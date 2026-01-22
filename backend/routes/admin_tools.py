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
    Simulated AI Financial Analyst
    Translates natural language queries into financial insights
    """
    identity = get_jwt_identity()
    user = get_user_by_identity(identity)
    if not user or user.role != UserRole.ADMIN:
        return jsonify({"msg": "Access Denied"}), 403

    data = request.get_json()
    query = data.get("query", "").lower()

    response = {
        "text": "I'm sorry, I couldn't find specific data for that request. Try asking about 'total collections', 'today's cash', or 'top agents'.",
        "data": None,
        "type": "text",
    }

    # 0. Greetings
    if any(greet in query for greet in ["hi", "hello", "hey", "vanakkam"]):
        response["text"] = (
            "Hello! I am your AI Financial Analyst. You can ask me about collections, agent performance, or risk. For example: 'What is today's total cash?'"
        )
        return jsonify(response), 200

    # 1. Total Collections Query (All time or general)
    if "total" in query and (
        "collection" in query or "collect" in query or "all" in query
    ):
        total_sum = (
            db.session.query(db.func.sum(Collection.amount))
            .filter_by(status="approved")
            .scalar()
            or 0
        )
        total_count = Collection.query.filter_by(status="approved").count()
        response["text"] = (
            f"Our lifetime approved collections reached ₹{total_sum:,.2f} across {total_count} entries. This reflects a healthy recovery rate across all lines."
        )
        response["data"] = {
            "value": total_sum,
            "metric": "LifeTime Collections",
            "count": total_count,
        }
        response["type"] = "metric"

    # 2. Today's Cash or just "Total cash"
    elif "today" in query or "day" in query or "cash" in query:
        from datetime import datetime

        today = datetime.utcnow().date()

        today_cash = (
            db.session.query(db.func.sum(Collection.amount))
            .filter(
                db.func.date(Collection.created_at) == today,
                Collection.status == "approved",
                Collection.payment_mode == "cash",
            )
            .scalar()
            or 0
        )

        today_upi = (
            db.session.query(db.func.sum(Collection.amount))
            .filter(
                db.func.date(Collection.created_at) == today,
                Collection.status == "approved",
                Collection.payment_mode == "upi",
            )
            .scalar()
            or 0
        )

        today_count = Collection.query.filter(
            db.func.date(Collection.created_at) == today,
            Collection.status == "approved",
        ).count()

        top_agent_today = (
            db.session.query(User.name, db.func.sum(Collection.amount))
            .join(Collection, User.id == Collection.agent_id)
            .filter(
                db.func.date(Collection.created_at) == today,
                Collection.status == "approved",
            )
            .group_by(User.id)
            .order_by(db.func.sum(Collection.amount).desc())
            .first()
        )

        if "upi" in query:
            response["text"] = (
                f"Today's total approved UPI collection is ₹{today_upi:,.2f}."
            )
            response["data"] = {"value": today_upi, "metric": "Today's UPI"}
        else:
            summary_text = f"Today's Tally: Total ₹{today_cash + today_upi:,.2f} recovered across {today_count} collections.\n\n"
            summary_text += f"• Cash: ₹{today_cash:,.2f}\n"
            summary_text += f"• UPI: ₹{today_upi:,.2f}\n"
            if top_agent_today:
                summary_text += f"\nLeaderboard: {top_agent_today[0]} is leading today with ₹{top_agent_today[1]:,.2f} collected."

            response["text"] = summary_text
            response["data"] = {
                "cash": today_cash,
                "upi": today_upi,
                "total": today_cash + today_upi,
            }

        response["type"] = "metric"

    # 3. Best/Top Agent (All time)
    elif (
        "top" in query or "best" in query or "agent" in query or "performance" in query
    ):
        top_agent = (
            db.session.query(User.name, db.func.sum(Collection.amount))
            .join(Collection, User.id == Collection.agent_id)
            .filter(Collection.status == "approved")
            .group_by(User.id)
            .order_by(db.func.sum(Collection.amount).desc())
            .first()
        )

        if top_agent:
            response["text"] = (
                f"Our all-time top performing agent is {top_agent[0]}, who has successfully recovered ₹{top_agent[1]:,.2f}. This agent consistently maintains high geofencing accuracy."
            )
            response["data"] = {"name": top_agent[0], "value": top_agent[1]}
            response["type"] = "agent_highlight"

    # 4. Defaults / High Risk
    elif "risk" in query or "default" in query:
        high_risk_count = Loan.query.filter(
            Loan.pending_amount > (Loan.principal_amount * 0.8)
        ).count()
        response["text"] = (
            f"I've identified {high_risk_count} loans with a potential high risk of default (over 80% balance remaining)."
        )
        response["data"] = {"count": high_risk_count}
        response["type"] = "risk_summary"

    return jsonify(response), 200


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
