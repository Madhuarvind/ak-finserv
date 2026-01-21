from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from models import (
    db,
    User,
    Customer,
    Loan,
    Collection,
    UserRole,
    EMISchedule,
    LoanAuditLog,
    Line,
    LineCustomer,
)
from utils.auth_helpers import get_user_by_identity
from datetime import datetime, timedelta
from utils.interest_utils import (  # noqa: F401
    calculate_flat_emi,
    calculate_reducing_emi,
    generate_dates,
    get_distance_meters,
)

collection_bp = Blueprint("collection", __name__)


@collection_bp.route("/submit", methods=["POST"])
@jwt_required()
def submit_collection():
    identity = get_jwt_identity()
    user = get_user_by_identity(identity)

    if not user:
        return jsonify({"msg": "User not found"}), 404

    data = request.get_json()
    loan_id = data.get("loan_id")
    amount = float(data.get("amount"))
    payment_mode = data.get("payment_mode", "cash")
    latitude = data.get("latitude")
    longitude = data.get("longitude")
    line_id = data.get("line_id")

    if not loan_id or amount is None:
        return jsonify({"msg": "Missing required fields"}), 400

    loan = Loan.query.get(loan_id)
    if not loan:
        return jsonify({"msg": "Loan not found"}), 404

    # --- NEW: ENFORCE ENHANCED SECURITY ---
    today = datetime.utcnow().date()
    
    # 1. Check if already collected today FOR THIS LOAN
    existing_today = Collection.query.filter(
        Collection.loan_id == loan_id,
        db.func.date(Collection.created_at) == today
    ).first()
    
    if existing_today:
        return jsonify({"msg": "already_collected_today"}), 400

    # 2. Check Time Window if line_id provided
    if line_id:
        line = Line.query.get(line_id)
        if line and line.start_time and line.end_time:
            # Current time in IST (User preference)
            ist_now = datetime.utcnow() + timedelta(hours=5, minutes=30)
            current_time_str = ist_now.strftime("%H:%M")
            
            if not (line.start_time <= current_time_str <= line.end_time):
                return jsonify({
                    "msg": "collection_window_closed",
                    "window": f"{line.start_time} - {line.end_time}",
                    "current": current_time_str
                }), 403

    # 3. Duplicate Check (Idempotency - Short term)
    # ...

    # --- PHASE 11: AI-POWERED FRAUD DETECTION & GEOFENCING ---
    fraud_flag = False
    fraud_reason = []

    # A. Geofencing Check
    distance = None  # Initialize
    if (
        loan.customer
        and loan.customer.latitude
        and loan.customer.longitude
        and latitude
        and longitude
    ):
        distance = get_distance_meters(
            latitude, longitude, loan.customer.latitude, loan.customer.longitude
        )
        if distance > 200:  # 200 meters threshold
            fraud_flag = True
            fraud_reason.append(
                f"Geofencing Violation: {round(distance)}m away from customer profile location"
            )

    # B. Collection Velocity Check (Anti-Speed Collection)
    # If agent is submitting multiple collections from different customers too fast
    last_agent_collection = (
        Collection.query.filter_by(agent_id=user.id)
        .order_by(Collection.created_at.desc())
        .first()
    )
    if last_agent_collection:
        time_diff = (
            datetime.utcnow() - last_agent_collection.created_at
        ).total_seconds()
        if time_diff < 30:  # Less than 30 seconds between distinct collections
            fraud_flag = True
            fraud_reason.append(
                f"Velocity Anomaly: System detected rapid-fire collection ({int(time_diff)}s since last entry)"
            )

    collect_status = "pending"  # Requires admin approval
    if fraud_flag:
        collect_status = "flagged"  # Admin must review

    # --- PHASE 12: AI AUTONOMOUS MANAGER (AUTO-APPROVAL) ---
    # Goal: Zero-touch approval for trusted agents in correct location
    # Reduce manual overhead by 80% for high-trust agents
    if (
        not fraud_flag
        and payment_mode == "cash"
        and distance is not None
        and distance < 50
    ):
        # Check Agent Trust History
        # If agent has 0 flagged collections in history, they are trusted
        flagged_count = Collection.query.filter_by(
            agent_id=user.id, status="flagged"
        ).count()
        if flagged_count == 0:
            collect_status = "approved"
            # Log AI auto-approval
            ai_log = LoanAuditLog(
                loan_id=loan.id,
                action="AI_AUTO_APPROVAL",
                performed_by=user.id,
                remarks="AI Autonomous Manager: Entry verified via strict geofencing and agent trust score. Auto-approved.",
            )
            db.session.add(ai_log)

    # 2. Record Collection
    new_collection = Collection(
        loan_id=loan_id,
        agent_id=user.id,
        line_id=line_id,
        amount=amount,
        payment_mode=payment_mode,
        latitude=latitude,
        longitude=longitude,
        status=collect_status,
    )

    if fraud_flag:
        # Log suspected fraud in audit
        audit_fraud = LoanAuditLog(
            loan_id=loan.id,
            action="FRAUD_ALERT",
            performed_by=user.id,
            remarks=f"SUSPECTED FRAUD: {', '.join(fraud_reason)}",
        )
        db.session.add(audit_fraud)

    db.session.add(new_collection)

    # 3. Allocating Payment to EMIs (The "Brain")
    # ONLY apply financial impact if status is approved (Manual or AI)
    if collect_status == "approved":
        remaining = amount
        emis = (
            EMISchedule.query.filter_by(loan_id=loan_id)
            .filter(EMISchedule.status != "paid")
            .order_by(EMISchedule.due_date)
            .all()
        )

        allocation_details = []

        for emi in emis:
            if remaining <= 0:
                break

            # If emi.balance is None (legacy data), assume full amount
            current_balance = emi.balance if emi.balance is not None else emi.amount

            check_amount = min(remaining, current_balance)

            new_balance = current_balance - check_amount
            remaining -= check_amount

            emi.balance = new_balance
            if new_balance <= 0.1:  # Float tolerance
                emi.status = "paid"
                emi.balance = 0
            else:
                emi.status = "partial"

            allocation_details.append(f"EMI #{emi.emi_no}: Paid {check_amount}")

        # 4. Update Loan Balance
        loan.pending_amount = max(0, loan.pending_amount - amount)

        # Check for Loan Closure
        if loan.pending_amount <= 10:  # Small tolerance for calc errors
            # Verify all EMIs are paid
            all_paid = (
                not EMISchedule.query.filter_by(loan_id=loan_id)
                .filter(EMISchedule.status != "paid")
                .first()
            )
            if all_paid:
                loan.status = "closed"
                allocation_details.append("Loan Closed")

        # 5. Audit Log (Financial)
        audit = LoanAuditLog(
            loan_id=loan.id,
            action="COLLECTION_APPROVED",
            performed_by=user.id,
            remarks=f"Financials updated. Collected {amount} via {payment_mode}. "
            + ", ".join(allocation_details),
        )
        db.session.add(audit)
    else:
        # Audit Log (Record only)
        audit = LoanAuditLog(
            loan_id=loan.id,
            action="COLLECTION_SUBMITTED",
            performed_by=user.id,
            remarks=f"Collection of {amount} registered as {collect_status}. Financials pending approval.",
        )
        db.session.add(audit)

    try:
        db.session.commit()
        return (
            jsonify(
                {
                    "msg": "collection_submitted_successfully",
                    "id": new_collection.id,
                    "status": new_collection.status,
                    "loan_balance": loan.pending_amount,
                    "fraud_warning": fraud_reason if fraud_flag else None,
                }
            ),
            201,
        )
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": str(e)}), 500


