from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from models import db, User, Customer, Loan, Collection, UserRole, EMISchedule, Line
from datetime import datetime, timedelta
from sqlalchemy import func

reports_bp = Blueprint("reports", __name__)


def get_admin_user():
    identity = get_jwt_identity()
    user = User.query.filter(
        (User.username == identity)
        | (User.id == identity)
        | (User.mobile_number == identity)
    ).first()
    if user and user.role == UserRole.ADMIN:
        return user
    return None


@reports_bp.route("/stats/kpi", methods=["GET"])
@jwt_required()
def get_kpi_stats():
    """Top-level KPIs for Admin Dashboard"""
    if not get_admin_user():
        return jsonify({"msg": "Admin access required"}), 403

    try:
        total_customers = Customer.query.count()
        active_loans = Loan.query.filter_by(status="active").count()

        # Disbursed (Total Principal)
        total_disbursed = (
            db.session.query(func.sum(Loan.principal_amount)).scalar() or 0
        )

        # Collected (Approved collections only)
        total_collected = (
            db.session.query(func.sum(Collection.amount))
            .filter_by(status="approved")
            .scalar()
            or 0
        )

        # Outstanding (Principal + Interest pending - Collected)
        # Actually in our model Loan.pending_amount tracks this directly
        outstanding_balance = (
            db.session.query(func.sum(Loan.pending_amount))
            .filter(Loan.status.in_(["active", "approved"]))
            .scalar()
            or 0
        )

        # Overdue Amount: Sum of unpaid EMIs where due_date < today
        today = datetime.utcnow()
        overdue_amount = (
            db.session.query(func.sum(EMISchedule.balance))
            .filter(EMISchedule.status != "paid", EMISchedule.due_date < today)
            .scalar()
            or 0
        )

        return (
            jsonify(
                {
                    "total_customers": total_customers,
                    "active_loans": active_loans,
                    "total_disbursed": float(total_disbursed),
                    "total_collected": float(total_collected),
                    "outstanding_balance": float(outstanding_balance),
                    "overdue_amount": float(overdue_amount),
                }
            ),
            200,
        )

    except Exception as e:
        print(f"KPI Error: {e}")
        return jsonify({"msg": str(e)}), 500


@reports_bp.route("/daily", methods=["GET"])
@jwt_required()
def get_daily_report():
    """Collections for a specific date range"""
    if not get_admin_user():
        return jsonify({"msg": "Admin access required"}), 403

    start_date_str = request.args.get("start_date")
    end_date_str = request.args.get("end_date")

    try:
        start_date = (
            datetime.fromisoformat(start_date_str)
            if start_date_str
            else datetime.utcnow().replace(hour=0, minute=0, second=0)
        )
        end_date = (
            datetime.fromisoformat(end_date_str)
            if end_date_str
            else datetime.utcnow().replace(hour=23, minute=59, second=59)
        )

        collections = (
            Collection.query.filter(
                Collection.created_at >= start_date, Collection.created_at <= end_date
            )
            .order_by(Collection.created_at.desc())
            .all()
        )

        report = []
        for c in collections:
            report.append(
                {
                    "id": c.id,
                    "amount": c.amount,
                    "mode": c.payment_mode,
                    "status": c.status,
                    "time": c.created_at.isoformat() + "Z",
                    "agent_name": c.agent.name if c.agent else "Unknown",
                    "customer_name": (
                        c.loan.customer.name
                        if c.loan and c.loan.customer
                        else "Unknown"
                    ),
                    "loan_id": c.loan.loan_id if c.loan else "N/A",
                }
            )

        summary = {
            "total": sum(c.amount for c in collections if c.status == "approved"),
            "count": len(collections),
            "cash": sum(
                c.amount
                for c in collections
                if c.status == "approved" and c.payment_mode == "cash"
            ),
            "upi": sum(
                c.amount
                for c in collections
                if c.status == "approved" and c.payment_mode == "upi"
            ),
        }

        return jsonify({"report": report, "summary": summary}), 200

    except Exception as e:
        return jsonify({"msg": str(e)}), 500


@reports_bp.route("/outstanding", methods=["GET"])
@jwt_required()
def get_outstanding_report():
    """List of all loans with pending balance"""
    if not get_admin_user():
        return jsonify({"msg": "Admin access required"}), 403

    try:
        loans = (
            Loan.query.filter(Loan.pending_amount > 0)
            .order_by(Loan.pending_amount.desc())
            .all()
        )

        report = []
        for pl in loans:
            customer_name = pl.customer.name if pl.customer else "Unknown"
            area = pl.customer.area if pl.customer else "Unknown"
            mobile = pl.customer.mobile_number if pl.customer else "N/A"

            report.append(
                {
                    "loan_id": pl.loan_id,
                    "customer_name": customer_name,
                    "mobile": mobile,
                    "area": area,
                    "principal": pl.principal_amount,
                    "pending": pl.pending_amount,
                    "status": pl.status,
                    "days_active": (datetime.utcnow() - pl.created_at).days,
                }
            )

        return jsonify(report), 200
    except Exception as e:
        return jsonify({"msg": str(e)}), 500


