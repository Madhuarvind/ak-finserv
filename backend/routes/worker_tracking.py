from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from models import db, User, UserRole
from datetime import datetime

tracking_bp = Blueprint("tracking", __name__)

@tracking_bp.route("/update-tracking", methods=["POST"])
@jwt_required()
def update_tracking():
    """Update field agent's current location and status"""
    identity = get_jwt_identity()
    data = request.get_json()
    
    # Resolve user from identity (can be name, mobile, id, or username)
    user = User.query.filter(
        (User.id == identity) | 
        (User.name == identity) | 
        (User.mobile_number == identity) | 
        (User.username == identity)
    ).first()
    
    if not user:
        return jsonify({"msg": "user_not_found"}), 404
        
    user.last_latitude = data.get("latitude")
    user.last_longitude = data.get("longitude")
    user.last_location_update = datetime.utcnow()
    
    if "duty_status" in data:
        user.duty_status = data["duty_status"]
        
    if "activity" in data:
        user.current_activity = data["activity"]
        
    db.session.commit()
    return jsonify({"msg": "tracking_updated", "status": user.duty_status}), 200

@tracking_bp.route("/field-map", methods=["GET"])
@jwt_required()
def get_field_map():
    """Get all agents' last known positions (Admin only)"""
    identity = get_jwt_identity()
    admin = User.query.filter(
        (User.id == identity) | 
        (User.name == identity) | 
        (User.mobile_number == identity) | 
        (User.username == identity)
    ).first()
    
    if not admin:
        return jsonify({"msg": "unauthorized"}), 403
        
    current_role = admin.role.value if hasattr(admin.role, 'value') else admin.role
    if current_role != UserRole.ADMIN.value:
        return jsonify({"msg": "unauthorized"}), 403
        
    agents = User.query.filter_by(role=UserRole.FIELD_AGENT, is_active=True).all()
    
    result = []
    for agent in agents:
        result.append({
            "id": agent.id,
            "name": agent.name,
            "mobile": agent.mobile_number,
            "latitude": agent.last_latitude,
            "longitude": agent.last_longitude,
            "last_update": agent.last_location_update.isoformat() if agent.last_location_update else None,
            "status": agent.duty_status,
            "activity": agent.current_activity
        })
        
    return jsonify(result), 200