@collection_bp.route("/customers", methods=["GET"])
@jwt_required()
def get_customers():
    customers = Customer.query.all()
    return (
        jsonify(
            [
                {"id": c.id, "name": c.name, "mobile": c.mobile_number, "area": c.area}
                for c in customers
            ]
        ),
        200,
    )


@collection_bp.route("/customers", methods=["POST"])
@jwt_required()
def create_customer():
    identity = get_jwt_identity()
    admin = get_user_by_identity(identity)

    if not admin:
        return jsonify({"msg": "Admin Access Required"}), 403

    # Normalize role check
    current_role = admin.role.value if hasattr(admin.role, 'value') else admin.role
    if current_role != UserRole.ADMIN.value:
        return jsonify({"msg": "Admin Access Required"}), 403

    data = request.get_json()
    name = data.get("name")
    mobile = data.get("mobile_number")
    area = data.get("area")
    address = data.get("address", "")

    if not name or not mobile:
        return jsonify({"msg": "Name and Mobile are required"}), 400

    # Generate Unique Customer ID
    current_year = datetime.now().year
    count = Customer.query.filter(
        Customer.created_at >= datetime(current_year, 1, 1)
    ).count()
    cust_unique_id = f"CUST-{current_year}-{str(count + 1).zfill(6)}"

    while Customer.query.filter_by(customer_id=cust_unique_id).first():
        count += 1
        cust_unique_id = f"CUST-{current_year}-{str(count + 1).zfill(6)}"

    new_customer = Customer(
        name=name,
        mobile_number=mobile,
        area=area,
        address=address,
        customer_id=cust_unique_id,
        status="active",
        created_at=datetime.utcnow(),
    )

    db.session.add(new_customer)
    db.session.commit()

    return (
        jsonify(
            {
                "msg": "customer_created_successfully",
                "id": new_customer.id,
                "customer_id": new_customer.customer_id,
            }
        ),
        201,
    )