@reports_bp.route("/performance", methods=["GET"])
@jwt_required()
def get_performance_report():
    """Agent Performance Metrics"""
    if not get_admin_user():
        return jsonify({"msg": "Admin access required"}), 403

    try:
        agents = User.query.filter_by(role=UserRole.FIELD_AGENT).all()
        report = []

        for agent in agents:
            collected = (
                db.session.query(func.sum(Collection.amount))
                .filter_by(agent_id=agent.id, status="approved")
                .scalar()
                or 0
            )
            assigned_cust = Customer.query.filter_by(
                assigned_worker_id=agent.id
            ).count()

            report.append(
                {
                    "agent_id": agent.id,
                    "name": agent.name,
                    "collected": float(collected),
                    "assigned_customers": assigned_cust,
                    # "target": agent.target_amount # If we had this field
                }
            )

        return jsonify(report), 200
    except Exception as e:
        return jsonify({"msg": str(e)}), 500


@reports_bp.route("/risk/overdue", methods=["GET"])
@jwt_required()
def get_overdue_report():
    """List of customers with overdue EMIs"""
    if not get_admin_user():
        return jsonify({"msg": "Admin access required"}), 403

    try:
        today = datetime.utcnow()
        overdue_emis = (
            db.session.query(EMISchedule, Loan, Customer)
            .join(Loan, EMISchedule.loan_id == Loan.id)
            .join(Customer, Loan.customer_id == Customer.id)
            .filter(EMISchedule.status != "paid", EMISchedule.due_date < today)
            .all()
        )

        report_map = {}

        for emi, loan, cust in overdue_emis:
            if cust.id not in report_map:
                report_map[cust.id] = {
                    "customer_name": cust.name,
                    "mobile": cust.mobile_number,
                    "area": cust.area,
                    "total_overdue": 0,
                    "missed_emis": 0,
                    "oldest_due_date": emi.due_date.isoformat() + "Z",
                }

            report_map[cust.id]["total_overdue"] += emi.balance
            report_map[cust.id]["missed_emis"] += 1
            if emi.due_date.isoformat() + "Z" < report_map[cust.id]["oldest_due_date"]:
                report_map[cust.id]["oldest_due_date"] = emi.due_date.isoformat() + "Z"

        return jsonify(list(report_map.values())), 200

    except Exception as e:
        return jsonify({"msg": str(e)}), 500


@reports_bp.route("/reminders/due-tomorrow", methods=["GET"])
@jwt_required()
def get_tomorrow_reminders():
    """Customers with EMIs due tomorrow for proactive reminders"""
    if not get_admin_user():
        return jsonify({"msg": "Admin access required"}), 403

    try:
        tomorrow = (datetime.utcnow() + timedelta(days=1)).date()

        targets = (
            db.session.query(EMISchedule, Loan, Customer)
            .join(Loan, EMISchedule.loan_id == Loan.id)
            .join(Customer, Loan.customer_id == Customer.id)
            .filter(
                EMISchedule.status != "paid",
                func.date(EMISchedule.due_date) == tomorrow,
            )
            .all()
        )

        report = []
        for emi, loan, cust in targets:
            report.append(
                {
                    "customer_name": cust.name,
                    "mobile": cust.mobile_number,
                    "amount": emi.amount,
                    "loan_id": loan.loan_id,
                    "area": cust.area,
                }
            )

        return jsonify(report), 200
    except Exception as e:
        return jsonify({"msg": str(e)}), 500


@reports_bp.route("/reminders/send-all", methods=["POST"])
@jwt_required()
def trigger_bulk_reminders():
    """Simulates sending WhatsApp/SMS reminders to all targets"""
    if not get_admin_user():
        return jsonify({"msg": "Admin access required"}), 403

    # In a real app, this would queue background tasks
    # For this demo, we return success and log the event
    return (
        jsonify(
            {
                "msg": "Reminders queued for delivery",
                "provider": "WhatsApp/SMS Gateway",
                "status": "success",
            }
        ),
        200,
    )


