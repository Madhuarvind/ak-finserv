from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from models import (
    db,
    User,
    Customer,
    Line,
    LineCustomer,
    UserRole,
    Loan,
    EMISchedule,
    Collection,
)
from datetime import datetime
from utils.interest_utils import get_distance_meters
from utils.ml_risk import risk_engine


line_bp = Blueprint("line", __name__)


@line_bp.route("/create", methods=["POST"])
@jwt_required()
def create_line():
    identity = get_jwt_identity()
    admin = User.query.filter(
        (User.username == identity)
        | (User.id == identity)
        | (User.mobile_number == identity)
    ).first()

    if not admin or admin.role != UserRole.ADMIN:
        return jsonify({"msg": "Access Denied"}), 403

    data = request.get_json()
    name = data.get("name")
    area = data.get("area")
    agent_id = data.get("agent_id")

    if not name or not area:
        return jsonify({"msg": "Line Name and Area are required"}), 400

    if Line.query.filter_by(name=name).first():
        return jsonify({"msg": "Line name already exists"}), 400

    new_line = Line(
        name=name,
        area=area,
        agent_id=agent_id,
        working_days=data.get("working_days", "Mon-Sat"),
        start_time=data.get("start_time"),
        end_time=data.get("end_time"),
    )

    db.session.add(new_line)
    db.session.commit()

    return jsonify({"msg": "line_created_successfully", "id": new_line.id}), 201


@line_bp.route("/all", methods=["GET"])
@jwt_required()
def get_all_lines():
    identity = get_jwt_identity()
    user = User.query.filter(
        (User.username == identity)
        | (User.id == identity)
        | (User.mobile_number == identity)
    ).first()

    if not user:
        return jsonify({"msg": "User not found"}), 404

    # Admins see all lines, Agents see only their assigned lines
    if user.role == UserRole.ADMIN:
        lines = Line.query.all()
    else:
        lines = Line.query.filter_by(agent_id=user.id).all()

    return (
        jsonify(
            [
                {
                    "id": sub_loan.id,
                    "name": sub_loan.name,
                    "area": sub_loan.area,
                    "agent_id": sub_loan.agent_id,
                    "is_locked": sub_loan.is_locked,
                    "customer_count": len(sub_loan.customers),
                }
                for sub_loan in lines
            ]
        ),
        200,
    )


@line_bp.route("/<int:line_id>/assign-agent", methods=["POST"])
@jwt_required()
def assign_agent(line_id):
    identity = get_jwt_identity()
    admin = User.query.filter(
        (User.username == identity)
        | (User.id == identity)
        | (User.mobile_number == identity)
    ).first()

    if not admin or admin.role != UserRole.ADMIN:
        return jsonify({"msg": "Access Denied"}), 403

    data = request.get_json()
    agent_id = data.get("agent_id")

    line = Line.query.get(line_id)
    if not line:
        return jsonify({"msg": "Line not found"}), 404

    line.agent_id = agent_id
    db.session.commit()

    return jsonify({"msg": "agent_assigned_successfully"}), 200


@line_bp.route("/<int:line_id>/add-customer", methods=["POST"])
@jwt_required()
def add_customer_to_line(line_id):
    identity = get_jwt_identity()
    admin = User.query.filter(
        (User.username == identity)
        | (User.id == identity)
        | (User.mobile_number == identity)
    ).first()

    if not admin or admin.role != UserRole.ADMIN:
        return jsonify({"msg": "Access Denied"}), 403

    data = request.get_json()
    customer_id = data.get("customer_id")

    line = Line.query.get(line_id)
    if not line:
        return jsonify({"msg": "Line not found"}), 404

    # Check if customer already in another active line? (User rule 3.3)
    # For now, just allow mapping

    # Calculate next sequence order
    max_seq = (
        db.session.query(db.func.max(LineCustomer.sequence_order))
        .filter_by(line_id=line_id)
        .scalar()
        or 0
    )

    new_mapping = LineCustomer(
        line_id=line_id, customer_id=customer_id, sequence_order=max_seq + 1
    )

    db.session.add(new_mapping)
    db.session.commit()

    return jsonify({"msg": "customer_added_to_line"}), 201


@line_bp.route("/<int:line_id>/customers", methods=["GET"])
@jwt_required()
def get_line_customers(line_id):
    line = Line.query.get(line_id)
    if not line:
        return jsonify({"msg": "Line not found"}), 404

    customers_mapping = (
        LineCustomer.query.filter_by(line_id=line_id)
        .order_by(LineCustomer.sequence_order)
        .all()
    )

    return (
        jsonify(
            [
                {
                    "id": m.customer.id,
                    "name": m.customer.name,
                    "mobile": m.customer.mobile_number,
                    "area": m.customer.area,
                    "sequence": m.sequence_order,
                }
                for m in customers_mapping
            ]
        ),
        200,
    )