@collection_bp.route("/loans/<int:customer_id>", methods=["GET"])
@jwt_required()
def get_customer_loans(customer_id):
    loans = Loan.query.filter_by(customer_id=customer_id, status="active").all()
    return (
        jsonify(
            [
                {
                    "id": loan.id,
                    "amount": loan.principal_amount,
                    "pending": loan.pending_amount,
                    "installments": loan.tenure,
                    "loan_id": loan.loan_id,
                    "interest_rate": loan.interest_rate,
                    "tenure": loan.tenure,
                    "tenure_unit": loan.tenure_unit,
                }
                for loan in loans
            ]
        ),
        200,
    )


@collection_bp.route("/pending-collections", methods=["GET"])
@jwt_required()
def get_pending_collections():
    identity = get_jwt_identity()
    user = get_user_by_identity(identity)

    if not user:
        return jsonify({"msg": "Admin Access Required"}), 403

    # Normalize role check
    current_role = user.role.value if hasattr(user.role, 'value') else user.role
    if current_role != UserRole.ADMIN.value:
        return jsonify({"msg": "Admin Access Required"}), 403

    # Get all pending and flagged collections with joins
    collections = (
        Collection.query.filter(Collection.status.in_(["pending", "flagged"]))
        .order_by(Collection.created_at.desc())
        .all()
    )

    result = []
    for c in collections:
        loan = Loan.query.get(c.loan_id)
        customer = Customer.query.get(loan.customer_id) if loan else None
        agent = User.query.get(c.agent_id)

        result.append(
            {
                "id": c.id,
                "amount": c.amount,
                "payment_mode": c.payment_mode,
                "status": c.status,
                "created_at": c.created_at.isoformat() + "Z",
                "customer_name": customer.name if customer else "Unknown",
                "customer_area": customer.area if customer else "",
                "loan_id": loan.loan_id if loan else "",
                "agent_name": agent.name if agent else "Unknown",
                "latitude": c.latitude,
                "longitude": c.longitude,
            }
        )

    return jsonify(result), 200