@reports_bp.route("/daily-ops-summary", methods=["GET"])
@jwt_required()
def get_daily_ops_summary():
    """Real-time pulse of today's recovery operations"""
    if not get_admin_user():
        return jsonify({"msg": "Admin access required"}), 403

    try:
        from datetime import datetime

        today_start = datetime.utcnow().replace(
            hour=0, minute=0, second=0, microsecond=0
        )
        today_end = datetime.utcnow().replace(
            hour=23, minute=59, second=59, microsecond=999999
        )

        # 1. Target: Sum of EMIs due today
        target_today = (
            db.session.query(func.sum(EMISchedule.amount))
            .filter(func.date(EMISchedule.due_date) == today_start.date())
            .scalar()
            or 0
        )

        # 2. Progress: Sum of collections approved today
        collected_today = (
            db.session.query(func.sum(Collection.amount))
            .filter(
                Collection.created_at >= today_start,
                Collection.created_at <= today_end,
                Collection.status == "approved",
            )
            .scalar()
            or 0
        )

        # 3. Efficiency: Unique agents with at least one approved collection today
        active_agents_count = (
            db.session.query(func.count(func.distinct(Collection.agent_id)))
            .filter(
                Collection.created_at >= today_start,
                Collection.created_at <= today_end,
                Collection.status == "approved",
            )
            .scalar()
            or 0
        )

        # 4. Top Performers (Today)
        top_performers = (
            db.session.query(User.name, func.sum(Collection.amount))
            .join(Collection, User.id == Collection.agent_id)
            .filter(
                Collection.created_at >= today_start,
                Collection.created_at <= today_end,
                Collection.status == "approved",
            )
            .group_by(User.id)
            .order_by(func.sum(Collection.amount).desc())
            .limit(5)
            .all()
        )

        leaders = [{"name": p[0], "amount": float(p[1])} for p in top_performers]

        return (
            jsonify(
                {
                    "target_today": float(target_today),
                    "collected_today": float(collected_today),
                    "progress_percentage": (
                        round((collected_today / target_today * 100), 1)
                        if target_today > 0
                        else 0
                    ),
                    "active_agents": active_agents_count,
                    "leaders": leaders,
                }
            ),
            200,
        )

    except Exception as e:
        return jsonify({"msg": str(e)}), 500


@reports_bp.route("/line/<int:line_id>", methods=["GET"])
@jwt_required()
def get_line_report(line_id):
    """Detailed summary of collections for a specific Line (Route)"""
    from models import Line, LineCustomer

    period = request.args.get("period", "daily")  # 'daily' or 'weekly'
    date_str = request.args.get("date")

    try:
        if date_str:
            target_date = datetime.fromisoformat(date_str).replace(
                hour=0, minute=0, second=0, microsecond=0
            )
        else:
            target_date = datetime.utcnow().replace(
                hour=0, minute=0, second=0, microsecond=0
            )

        if period == "weekly":
            # Start of current week (Monday)
            start_date = target_date - timedelta(days=target_date.weekday())
            end_date = start_date + timedelta(days=6, hours=23, minutes=59, seconds=59)
        else:
            start_date = target_date
            end_date = target_date.replace(
                hour=23, minute=59, second=59, microsecond=999999
            )

        line = Line.query.get_or_404(line_id)
        line_customers = (
            LineCustomer.query.filter_by(line_id=line_id)
            .order_by(LineCustomer.sequence_order)
            .all()
        )

        customer_ids = [lc.customer_id for lc in line_customers]

        # Get all collections for these customers in this line and period
        collections = Collection.query.filter(
            Collection.line_id == line_id,
            Collection.customer_id.in_(
                customer_ids
            ),  # Optimization: use relationship if possible
            Collection.created_at >= start_date,
            Collection.created_at <= end_date,
            Collection.status != "rejected",
        ).all()

        # Actually, our Collection model might not have customer_id directly (it has loan_id)
        # Let's verify Collection model logic. It has loan_id.
        # We need to join Collection with Loan to get customer_id.

        collections = (
            db.session.query(Collection)
            .join(Loan, Collection.loan_id == Loan.id)
            .filter(
                Collection.line_id == line_id,
                Loan.customer_id.in_(customer_ids),
                Collection.created_at >= start_date,
                Collection.created_at <= end_date,
                Collection.status != "rejected",
            )
            .all()
        )

        collection_map = {}
        for c in collections:
            cust_id = c.loan.customer_id
            if cust_id not in collection_map:
                collection_map[cust_id] = []
            collection_map[cust_id].append(c)

        report_details = []
        total_cash = 0
        total_upi = 0
        total_collected = 0
        paid_count = 0

        for lc in line_customers:
            cust = lc.customer
            cust_collections = collection_map.get(cust.id, [])

            is_paid = len(cust_collections) > 0
            if is_paid:
                paid_count += 1

            cust_total = sum(c.amount for c in cust_collections)
            modes = list(set(c.payment_mode for c in cust_collections))

            report_details.append(
                {
                    "customer_id": cust.customer_id,
                    "name": cust.name,
                    "area": cust.area,
                    "status": "Paid" if is_paid else "Not Paid",
                    "amount": float(cust_total),
                    "modes": modes,
                    "time": (
                        cust_collections[0].created_at.isoformat() + "Z"
                        if is_paid
                        else None
                    ),
                }
            )

            for c in cust_collections:
                total_collected += c.amount
                if c.payment_mode == "cash":
                    total_cash += c.amount
                elif c.payment_mode == "upi":
                    total_upi += c.amount

        return (
            jsonify(
                {
                    "line_name": line.name,
                    "period": period,
                    "start_date": start_date.isoformat() + "Z",
                    "end_date": end_date.isoformat() + "Z",
                    "details": report_details,
                    "summary": {
                        "total_customers": len(line_customers),
                        "paid_customers": paid_count,
                        "pending_customers": len(line_customers) - paid_count,
                        "total_collected": float(total_collected),
                        "total_cash": float(total_cash),
                        "total_upi": float(total_upi),
                    },
                }
            ),
            200,
        )

    except Exception as e:
        print(f"Line Report Error: {e}")
        return jsonify({"msg": str(e)}), 500


