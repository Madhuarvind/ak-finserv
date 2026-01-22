from flask import Blueprint, jsonify, request
from flask_jwt_extended import jwt_required, get_jwt_identity
from models import (
    db,
    User,
    UserRole,
    Customer,
    Loan,
    Line,
    Collection,
    DailySettlement,
    CustomerVersion,
    CustomerNote,
    CustomerDocument,
    SystemSetting,
)
from utils.auth_helpers import get_user_by_identity

admin_tools_bp = Blueprint("admin_tools", __name__)

MODEL_MAP = {
    "Users": User,
    "Customers": Customer,
    "Loans": Loan,
    "Lines": Line,
    "Collections": Collection,
    "DailySettlement": DailySettlement,
    "CustomerVersion": CustomerVersion,
    "CustomerNote": CustomerNote,
    "CustomerDocument": CustomerDocument,
    "SystemSetting": SystemSetting,
}


@admin_tools_bp.route("/raw-table/<table_name>", methods=["GET"])
@jwt_required()
def get_raw_table_data(table_name):
    identity = get_jwt_identity()
    user = get_user_by_identity(identity)

    if not user or user.role != UserRole.ADMIN:
        return jsonify({"msg": "Access Denied"}), 403

    model = MODEL_MAP.get(table_name)
    if not model:
        return jsonify({"msg": "Table not found"}), 404

    try:
        data = model.query.all()
        # Convert all model instances to dictionaries
        # We assume each model has a to_dict() method or we use a generic approach
        result = []
        for item in data:
            item_dict = {}
            for column in item.__table__.columns:
                val = getattr(item, column.name)
                # Handle datetime serialization
                if hasattr(val, "isoformat"):
                    val = val.isoformat()
                item_dict[column.name] = val
            result.append(item_dict)

        return jsonify(result), 200
    except Exception as e:
        return jsonify({"msg": "Error fetching data", "error": str(e)}), 500


