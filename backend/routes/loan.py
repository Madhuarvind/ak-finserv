from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from models import db, User, Loan, EMISchedule, LoanAuditLog, Collection
from datetime import datetime
from utils.auth_helpers import get_user_by_identity
from utils.interest_utils import (
    calculate_flat_emi,
    calculate_reducing_emi,
    generate_dates,
)

loan_bp = Blueprint("loan", __name__)


@loan_bp.route("/create", methods=["POST"])
@jwt_required()
def create_loan():
    identity = get_jwt_identity()
    user = get_user_by_identity(identity)

    if not user:
        return jsonify({"msg": "User not found"}), 404

    data = request.get_json()
    customer_id = data.get("customer_id")
    amount = data.get("principal_amount") or data.get("amount")
    interest_rate = data.get("interest_rate", 10.0)
    tenure = data.get("tenure", 100)
    tenure_unit = data.get("tenure_unit", "days")
    interest_type = data.get("interest_type", "flat")
    processing_fee = data.get("processing_fee", 0.0)

    # Anti-Fraud: One Active Loan Rule (Removed as per user request for multi-loan support)
    # existing_loan = Loan.query.filter_by(
    #     customer_id=customer_id, status="active"
    # ).first()
    # if existing_loan and not data.get("override_active_loan"):
    #     return (
    #         jsonify(
    #             {"msg": "Customer already has an active loan", "code": "DUPLICATE_LOAN"}
    #         ),
    #         400,
    #     )

    if not customer_id or not amount:
        return jsonify({"msg": "Customer ID and Amount are required"}), 400

    try:
        # Generate Temporary Loan ID logic
        year = datetime.utcnow().year
        # Fixed for PostgreSQL compatibility
        try:
             count = Loan.query.filter(
                db.extract('year', Loan.created_at) == year
            ).count()
        except:
             # Fallback
             count = Loan.query.filter(Loan.created_at >= datetime(year, 1, 1)).count()

        loan_id_str = f"LN-{year}-{count + 1:06d}"

        new_loan = Loan(
            loan_id=loan_id_str,
            customer_id=customer_id,
            principal_amount=amount,
            interest_rate=interest_rate,
            interest_type=interest_type,
            tenure=tenure,
            tenure_unit=tenure_unit,
            processing_fee=processing_fee,
            pending_amount=amount,  # Initially same as principal until approved/interest added
            status="created",  # DRAFT
            created_by=user.id,
            assigned_worker_id=data.get("assigned_worker_id", user.id),
            guarantor_name=data.get("guarantor_name"),
            guarantor_mobile=data.get("guarantor_mobile"),
            guarantor_relation=data.get("guarantor_relation"),
            created_at=datetime.utcnow(),
        )

        db.session.add(new_loan)
        db.session.flush()  # Ensure new_loan.id is populated for the audit log

        # Audit Log
        audit = LoanAuditLog(
            loan_id=new_loan.id,
            action="LOAN_CREATED",
            performed_by=user.id,
            new_status="created",
            remarks="Loan draft created",
        )
        db.session.add(audit)
        db.session.commit()

        return (
            jsonify(
                {
                    "msg": "Loan draft created successfully",
                    "loan_id": loan_id_str,
                    "id": new_loan.id,
                }
            ),
            201,
        )

    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": str(e)}), 500


@loan_bp.route("/<int:id>/approve", methods=["PATCH"])
@jwt_required()
def approve_loan(id):
    identity = get_jwt_identity()
    user = get_user_by_identity(identity)
    
    # Normalize role check
    current_role = user.role.value if hasattr(user.role, 'value') else user.role
    if current_role != "admin" and current_role != UserRole.ADMIN.value:
         return jsonify({"msg": "Admin access required"}), 403

    loan = Loan.query.get_or_404(id)
    if loan.status != "created":
        return jsonify({"msg": f"Cannot approve loan in {loan.status} status"}), 400

    data = request.get_json()
    start_date = data.get("start_date")
    if start_date:
        loan.start_date = datetime.fromisoformat(start_date)
    else:
        loan.start_date = datetime.utcnow()

    # Generate EMI Schedule
    if loan.interest_type == "reducing":
        schedule_data = calculate_reducing_emi(
            loan.principal_amount, loan.interest_rate, loan.tenure, loan.tenure_unit
        )
    else:
        schedule_data = calculate_flat_emi(
            loan.principal_amount, loan.interest_rate, loan.tenure, loan.tenure_unit
        )

    due_dates = generate_dates(loan.start_date, loan.tenure, loan.tenure_unit)

    total_payable = 0
    for i, entry in enumerate(schedule_data):
        emi = EMISchedule(
            loan_id=loan.id,
            emi_no=entry["emi_no"],
            due_date=due_dates[i],
            amount=entry["amount"],
            principal_part=entry["principal_part"],
            interest_part=entry["interest_part"],
            balance=entry["balance"],
        )
        db.session.add(emi)
        total_payable += entry["amount"]

    loan.pending_amount = total_payable
    loan.status = "approved"
    loan.approved_by = user.id

    # Audit Log
    audit = LoanAuditLog(
        loan_id=loan.id,
        action="LOAN_APPROVED",
        performed_by=user.id,
        old_status="created",
        new_status="approved",
    )
    db.session.add(audit)
    db.session.commit()

    return jsonify({"msg": "Loan approved and schedule generated"}), 200