@collection_bp.route("/<int:collection_id>/status", methods=["PATCH"])
@jwt_required()
def update_collection_status(collection_id):
    identity = get_jwt_identity()
    user = get_user_by_identity(identity)

    if not user:
        return jsonify({"msg": "Access Denied"}), 403

    # Normalize role check
    current_role = user.role.value if hasattr(user.role, 'value') else user.role
    if current_role == UserRole.FIELD_AGENT.value:
        return jsonify({"msg": "Access Denied"}), 403

    data = request.get_json()
    status = data.get("status")

    if status not in ["approved", "rejected"]:
        return jsonify({"msg": "Invalid status"}), 400

    collection = Collection.query.get(collection_id)
    if not collection:
        return jsonify({"msg": "Collection not found"}), 404

    old_status = collection.status
    collection.status = status

    if status == "approved" and old_status != "approved":
        loan = Loan.query.get(collection.loan_id)
        if loan:
            # Applying financial update only now

            remaining = collection.amount
            emis = (
                EMISchedule.query.filter_by(loan_id=loan.id)
                .filter(EMISchedule.status != "paid")
                .order_by(EMISchedule.due_date)
                .all()
            )

            allocation_details = []
            for emi in emis:
                if remaining <= 0:
                    break
                current_balance = emi.balance if emi.balance is not None else emi.amount
                check_amount = min(remaining, current_balance)
                emi.balance = current_balance - check_amount
                remaining -= check_amount
                if emi.balance <= 0.1:
                    emi.status = "paid"
                    emi.balance = 0
                else:
                    emi.status = "partial"
                allocation_details.append(f"EMI #{emi.emi_no}: Paid {check_amount}")

            loan.pending_amount = max(0, loan.pending_amount - collection.amount)
            if loan.pending_amount <= 10:
                all_paid = (
                    not EMISchedule.query.filter_by(loan_id=loan.id)
                    .filter(EMISchedule.status != "paid")
                    .first()
                )
                if all_paid:
                    loan.status = "closed"

            # Audit log
            audit = LoanAuditLog(
                loan_id=loan.id,
                action="COLLECTION_APPROVED_BY_ADMIN",
                performed_by=user.id,
                remarks=f"Admin manual approval. Collected {collection.amount}. "
                + ", ".join(allocation_details),
            )
            db.session.add(audit)
    else:
        collection.status = status

    db.session.commit()
    return jsonify({"msg": "collection_updated_successfully", "status": status}), 200


@collection_bp.route("/stats/financials", methods=["GET"])
@jwt_required()
def get_financial_stats():
    identity = get_jwt_identity()
    user = User.query.filter(
        (User.username == identity)
        | (User.id == identity)
        | (User.mobile_number == identity)
        | (User.name == identity)
    ).first()

    if not user:
        return jsonify({"msg": "Admin Access Required"}), 403

    # Normalize role check
    current_role = user.role.value if hasattr(user.role, 'value') else user.role
    if current_role != UserRole.ADMIN.value:
         return jsonify({"msg": "Admin Access Required"}), 403
    
    total_approved = (
        db.session.query(db.func.sum(Collection.amount))
        .filter_by(status="approved")
        .scalar()
        or 0
    )
    today = datetime.utcnow().date()
    today_total = (
        db.session.query(db.func.sum(Collection.amount))
        .filter(
            db.func.date(Collection.created_at) == today,
            Collection.status == "approved",
        )
        .scalar()
        or 0
    )

    agent_stats = (
        db.session.query(Collection.agent_id, User.name, db.func.sum(Collection.amount))
        .join(User, Collection.agent_id == User.id)
        .filter(Collection.status == "approved")
        .group_by(Collection.agent_id, User.name)
        .all()
    )

    mode_stats = (
        db.session.query(Collection.payment_mode, db.func.sum(Collection.amount))
        .filter(Collection.status == "approved")
        .group_by(Collection.payment_mode)
        .all()
    )

    return (
        jsonify(
            {
                "total_approved": float(total_approved),
                "today_total": float(today_total),
                "agent_performance": [
                    {"id": s[0], "name": s[1], "total": float(s[2])}
                    for s in agent_stats
                ],
                "mode_distribution": {s[0]: float(s[1]) for s in mode_stats},
            }
        ),
        200,
    )