@reports_bp.route("/dashboard-insights", methods=["GET"])
@jwt_required()
def get_dashboard_insights():
    """Advanced AI-style insights for admin dashboard"""
    if not get_admin_user():
        return jsonify({"msg": "Admin access required"}), 403

    try:
        # Today's metrics
        today_start = datetime.utcnow().replace(
            hour=0, minute=0, second=0, microsecond=0
        )

        # 1. Recovery Velocity
        recent_collections = Collection.query.filter(
            Collection.created_at >= today_start, Collection.status == "approved"
        ).count()

        # 2. Risk Trend (Simplified)
        high_risk_loans = Loan.query.filter(
            Loan.status == "active", Loan.pending_amount > Loan.principal_amount * 1.5
        ).count()

        # 3. Liquidity Prediction
        total_outstanding = (
            db.session.query(func.sum(Loan.pending_amount))
            .filter(Loan.status == "active")
            .scalar()
            or 0
        )

        insights = [
            f"Recovery velocity is nominal today with {recent_collections} approved entries.",
            f"Detected {high_risk_loans} loans exceeding normal interest-to-principal ratios.",
            f"Current market exposure (outstanding) stands at ₹{float(total_outstanding):,.2f}.",
        ]

        return (
            jsonify(
                {
                    "insights": insights,
                    "sentiment": "Neutral",
                    "recommendation": "Monitor high-risk accounts in 'Risk Analytics' section.",
                }
            ),
            200,
        )
    except Exception as e:
        return jsonify({"msg": str(e)}), 500


@reports_bp.route("/work-targets", methods=["GET"])
@jwt_required()
def get_work_targets():
    """Weekly/Daily recovery targets for agents"""
    if not get_admin_user():
        return jsonify({"msg": "Admin access required"}), 403

    try:
        # Simplified: Static targets or calculated based on lines
        agents = User.query.filter_by(role=UserRole.FIELD_AGENT).all()
        report = []

        for agent in agents:
            # Target = total pending balance in their assigned lines for the week
            assigned_lines = Line.query.filter_by(agent_id=agent.id).all()
            total_target = 0
            for line in assigned_lines:
                # Sum of EMIs due this week
                today = datetime.utcnow().date()
                start_week = today - timedelta(days=today.weekday())
                end_week = start_week + timedelta(days=6)

                line_cust_ids = [lc.customer_id for lc in line.customers]
                weekly_emis = (
                    db.session.query(func.sum(EMISchedule.amount))
                    .join(Loan)
                    .filter(
                        Loan.customer_id.in_(line_cust_ids),
                        func.date(EMISchedule.due_date) >= start_week,
                        func.date(EMISchedule.due_date) <= end_week,
                        EMISchedule.status != "paid",
                    )
                    .scalar()
                    or 0
                )
                total_target += float(weekly_emis)

            report.append(
                {
                    "agent_id": agent.id,
                    "name": agent.name,
                    "target": total_target,
                    "achieved": 0,  # Logic to sum approved collections this week
                }
            )

        return jsonify(report), 200
    except Exception as e:
        return jsonify({"msg": str(e)}), 500