@loan_bp.route("/<int:id>", methods=["GET"])
@jwt_required()
def get_loan(id):
    loan = Loan.query.get_or_404(id)

    # helper to format schedule
    schedule = [
        {
            "id": entry.id,
            "emi_no": entry.emi_no,
            "due_date": entry.due_date.strftime("%Y-%m-%d"),
            "amount": entry.amount,
            "status": entry.status,
        }
        for entry in loan.emi_schedule
    ]

    return (
        jsonify(
            {
                "id": loan.id,
                "loan_id": loan.loan_id,
                "customer_id": loan.customer_id,
                "principal_amount": loan.principal_amount,
                "interest_rate": loan.interest_rate,
                "interest_type": loan.interest_type,
                "tenure": loan.tenure,
                "tenure_unit": loan.tenure_unit,
                "processing_fee": loan.processing_fee,
                "pending_amount": loan.pending_amount,
                "status": loan.status,
                "start_date": (
                    loan.start_date.isoformat() + "Z" if loan.start_date else None
                ),
                "emi_schedule": schedule,
            }
        ),
        200,
    )


@loan_bp.route("/<int:id>/activate", methods=["PATCH"])
@jwt_required()
def activate_loan(id):
    loan = Loan.query.get_or_404(id)
    if loan.status != "approved":
        return jsonify({"msg": "Only approved loans can be activated"}), 400

    loan.status = "active"
    db.session.commit()

    return jsonify({"msg": "Loan is now ACTIVE"}), 200


@loan_bp.route("/<int:id>/foreclose", methods=["POST"])
@jwt_required()
def foreclose_loan(id):
    """Foreclose/Settle a loan early"""
    identity = get_jwt_identity()
    user = get_user_by_identity(identity)

    loan = Loan.query.get_or_404(id)
    if loan.status != "active":
        return jsonify({"msg": "Only active loans can be foreclosed"}), 400

    data = request.get_json()
    settlement_amount = data.get("settlement_amount")
    reason = data.get("reason", "Foreclosure")

    if settlement_amount is None:
        return jsonify({"msg": "Settlement amount is required"}), 400

    try:
        # 1. Create Collection Entry for the settlement
        collection = Collection(
            loan_id=loan.id,
            customer_id=loan.customer_id,
            amount_collected=settlement_amount,
            collected_by=user.id,
            collected_at=datetime.utcnow(),
            notes=f"Foreclosure Settlement. Reason: {reason}",
        )
        db.session.add(collection)

        # 2. Close the Loan
        loan.status = "closed"
        loan.pending_amount = 0

        # 3. Mark all unpaid EMIs as 'closed' (or similar)
        # For simplicity, we just leave them or mark them paid?
        # Better to just mark the loan closed. The EMIs are now irrelevant.

        # 4. Audit Log
        audit = LoanAuditLog(
            loan_id=loan.id,
            action="LOAN_FORECLOSED",
            performed_by=user.id,
            old_status="active",
            new_status="closed",
            remarks=f"Settled for {settlement_amount}. {reason}",
        )
        db.session.add(audit)

        db.session.commit()
        return jsonify({"msg": "Loan foreclosed successfully"}), 200

    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": str(e)}), 500


@loan_bp.route("/all", methods=["GET"])
@jwt_required()
def get_all_loans():
    identity = get_jwt_identity()
    user = get_user_by_identity(identity)

    status_filter = request.args.get("status")

    query = Loan.query
    # Normalize role check
    current_role = user.role.value if hasattr(user.role, 'value') else user.role
    if current_role != "admin" and current_role != UserRole.ADMIN.value:
        # Workers see their assigned loans
        query = query.filter_by(assigned_worker_id=user.id)

    if status_filter:
        query = query.filter_by(status=status_filter)

    loans = query.order_by(Loan.created_at.desc()).all()

    return jsonify(
        [
            {
                "id": loan.id,
                "loan_id": loan.loan_id,
                "customer_name": loan.customer.name if loan.customer else "Unknown",
                "principal_amount": loan.principal_amount,
                "interest_rate": loan.interest_rate,
                "interest_type": loan.interest_type,
                "tenure": loan.tenure,
                "tenure_unit": loan.tenure_unit,
                "status": loan.status,
                "created_at": loan.created_at.isoformat() + "Z",
            }
            for loan in loans
        ]
    )