@collection_bp.route("/stats/agent", methods=["GET"])
@jwt_required()
def get_agent_stats():
    identity = get_jwt_identity()
    user = get_user_by_identity(identity)

    if not user:
        return jsonify({"msg": "User not found"}), 404

    # Fix Timezone (IST)
    ist_offset = timedelta(hours=5, minutes=30)
    now_ist = datetime.utcnow() + ist_offset
    today = now_ist.date()

    # Calculate IST Start/End for Querying UTC Timestamp
    start_of_day_ist = datetime(today.year, today.month, today.day)
    start_of_day_utc = start_of_day_ist - ist_offset
    end_of_day_utc = start_of_day_utc + timedelta(days=1)
    
    # helper for status list combined with case insensitive check
    valid_statuses = ["approved", "pending", "flagged"]

    # 1. Total Collected (All Time) - Case Insensitive
    total_collected = (
        db.session.query(db.func.sum(Collection.amount))
        .filter(
            Collection.agent_id == user.id,
            db.func.lower(Collection.status).in_(valid_statuses)
        )
        .scalar()
        or 0
    )

    # 2. Today's Collected (IST Corrected)
    today_collected = (
        db.session.query(db.func.sum(Collection.amount))
        .filter(Collection.agent_id == user.id)
        .filter(
            Collection.created_at >= start_of_day_utc,
            Collection.created_at < end_of_day_utc
        )
        .filter(db.func.lower(Collection.status).in_(valid_statuses))
        .scalar()
        or 0
    )

    # 3. Dynamic Goal Calculation
    # Sum of EMI balances due <= today for all active loans of customers in lines assigned to this agent
    goal = (
        db.session.query(db.func.sum(EMISchedule.balance))
        .join(Loan, EMISchedule.loan_id == Loan.id)
        .join(Customer, Loan.customer_id == Customer.id)
        .join(LineCustomer, Customer.id == LineCustomer.customer_id)
        .join(Line, LineCustomer.line_id == Line.id)
        .filter(
            Line.agent_id == user.id,
            Loan.status == "active",
            EMISchedule.status.in_(["pending", "partial", "overdue"]),
            db.func.date(EMISchedule.due_date) <= today
        )
        .scalar()
        or 0
    )
    
    # Fallback if no lines assigned (maybe direct customer assignment?)
    if goal == 0:
        goal = (
            db.session.query(db.func.sum(EMISchedule.balance))
            .join(Loan, EMISchedule.loan_id == Loan.id)
            .join(Customer, Loan.customer_id == Customer.id)
            .filter(
                Customer.assigned_worker_id == user.id,
                Loan.status == "active",
                EMISchedule.status.in_(["pending", "partial", "overdue"]),
                db.func.date(EMISchedule.due_date) <= today
            )
            .scalar()
            or 0
        )
    
    # Just in case goal is still 0 (New Agent?), provide a small target or 0.
    # We keep it 0 to reflect reality.

    return (
        jsonify(
            {
                "collected": float(total_collected),
                "today_collected": float(today_collected),
                "goal": float(goal),
                "currency": "INR",
                "timestamp": datetime.utcnow().isoformat(),
            }
        ),
        200,
    )


@collection_bp.route("/history", methods=["GET"])
@jwt_required()
def get_collection_history():
    identity = get_jwt_identity()
    user = get_user_by_identity(identity)

    if not user:
        return jsonify({"msg": "User not found"}), 404

    # Get 10 most recent collections for this agent
    history = (
        Collection.query.filter_by(agent_id=user.id)
        .order_by(Collection.created_at.desc())
        .limit(10)
        .all()
    )

    return (
        jsonify(
            [
                {
                    "id": c.id,
                    "amount": c.amount,
                    "status": c.status,
                    "time": c.created_at.isoformat(),
                    "customer_name": (
                        c.loan.customer.name
                        if hasattr(c, "loan") and c.loan and c.loan.customer
                        else "Unknown"
                    ),
                    "payment_mode": c.payment_mode,
                }
                for c in history
            ]
        ),
        200,
    )

# Helper: Collection History for N8n
# This endpoint allows N8n to fetch raw history to calculate averages.
@collection_bp.route("/history/<int:loan_id>", methods=["GET"])
def get_loan_collection_history(loan_id):
    # Fetch last 10 approved collections
    collections = Collection.query.filter_by(loan_id=loan_id, status='approved')\
        .order_by(Collection.created_at.desc()).limit(10).all()
    
    data = [{
        "amount": c.amount,
        "date": c.created_at.isoformat()
    } for c in collections]
    
    # Check for today's entry
    today = datetime.utcnow().date()
    has_today = any(c.created_at.date() == today for c in collections)
    
    return jsonify({
        "history": data,
        "has_entry_today": has_today
    }), 200