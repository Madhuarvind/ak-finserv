from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from models import db, User, Collection, DailySettlement, UserRole
from datetime import datetime, date
from sqlalchemy import func

settlement_bp = Blueprint("settlement", __name__)


@settlement_bp.route("/today", methods=["GET"])
@jwt_required()
def get_todays_status():
    """
    Get list of agents and their collection status for today.
    """
    identity = get_jwt_identity()
    user = User.query.filter(
        (User.mobile_number == identity)
        | (User.username == identity)
        | (User.id == identity)
    ).first()

    if not user or user.role != UserRole.ADMIN:
        return jsonify({"msg": "Access Denied"}), 403

    today = date.today()

    # 1. Get all agents
    agents = User.query.filter_by(role=UserRole.FIELD_AGENT).all()

    result = []

    for agent in agents:
        # 2. Calculate System Cash for today
        # Only sum 'cash' collections
        total_cash = (
            db.session.query(func.sum(Collection.amount))
            .filter(Collection.agent_id == agent.id)
            .filter(func.date(Collection.created_at) == today)
            .filter(Collection.payment_mode == "cash")
            .scalar()
            or 0.0
        )

        # 3. Check if settlement exists
        settlement = DailySettlement.query.filter_by(
            agent_id=agent.id, date=today
        ).first()

        agent_data = {
            "agent_id": agent.id,
            "agent_name": agent.name,
            "system_cash": total_cash,
            "status": "pending",
        }

        if settlement:
            agent_data.update(
                {
                    "status": settlement.status,
                    "physical_cash": settlement.physical_cash,
                    "expenses": settlement.expenses,
                    "difference": settlement.difference,
                    "notes": settlement.notes,
                    "verified_at": (
                        settlement.verified_at.isoformat()
                        if settlement.verified_at
                        else None
                    ),
                }
            )

        result.append(agent_data)

    return jsonify(result), 200


@settlement_bp.route("/verify", methods=["POST"])
@jwt_required()
def verify_settlement():
    identity = get_jwt_identity()
    admin = User.query.filter(
        (User.mobile_number == identity)
        | (User.username == identity)
        | (User.id == identity)
    ).first()

    if not admin or admin.role != UserRole.ADMIN:
        return jsonify({"msg": "Access Denied"}), 403

    data = request.get_json()
    agent_id = data.get("agent_id")
    physical_cash = float(data.get("physical_cash", 0))
    expenses = float(data.get("expenses", 0))
    notes = data.get("notes", "")

    today = date.today()

    # Recalculate system cash to be safe
    system_cash = (
        db.session.query(func.sum(Collection.amount))
        .filter(Collection.agent_id == agent_id)
        .filter(func.date(Collection.created_at) == today)
        .filter(Collection.payment_mode == "cash")
        .scalar()
        or 0.0
    )

    difference = (physical_cash + expenses) - system_cash

    settlement = DailySettlement.query.filter_by(agent_id=agent_id, date=today).first()

    if settlement:
        settlement.physical_cash = physical_cash
        settlement.expenses = expenses
        settlement.difference = difference
        settlement.notes = notes
        settlement.status = "verified"
        settlement.verified_by = admin.id
        settlement.verified_at = datetime.utcnow()
    else:
        settlement = DailySettlement(
            agent_id=agent_id,
            date=today,
            system_cash=system_cash,
            physical_cash=physical_cash,
            expenses=expenses,
            difference=difference,
            notes=notes,
            status="verified",
            verified_by=admin.id,
            verified_at=datetime.utcnow(),
        )
        db.session.add(settlement)

    db.session.commit()

    return (
        jsonify({"msg": "Settlement verified successfully", "difference": difference}),
        200,
    )


@settlement_bp.route("/history", methods=["GET"])
@jwt_required()
def get_settlement_history():
    identity = get_jwt_identity()
    user = User.query.filter(
        (User.mobile_number == identity)
        | (User.username == identity)
        | (User.id == identity)
    ).first()

    if not user or user.role != UserRole.ADMIN:
        return jsonify({"msg": "Access Denied"}), 403

    settlements = (
        db.session.query(DailySettlement, User.name.label("agent_name"))
        .join(User, DailySettlement.agent_id == User.id)
        .order_by(DailySettlement.date.desc())
        .all()
    )

    result = []
    for s, agent_name in settlements:
        res = {
            "id": s.id,
            "agent_name": agent_name,
            "date": s.date.isoformat(),
            "system_cash": s.system_cash,
            "physical_cash": s.physical_cash,
            "expenses": s.expenses,
            "difference": s.difference,
            "notes": s.notes,
            "status": s.status,
            "verified_at": s.verified_at.isoformat() if s.verified_at else None,
        }
        result.append(res)

    return jsonify(result), 200