@admin_tools_bp.route("/ai-analyst", methods=["POST"])
@jwt_required()
def ai_analyst():
    """
    Advanced AI Financial Analyst
    Parses natural language queries for dates, entities, and financial intent.
    """
    identity = get_jwt_identity()
    user = get_user_by_identity(identity)
    if not user or user.role != UserRole.ADMIN:
        return jsonify({"msg": "Access Denied"}), 403

    data = request.get_json()
    query = data.get("query", "").lower()

    # --- Helper: Time Window Parser ---
    from datetime import datetime, timedelta
    
    def get_date_range(text):
        today = datetime.utcnow().date()
        start_date = None
        end_date = None
        label = "All Time"

        if "today" in text:
            start_date = today
            end_date = today
            label = "Today"
        elif "yesterday" in text:
            start_date = today - timedelta(days=1)
            end_date = start_date
            label = "Yesterday"
        elif "this week" in text:
            start_date = today - timedelta(days=today.weekday())
            end_date = today
            label = "This Week"
        elif "last week" in text:
            start_date = today - timedelta(days=today.weekday() + 7)
            end_date = start_date + timedelta(days=6)
            label = "Last Week"
        elif "this month" in text:
            start_date = today.replace(day=1)
            end_date = today
            label = "This Month"
        elif "last month" in text:
            last_month_end = today.replace(day=1) - timedelta(days=1)
            start_date = last_month_end.replace(day=1)
            end_date = last_month_end
            label = "Last Month"
        
        return start_date, end_date, label

    # --- Helper: Value Formatter ---
    def fmt_cur(val):
        return f"₹{val:,.2f}"

    try:
        start_date, end_date, time_label = get_date_range(query)
        
        # --- Intent 1: Agent Performance (Specific Name) ---
        # Scan for agent names in the query
        agents = User.query.filter_by(role=UserRole.FIELD_AGENT).all()
        target_agent = None
        for agent in agents:
            if agent.name.lower() in query:
                target_agent = agent
                break
        
        if target_agent:
            # Agent-specific query
            coll_query = db.session.query(db.func.sum(Collection.amount)).filter(
                Collection.agent_id == target_agent.id,
                Collection.status == "approved"
            )
            
            if start_date:
                coll_query = coll_query.filter(db.func.date(Collection.created_at) >= start_date)
                if end_date:
                    coll_query = coll_query.filter(db.func.date(Collection.created_at) <= end_date)
            
            total = coll_query.scalar() or 0
            
            response_text = f"📊 **{target_agent.name} ({time_label})**\n" \
                            f"Total Collections: **{fmt_cur(total)}**"
            
            if "status" in query or "where" in query:
                status = "On Duty" if target_agent.duty_status == "on_duty" else "Off Duty"
                response_text += f"\nCurrent Status: {status} ({target_agent.current_activity})"

            return jsonify({
                "text": response_text,
                "type": "agent_highlight",
                "data": {"agent": target_agent.name, "amount": total}
            }), 200

        # --- Intent 2: General Collection Summary (Time-based) ---
        if any(w in query for w in ["collection", "collected", "recovery", "income", "revenue"]):
            coll_query = db.session.query(db.func.sum(Collection.amount)).filter(Collection.status == "approved")
            count_query = Collection.query.filter(Collection.status == "approved")
            
            if start_date:
                coll_query = coll_query.filter(db.func.date(Collection.created_at) >= start_date)
                count_query = count_query.filter(db.func.date(Collection.created_at) >= start_date)
                if end_date:
                    coll_query = coll_query.filter(db.func.date(Collection.created_at) <= end_date)
                    count_query = count_query.filter(db.func.date(Collection.created_at) <= end_date)

            total = coll_query.scalar() or 0
            count = count_query.count()
            
            # Breakdown by mode
            cash_q = coll_query.filter(Collection.payment_mode == "cash").scalar() or 0
            upi_q = coll_query.filter(Collection.payment_mode == "upi").scalar() or 0
            
            response_text = f"💰 **Financial Summary ({time_label})**\n" \
                            f"Total Recovery: **{fmt_cur(total)}**\n" \
                            f"Receipts Generated: {count}\n\n" \
                            f"• Cash: {fmt_cur(cash_q)}\n" \
                            f"• UPI: {fmt_cur(upi_q)}"
            
            return jsonify({
                "text": response_text,
                "type": "metric",
                "data": {"total": total, "cash": cash_q, "upi": upi_q}
            }), 200

        # --- Intent 3: Risk & Overdue ---
        if any(w in query for w in ["risk", "overdue", "pending", "default", "arrears"]):
            # Overdue EMIs
            overdue_emi_sum = db.session.query(db.func.sum(EMISchedule.balance)).filter(
                EMISchedule.status == "pending",
                db.func.cast(EMISchedule.due_date, db.Date) < datetime.utcnow().date()
            ).scalar() or 0
            
            # Total Pending Loan Amount
            total_pending = db.session.query(db.func.sum(Loan.pending_amount)).filter(
                Loan.status == "active"
            ).scalar() or 0
            
            response_text = "⚠️ **Risk Assessment**\n"
            if "overdue" in query:
                response_text += f"Total Overdue ARREARS: **{fmt_cur(overdue_emi_sum)}**\n" \
                                 f"Immediate action required for these missed payments."
            else:
                response_text += f"Total Outstanding Principal: **{fmt_cur(total_pending)}**\n" \
                                 f"Current Overdue ARREARS: **{fmt_cur(overdue_emi_sum)}**"

            return jsonify({
                "text": response_text,
                "type": "risk_summary",
                "data": {"overdue": overdue_emi_sum, "pending": total_pending}
            }), 200

        # --- Intent 4: Loan/Customer Status ---
        if any(w in query for w in ["how many", "count", "status", "list"]):
            if "customer" in query:
                total_c = Customer.query.count()
                active_c = Customer.query.filter_by(status="active").count()
                return jsonify({"text": f"👥 **Customer Base**\nTotal: {total_c}\nActive: {active_c}"}), 200
            
            if "loan" in query:
                 active_l = Loan.query.filter_by(status="active").count()
                 closed_l = Loan.query.filter_by(status="closed").count()
                 return jsonify({"text": f"📜 **Loan Portfolio**\nActive Loans: {active_l}\nClosed Loans: {closed_l}"}), 200
            
            if "agent" in query:
                on_duty = User.query.filter_by(role=UserRole.FIELD_AGENT, duty_status="on_duty").count()
                total_a = User.query.filter_by(role=UserRole.FIELD_AGENT).count()
                return jsonify({"text": f"👷 **Field Force**\nOn Duty: {on_duty}\nTotal Agents: {total_a}"}), 200

        # --- Fallback / Greetings ---
        if any(greet in query for greet in ["hi", "hello", "hey"]):
             return jsonify({
                "text": "Hello! I am your Advanced AI Analyst. You can ask me things like:\n"
                        "• 'How much did Madhu collect yesterday?'\n"
                        "• 'What is the revenue last month?'\n"
                        "• 'Show me overdue risk'\n"
                        "• 'How many active loans?'"
            }), 200

        # --- Default Catch-All ---
        return jsonify({
            "text": "I didn't quite catch that. Try specifying a date (e.g., 'yesterday'), an agent name, or a topic like 'collections' or 'overdue'.",
            "type": "text"
        }), 200

    except Exception as e:
        print(f"AI Error: {e}")
        return jsonify({
            "text": "My brain encountered a glitch processing that complex query. Please try again.",
            "type": "error"
        }), 500


@admin_tools_bp.route("/seed-users", methods=["POST"])
def seed_users():
    """
    seeds the database with default users if they don't exist.
    """
    import bcrypt
    from models import User, UserRole
    
    def hash_pass(password):
        return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")

    try:
        # Check if users already exist
        existing_admin = User.query.filter_by(username="Arun").first()
        if not existing_admin:
            admin_arun = User(
                name="Arun",
                username="Arun",
                password_hash=hash_pass("Arun@123"),
                mobile_number="9000000001",
                role=UserRole.ADMIN,
                is_first_login=False
            )
            db.session.add(admin_arun)
            print("Created Admin: Arun")

        existing_worker = User.query.filter_by(name="Madhu").first()
        if not existing_worker:
            worker_madhu = User(
                name="Madhu",
                pin_hash=hash_pass("1111"),
                mobile_number="9000000002",
                role=UserRole.FIELD_AGENT,
                is_first_login=False
            )
            db.session.add(worker_madhu)
            print("Created Worker: Madhu")

        db.session.commit()
        return jsonify({"msg": "Database seeded successfully. Login with Arun/Arun@123 or Madhu/1111"}), 200

    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": "Seeding failed", "error": str(e)}), 500
