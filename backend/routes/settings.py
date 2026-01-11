from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from models import db, SystemSetting, User, UserRole


settings_bp = Blueprint("settings", __name__)

DEFAULTS = {
    "default_interest_rate": "10.0",
    "penalty_amount": "50.0",
    "grace_period_days": "3",
    "max_loan_amount": "50000.0",
    "emi_frequency_options": "['daily', 'weekly', 'monthly']",
    "worker_can_edit_customer": "false",
    "upi_id": "arun.finance@okaxis",
    "upi_qr_url": "",
}


def get_admin_user():
    identity = get_jwt_identity()
    user = User.query.filter(
        (User.username == identity) | (User.id == identity)
    ).first()
    if user and user.role == UserRole.ADMIN:
        return user
    return None


@settings_bp.route("/", methods=["GET"])
@jwt_required()
def get_settings():
    """Get all system settings, seeding defaults if missing"""
    try:
        settings = SystemSetting.query.all()
        settings_dict = {s.key: s.value for s in settings}

        # Seed defaults if missing
        changed = False
        for key, value in DEFAULTS.items():
            if key not in settings_dict:
                new_setting = SystemSetting(
                    key=key, value=str(value), description=key.replace("_", " ").title()
                )
                db.session.add(new_setting)
                settings_dict[key] = str(value)
                changed = True

        if changed:
            db.session.commit()

        return jsonify(settings_dict), 200
    except Exception as e:
        return jsonify({"msg": str(e)}), 500


@settings_bp.route("/", methods=["PUT"])
@jwt_required()
def update_settings():
    """Update multiple settings at once"""
    user = get_admin_user()
    if not user:
        return jsonify({"msg": "Admin access required"}), 403

    data = request.get_json()
    try:
        for key, value in data.items():
            setting = SystemSetting.query.get(key)
            if setting:
                setting.value = str(value)
            else:
                # Should not happen typically if seeded, but handle it
                setting = SystemSetting(key=key, value=str(value))
                db.session.add(setting)

        db.session.commit()
        return jsonify({"msg": "Settings updated successfully"}), 200
    except Exception as e:
        return jsonify({"msg": str(e)}), 500