@line_bp.route("/<int:line_id>/reorder", methods=["POST"])
@jwt_required()
def reorder_line_customers(line_id):
    identity = get_jwt_identity()
    admin = User.query.filter(
        (User.username == identity)
        | (User.id == identity)
        | (User.mobile_number == identity)
    ).first()

    if not admin or admin.role != UserRole.ADMIN:
        return jsonify({"msg": "Access Denied"}), 403

    data = request.get_json()
    customer_order = data.get("order")  # List of customer IDs in new order

    if not customer_order:
        return jsonify({"msg": "Order required"}), 400

    for index, customer_id in enumerate(customer_order):
        mapping = LineCustomer.query.filter_by(
            line_id=line_id, customer_id=customer_id
        ).first()
        if mapping:
            mapping.sequence_order = index + 1

    db.session.commit()
    return jsonify({"msg": "Order updated successfully"}), 200


@line_bp.route("/<int:line_id>/lock", methods=["PATCH"])
@jwt_required()
def toggle_line_lock(line_id):
    identity = get_jwt_identity()
    admin = User.query.filter(
        (User.username == identity)
        | (User.id == identity)
        | (User.mobile_number == identity)
    ).first()

    if not admin or admin.role != UserRole.ADMIN:
        return jsonify({"msg": "Access Denied"}), 403

    line = Line.query.get(line_id)
    if not line:
        return jsonify({"msg": "Line not found"}), 404

    line.is_locked = not line.is_locked
    db.session.commit()

    return jsonify({"msg": "line_status_updated", "is_locked": line.is_locked}), 200


@line_bp.route("/<int:line_id>/optimize", methods=["POST"])
@jwt_required()
def optimize_line_route(line_id):
    """
    AI-Powered Route Optimization
    Calculates priority based on: Proximity (40%) and AI Risk Score (60%)
    """
    data = request.get_json()
    current_lat = data.get("latitude")
    current_lng = data.get("longitude")

    Line.query.get_or_404(line_id)
    mappings = LineCustomer.query.filter_by(line_id=line_id).all()

    results = []
    today = datetime.utcnow()

    for mapping in mappings:
        customer = mapping.customer
        # 1. Fetch AI Risk Score for this customer's active loan
        active_loan = Loan.query.filter_by(
            customer_id=customer.id, status="active"
        ).first()

        risk_score = 0
        if active_loan:
            # Simplified feature extraction for speed
            missed = EMISchedule.query.filter(
                EMISchedule.loan_id == active_loan.id,
                EMISchedule.status != "paid",
                EMISchedule.due_date < today,
            ).count()

            last_pay = (
                Collection.query.filter_by(loan_id=active_loan.id, status="approved")
                .order_by(Collection.created_at.desc())
                .first()
            )
            days_since = (today - last_pay.created_at).days if last_pay else 30

            # utilization = (pending/principal)*100
            util = (
                (active_loan.pending_amount / active_loan.principal_amount * 100)
                if active_loan.principal_amount > 0
                else 50
            )

            prob, _ = risk_engine.predict_risk(missed, missed * 10, days_since, 0, util)
            risk_score = prob

        # 2. Proximity Analysis
        dist_score = 0
        distance = None
        if current_lat and current_lng and customer.latitude and customer.longitude:
            distance = get_distance_meters(
                current_lat, current_lng, customer.latitude, customer.longitude
            )
            # Normalize distance (closer = higher score). 0m = 100, 5000m+ = 0
            dist_score = max(0, 100 - (distance / 50))

        # 3. Final AI Priority Calculation
        # Priority = (Proximity * 0.4) + (Risk * 0.6)
        # We prioritize high-risk customers who are close by
        priority = (dist_score * 0.4) + (risk_score * 0.6)

        results.append(
            {
                "id": customer.id,
                "name": customer.name,
                "mobile": customer.mobile_number,
                "area": customer.area,
                "sequence": mapping.sequence_order,
                "risk_score": round(risk_score, 1),
                "distance_meters": round(distance) if distance is not None else None,
                "ai_priority": round(priority, 1),
            }
        )

    # Sort by AI Priority (Highest first)
    results.sort(key=lambda x: x["ai_priority"], reverse=True)

    return jsonify(results), 200


@line_bp.route("/bulk-reassign", methods=["POST"])
@jwt_required()
def bulk_reassign_agent():
    """Swap all customers and lines from one agent to another"""
    identity = get_jwt_identity()
    admin = User.query.filter(
        (User.mobile_number == identity)
        | (User.username == identity)
        | (User.id == identity)
    ).first()

    if not admin or admin.role != UserRole.ADMIN:
        return jsonify({"msg": "Access Denied"}), 403

    data = request.get_json()
    from_agent_id = data.get("from_agent_id")
    to_agent_id = data.get("to_agent_id")

    if not from_agent_id or not to_agent_id:
        return jsonify({"msg": "Both source and target agents are required"}), 400

    try:
        # 1. Update all Lines assigned to the agent
        lines_updated = Line.query.filter_by(agent_id=from_agent_id).update(
            {Line.agent_id: to_agent_id}
        )

        # 2. Update all Customers assigned to the agent (for direct oversight)
        customers_updated = Customer.query.filter_by(
            assigned_worker_id=from_agent_id
        ).update({Customer.assigned_worker_id: to_agent_id})

        db.session.commit()

        return (
            jsonify(
                {
                    "msg": "bulk_reassignment_successful",
                    "lines_affected": lines_updated,
                    "customers_affected": customers_updated,
                }
            ),
            200,
        )

    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": str(e)}), 500
