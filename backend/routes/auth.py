from flask import Blueprint, request, jsonify
from extensions import db
from models import User, UserRole, LoginLog, Device, OTPLog, FaceEmbedding
from flask_jwt_extended import (
    create_access_token,
    create_refresh_token,
    jwt_required,
    get_jwt_identity,
)
import bcrypt

from datetime import datetime, timedelta
from utils.auth_helpers import get_user_by_identity

auth_bp = Blueprint("auth", __name__)
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@auth_bp.route("/set-pin", methods=["POST"])
def set_pin():
    data = request.get_json()
    name = data.get(
        "name", ""
    ).strip()  # Usually get from JWT identity in real scenario
    pin = data.get("pin")

    if not pin or len(pin) != 4:
        return jsonify({"msg": "4-digit PIN required"}), 400

    user = User.query.filter(User.name.ilike(name)).first()
    if not user:
        return jsonify({"msg": "User not found"}), 404

    hashed_pin = bcrypt.hashpw(pin.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")
    user.pin_hash = hashed_pin
    user.is_first_login = False
    db.session.commit()

    return jsonify({"msg": "PIN Set Successfully"}), 200


@auth_bp.route("/login-pin", methods=["POST"])
def login_pin():
    try:
        data = request.get_json()
        name = data.get("name", "").strip()
        pin = data.get("pin")

        if not name or not pin:
            return jsonify({"msg": "Name and PIN are required"}), 400

        print(f"Login attempt for: {name}")

        user = User.query.filter(User.name.ilike(name)).first()

        if not user:
            print(f"User not found: {name}")
            return jsonify({"msg": "invalid_login"}), 401

        if not user.is_active:
            return jsonify({"msg": "user_inactive"}), 403

        if user.is_locked:
            return jsonify({"msg": "Account locked"}), 403

        if not user.pin_hash:
            return jsonify({"msg": "PIN not set"}), 401

        # Direct PIN check mirroring Admin Login pattern
        if bcrypt.checkpw(pin.encode("utf-8"), user.pin_hash.encode("utf-8")):
            # User PIN is correct. Now check Device Security.
            device_id = data.get("device_id")

            # Check if this user has any face data registered (Biometric Enabled)
            from models import FaceEmbedding

            has_biometrics = (
                FaceEmbedding.query.filter_by(user_id=user.id).first() is not None
            )

            if has_biometrics:
                # If biometrics enabled, enforce Trusted Device policy
                if not device_id:
                    return (
                        jsonify(
                            {
                                "msg": "requires_face_verification",
                                "reason": "new_device",
                                "name": user.name,
                            }
                        ),
                        200,
                    )

                trusted_device = Device.query.filter_by(
                    user_id=user.id, device_id=device_id, is_trusted=True
                ).first()
                if not trusted_device:
                    # PIN is good, but Device is Unknown -> Require Face
                    return (
                        jsonify(
                            {
                                "msg": "requires_face_verification",
                                "reason": "new_device",
                                "name": user.name,
                            }
                        ),
                        200,
                    )

            # If no biometrics or Device is Trusted -> Log in
            user.last_login = datetime.utcnow()

            # Update device last active if exists
            if device_id:
                dev = Device.query.filter_by(
                    user_id=user.id, device_id=device_id
                ).first()
                if dev:
                    dev.last_active = datetime.utcnow()

            # Simple Audit success login
            log = LoginLog(
                user_id=user.id,
                status="success",
                ip_address=request.remote_addr,
                device_info=device_id or "Unknown",
            )
            db.session.add(log)
            db.session.commit()

            access_token = create_access_token(identity=str(user.id))
            refresh_token = create_refresh_token(identity=str(user.id))

            # Resolve role value safely
            current_role = user.role.value if hasattr(user.role, 'value') else str(user.role)

            print(f"Login success for: {name}")
            return (
                jsonify(
                    {
                        "msg": "Login success",
                        "access_token": access_token,
                        "refresh_token": refresh_token,
                        "role": current_role,
                        "is_active": user.is_active,
                        "is_locked": user.is_locked,
                    }
                ),
                200,
            )
        else:
            print(f"Login failed: Invalid PIN for {name}")
            return jsonify({"msg": "invalid_pin"}), 401

    except Exception as e:
        print(f"Login Pin Error: {str(e)}")
        # Return error details temporarily to help debugging
        return jsonify({"msg": "server_error", "error": str(e)}), 500


@auth_bp.route("/verify-face-login", methods=["POST"])
def verify_face_login():
    try:
        # 1. Get identifier (name or uid)
        name = request.form.get("name", "").strip()
        device_id = request.form.get("device_id")

        if "file" not in request.files or not name:
            return jsonify({"msg": "Missing face file or name"}), 400

        file = request.files["file"]
        image_bytes = file.read()

        user = User.query.filter(User.name.ilike(name)).first()
        if not user:
            return jsonify({"msg": "Invalid Login"}), 401

        # 2. Get registered face
        from models import FaceEmbedding

        stored_face = FaceEmbedding.query.filter_by(user_id=user.id).first()
        if not stored_face:
            return jsonify({"msg": "Face not registered"}), 401

        # 3. Real ML Verification
        from utils.face_utils import generate_face_embedding, compare_embeddings

        current_embedding, error = generate_face_embedding(image_bytes)

        if error:
            return jsonify({"msg": f"AI Error: {error}"}), 422

        # Check for model version mismatch (e.g. 128-d vs 1280-d)
        stored_emb = stored_face.embedding_data

        if len(stored_emb) != len(current_embedding):
            return (
                jsonify(
                    {
                        "msg": "Security model updated. Please re-register your face from an admin account."
                    }
                ),
                400,
            )

        similarity = compare_embeddings(stored_emb, current_embedding)

        # Threshold for MobileNetV2 features (tuned for reliability)
        if similarity >= 0.75:
            # Face verified -> Trust this device
            if device_id:
                device = Device.query.filter_by(
                    user_id=user.id, device_id=device_id
                ).first()
                if not device:
                    device = Device(
                        user_id=user.id,
                        device_id=device_id,
                        device_name="Verified Device",
                        is_trusted=True,
                    )
                    db.session.add(device)
                else:
                    device.is_trusted = True
                    device.last_active = datetime.utcnow()
                db.session.commit()

            access_token = create_access_token(identity=name)
            refresh_token = create_refresh_token(identity=name)

            return (
                jsonify(
                    {
                        "msg": "face_verified",
                        "access_token": access_token,
                        "refresh_token": refresh_token,
                        "role": user.role.value,
                    }
                ),
                200,
            )
        else:
            return (
                jsonify({"msg": f"Face Mismatch (Score: {round(similarity, 2)})"}),
                401,
            )

    except Exception as e:
        return jsonify({"msg": "server_error", "error": str(e)}), 500


@auth_bp.route("/admin-login", methods=["POST"])
def admin_login():
    data = request.get_json()
    username = data.get("username", "").strip()
    password = data.get("password", "").strip()

    if not username or not password:
        return jsonify({"msg": "Username and password required"}), 400

    user = User.query.filter(
        (User.username == username) | (User.name == username)
    ).first()
    if not user:
        print(f"DEBUG: Admin login failed - User '{username}' not found in DB")
        return jsonify({"msg": f"Access Denied: User '{username}' not found"}), 403

    # Normalize role check
    current_role = user.role.value if hasattr(user.role, 'value') else str(user.role)
    if current_role != "admin" and current_role != UserRole.ADMIN.value:
        print(
            f"DEBUG: Admin login failed - User '{username}' has role {current_role}, expected {UserRole.ADMIN.value}"
        )
        return jsonify({"msg": f"Access Denied: Incorrect role {current_role}"}), 403

    if not user.password_hash or not bcrypt.checkpw(
        password.encode("utf-8"), user.password_hash.encode("utf-8")
    ):
        # Audit failed login
        log = LoginLog(
            user_id=user.id,
            status="failed",
            device_info=request.headers.get("User-Agent"),
            ip_address=request.remote_addr,
        )
        db.session.add(log)
        db.session.commit()
        return jsonify({"msg": "Invalid Password"}), 401

    # Direct login success - no OTP
    user.last_login = datetime.utcnow()

    # Audit success login
    log = LoginLog(
        user_id=user.id,
        status="success",
        device_info=request.headers.get("User-Agent"),
        ip_address=request.remote_addr,
    )
    db.session.add(log)
    db.session.commit()

    access_token = create_access_token(identity=username)
    refresh_token = create_refresh_token(identity=username)

    return (
        jsonify(
            {
                "msg": "Login success",
                "access_token": access_token,
                "refresh_token": refresh_token,
                "role": user.role.value if hasattr(user.role, 'value') else str(user.role),
                "is_active": user.is_active,
                "is_locked": user.is_locked,
            }
        ),
        200,
    )


@auth_bp.route("/admin-verify", methods=["POST"])
def admin_verify():
    data = request.get_json()
    mobile_number = data.get("mobile_number")
    otp_code = data.get("otp")

    otp_entry = OTPLog.query.filter_by(
        mobile_number=mobile_number, otp_code=otp_code, is_used=False
    ).first()

    if not otp_entry or otp_entry.expires_at < datetime.utcnow():
        return jsonify({"msg": "Invalid or expired OTP"}), 400

    otp_entry.is_used = True
    user = User.query.filter_by(mobile_number=mobile_number).first()
    user.last_login = datetime.utcnow()

    # Audit success login
    log = LoginLog(
        user_id=user.id,
        status="success",
        device_info=request.headers.get("User-Agent"),
        ip_address=request.remote_addr,
    )
    db.session.add(log)
    db.session.commit()

    access_token = create_access_token(identity=mobile_number)
    refresh_token = create_refresh_token(identity=mobile_number)

    return (
        jsonify(
            {
                "msg": "Login success",
                "access_token": access_token,
                "refresh_token": refresh_token,
                "role": user.role.value if hasattr(user.role, 'value') else str(user.role),
            }
        ),
        200,
    )


@auth_bp.route("/refresh-token", methods=["POST"])
@jwt_required(refresh=True)
def refresh_token():
    current_user = get_jwt_identity()
    new_token = create_access_token(identity=current_user)
    return jsonify({"access_token": new_token}), 200


@auth_bp.route("/register-worker", methods=["POST"])
@jwt_required()
def register_worker():
    # Safe lookup
    identity = get_jwt_identity()
    admin = get_user_by_identity(identity)
    
    logger.info(f"Register Worker Request by: {identity}")

    if not admin:
        logger.error(f"Access Denied: Admin user not found for identity {identity}")
        return jsonify({"msg": "Access Denied"}), 403

    # Ensure role comparison works for both Enum object and string value from DB
    current_role = admin.role.value if hasattr(admin.role, 'value') else str(admin.role)
    if current_role != "admin" and current_role != UserRole.ADMIN.value:
         logger.error(f"Access Denied: User {admin.name} has role {current_role}, expected {UserRole.ADMIN.value}")
         return jsonify({"msg": "Access Denied"}), 403

    data = request.get_json()
    name = data.get("name", "").strip()
    mobile = data.get("mobile_number", "").strip()
    pin = data.get("pin")
    area = data.get("area")
    address = data.get("address")
    id_proof = data.get("id_proof")
    role_str = data.get("role", "field_agent")
    manager_id = data.get("manager_id")

    if not mobile or not pin or not name:
        return jsonify({"msg": "Name, mobile and PIN are required"}), 400

    if User.query.filter_by(mobile_number=mobile).first():
        return jsonify({"msg": "Mobile number already exists"}), 400

    if User.query.filter(User.name.ilike(name)).first():
        return jsonify({"msg": "Worker name already exists"}), 400

    try:
        role = UserRole(role_str)
    except ValueError:
        return jsonify({"msg": "Invalid role"}), 400

    hashed_pin = bcrypt.hashpw(pin.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")

    new_worker = User(
        name=name,
        mobile_number=mobile,
        pin_hash=hashed_pin,
        area=area,
        address=address,
        id_proof=id_proof,
        role=role,
        manager_id=manager_id,
        is_first_login=False,
    )
    db.session.add(new_worker)
    db.session.flush()  # Get user ID before commit

    # Generate QR Token
    import secrets

    qr_token = secrets.token_hex(16)
    from models import QRCode

    new_qr = QRCode(user_id=new_worker.id, qr_token=qr_token)
    db.session.add(new_qr)

    db.session.commit()

    return (
        jsonify(
            {
                "msg": "Worker created successfully",
                "user_id": new_worker.id,
                "qr_token": qr_token,
            }
        ),
        201,
    )


@auth_bp.route("/register-face", methods=["POST"])
@jwt_required()
def register_face():
    try:
        user_id = request.form.get("user_id")
        device_id = request.form.get("device_id")
        identity = get_jwt_identity()

        # Resolve the requester safely
        requester = get_user_by_identity(identity)

        if not requester:
            return jsonify({"msg": "unauthorized"}), 403

        # Determine target user
        if not user_id or user_id == "0":
            target_user = requester
        else:
            # If specified a specific ID, verify permission
            target_user = User.query.get(int(user_id))
            if not target_user:
                return jsonify({"msg": "target_user_not_found"}), 404
            
            # Non-admins can only register their own face
            req_role = requester.role.value if hasattr(requester.role, 'value') else str(requester.role)
            if req_role != "admin" and req_role != UserRole.ADMIN.value and requester.id != target_user.id:
                return jsonify({"msg": "permission_denied"}), 403

        if "file" not in request.files:
            return jsonify({"msg": "Missing face file"}), 400

        file = request.files["file"]
        image_bytes = file.read()

        from utils.face_utils import generate_face_embedding

        embedding, error = generate_face_embedding(image_bytes)

        if error:
            return jsonify({"msg": f"AI Error: {error}"}), 422

        from models import FaceEmbedding

        # Remove old embedding if exists
        FaceEmbedding.query.filter_by(user_id=target_user.id).delete()

        new_face = FaceEmbedding(
            user_id=target_user.id, 
            embedding_data=embedding, 
            device_id=device_id
        )
        db.session.add(new_face)
        db.session.commit()

        return jsonify({"msg": "face_registered_successfully"}), 201
    except Exception as e:
        return jsonify({"msg": "server_error", "error": str(e)}), 500


@auth_bp.route("/users", methods=["GET"])
@jwt_required()
def list_users():
    identity = get_jwt_identity()
    admin = get_user_by_identity(identity)

    current_role = admin.role.value if hasattr(admin.role, 'value') else str(admin.role)
    if not admin or (current_role != "admin" and current_role != UserRole.ADMIN.value):
        return jsonify({"msg": "Access Denied"}), 403

    users = User.query.all()
    user_list = []
    for u in users:
        # Check if device is bound
        has_device = (
            Device.query.filter_by(user_id=u.id, is_trusted=True).first() is not None
        )
        user_list.append(
            {
                "id": u.id,
                "name": u.name,
                "username": u.username,
                "mobile_number": u.mobile_number,
                "role": u.role.value if hasattr(u.role, 'value') else str(u.role),
                "area": u.area,
                "id_proof": u.id_proof,
                "is_active": u.is_active,
                "is_locked": u.is_locked,
                "has_device_bound": has_device,
            }
        )

    return jsonify(user_list), 200


@auth_bp.route("/reset-device", methods=["POST"])
@jwt_required()
def reset_device():
    identity = get_jwt_identity()
    admin = get_user_by_identity(identity)

    current_role = admin.role.value if hasattr(admin.role, 'value') else str(admin.role)
    if not admin or (current_role != "admin" and current_role != UserRole.ADMIN.value):
        return jsonify({"msg": "Access Denied"}), 403

    data = request.get_json()
    user_id = data.get("user_id")

    if not user_id:
        return jsonify({"msg": "User ID required"}), 400

    # Delete or untrust devices for this user
    Device.query.filter_by(user_id=user_id).delete()
    db.session.commit()

    return jsonify({"msg": "Device binding reset"}), 200


@auth_bp.route("/audit-logs", methods=["GET"])
@jwt_required()
def get_audit_logs():
    identity = get_jwt_identity()
    admin = get_user_by_identity(identity)

    current_role = admin.role.value if hasattr(admin.role, 'value') else str(admin.role)
    if not admin or (current_role != "admin" and current_role != UserRole.ADMIN.value):
        return jsonify({"msg": "Access Denied"}), 403

    logs = LoginLog.query.order_by(LoginLog.login_time.desc()).limit(100).all()
    log_data = []
    for log_entry in logs:
        # Try to join with user to get name
        u = User.query.get(log_entry.user_id) if log_entry.user_id else None
        log_data.append(
            {
                "id": log_entry.id,
                "user_name": u.name if u else "Unknown",
                "mobile": u.mobile_number if u else "N/A",
                "time": log_entry.login_time.isoformat() + "Z",
                "status": log_entry.status,
                "device": log_entry.device_info,
                "ip": log_entry.ip_address,
            }
        )

    return jsonify(log_data), 200


@auth_bp.route("/users/<int:user_id>/biometrics", methods=["DELETE"])
@jwt_required()
def clear_biometrics(user_id):
    identity = get_jwt_identity()
    admin = get_user_by_identity(identity)

    current_role = admin.role.value if hasattr(admin.role, 'value') else str(admin.role)
    if not admin or (current_role != "admin" and current_role != UserRole.ADMIN.value):
        return jsonify({"msg": "Access Denied"}), 403

    from models import FaceEmbedding

    FaceEmbedding.query.filter_by(user_id=user_id).delete()
    db.session.commit()

    return jsonify({"msg": "Biometric data cleared successfully"}), 200


@auth_bp.route("/users/<int:user_id>/reset-pin", methods=["PATCH"])
@jwt_required()
def reset_user_pin(user_id):
    identity = get_jwt_identity()
    admin = get_user_by_identity(identity)

    current_role = admin.role.value if hasattr(admin.role, 'value') else str(admin.role)
    if not admin or (current_role != "admin" and current_role != UserRole.ADMIN.value):
        return jsonify({"msg": "Access Denied"}), 403

    data = request.get_json()
    new_pin = data.get("new_pin")

    if not new_pin:
        return jsonify({"msg": "New PIN required"}), 400

    u = User.query.get_or_404(user_id)
    hashed_pin = bcrypt.hashpw(new_pin.encode("utf-8"), bcrypt.gensalt()).decode(
        "utf-8"
    )
    u.pin_hash = hashed_pin
    u.is_first_login = True  # Force worker to change it maybe? Or just reset it.

    db.session.commit()
    return jsonify({"msg": "PIN reset successfully"}), 200


@auth_bp.route("/users/<int:user_id>", methods=["GET"])
@jwt_required()
def get_user_detail(user_id):
    identity = get_jwt_identity()
    admin = get_user_by_identity(identity)

    current_role = admin.role.value if hasattr(admin.role, 'value') else str(admin.role)
    if not admin or (current_role != "admin" and current_role != UserRole.ADMIN.value):
        return jsonify({"msg": "Access Denied"}), 403

    u = User.query.get_or_404(user_id)
    # Check if device is bound
    has_device = (
        Device.query.filter_by(user_id=u.id, is_trusted=True).first() is not None
    )

    # Get QR code token
    from models import QRCode

    qr_code = QRCode.query.filter_by(user_id=u.id).first()
    qr_token = qr_code.qr_token if qr_code else None

    return (
        jsonify(
            {
                "id": u.id,
                "name": u.name,
                "username": u.username,
                "mobile_number": u.mobile_number,
                "role": u.role.value if hasattr(u.role, 'value') else str(u.role),
                "area": u.area,
                "address": u.address,
                "id_proof": u.id_proof,
                "business_name": u.business_name,
                "is_active": u.is_active,
                "is_locked": u.is_locked,
                "has_device_bound": has_device,
                "qr_token": qr_token,
                "created_at": u.created_at.isoformat(),
            }
        ),
        200,
    )


@auth_bp.route("/users/<int:user_id>", methods=["PUT"])
@jwt_required()
def update_user(user_id):
    # Safe lookup
    identity = get_jwt_identity()
    admin = get_user_by_identity(identity)

    current_role = admin.role.value if hasattr(admin.role, 'value') else str(admin.role)
    if not admin or (current_role != "admin" and current_role != UserRole.ADMIN.value):
        return jsonify({"msg": "Access Denied"}), 403

    u = User.query.get_or_404(user_id)
    data = request.get_json()

    # Update fields if provided
    if "name" in data:
        u.name = data["name"]
    if "mobile_number" in data:
        u.mobile_number = data["mobile_number"]
    if "area" in data:
        u.area = data["area"]
    if "address" in data:
        u.address = data["address"]
    if "id_proof" in data:
        u.id_proof = data["id_proof"]
    if "role" in data:
        try:
            u.role = UserRole(data["role"])
        except ValueError:
            return jsonify({"msg": "Invalid role"}), 400

    if "is_active" in data:
        u.is_active = bool(data["is_active"])
    if "is_locked" in data:
        u.is_locked = bool(data["is_locked"])

    db.session.commit()
    return jsonify({"msg": "User updated successfully"}), 200


@auth_bp.route("/users/<int:user_id>/status", methods=["PATCH"])
@jwt_required()
def toggle_user_status(user_id):
    # Safe lookup
    identity = get_jwt_identity()
    admin = get_user_by_identity(identity)

    current_role = admin.role.value if hasattr(admin.role, 'value') else str(admin.role)
    if not admin or (current_role != "admin" and current_role != UserRole.ADMIN.value):
        return jsonify({"msg": "Access Denied"}), 403

    u = User.query.get_or_404(user_id)
    data = request.get_json()

    if "is_active" in data:
        u.is_active = bool(data["is_active"])
        print(f"DEBUG: Toggled user {user_id} is_active to {u.is_active}")
    if "is_locked" in data:
        u.is_locked = bool(data["is_locked"])
        print(f"DEBUG: Toggled user {user_id} is_locked to {u.is_locked}")

    db.session.commit()
    print(f"DEBUG: Committed status change for user {user_id}")
    return (
        jsonify(
            {
                "msg": "Status updated",
                "is_active": u.is_active,
                "is_locked": u.is_locked,
            }
        ),
        200,
    )


@auth_bp.route("/users/<int:user_id>", methods=["DELETE"])
@jwt_required()
def delete_user(user_id):
    identity = get_jwt_identity()
    admin = get_user_by_identity(identity)

    current_role = admin.role.value if hasattr(admin.role, 'value') else str(admin.role)
    if not admin or (current_role != "admin" and current_role != UserRole.ADMIN.value):
        return jsonify({"msg": "Access Denied"}), 403

    u = User.query.get_or_404(user_id)

    # Protect against self-deletion if needed, but let's assume admin knows what they are doing.
    if u.id == admin.id:
        return jsonify({"msg": "Cannot delete your own account"}), 400

    # Automated cleanup handles dependencies via Relationship Cascades
    db.session.delete(u)
    db.session.commit()

    return jsonify({"msg": "User deleted successfully"}), 200


@auth_bp.route("/users/<int:user_id>/biometrics-info", methods=["GET"])
@jwt_required()
def get_user_biometrics(user_id):
    identity = get_jwt_identity()
    admin = get_user_by_identity(identity)

    current_role = admin.role.value if hasattr(admin.role, 'value') else str(admin.role)
    if not admin or (current_role != "admin" and current_role != UserRole.ADMIN.value):
        return jsonify({"msg": "Access Denied"}), 403

    from models import FaceEmbedding

    face = FaceEmbedding.query.filter_by(user_id=user_id).first()

    if not face:
        return (
            jsonify({"has_biometric": False, "registered_at": None, "device_id": None}),
            200,
        )

    return (
        jsonify(
            {
                "has_biometric": True,
                "registered_at": (
                    face.created_at.isoformat() if face.created_at else None
                ),
                "device_id": face.device_id,
            }
        ),
        200,
    )


@auth_bp.route("/users/<int:user_id>/login-stats", methods=["GET"])
@jwt_required()
def get_user_login_stats(user_id):
    identity = get_jwt_identity()
    admin = get_user_by_identity(identity)

    if not admin or admin.role != UserRole.ADMIN:
        return jsonify({"msg": "Access Denied"}), 403

    # Get login statistics
    total_logins = LoginLog.query.filter_by(user_id=user_id, status="success").count()
    failed_logins = LoginLog.query.filter(
        LoginLog.user_id == user_id,
        LoginLog.status.in_(["failed", "failed_device_mismatch"]),
    ).count()

    # Get last login
    last_login_log = (
        LoginLog.query.filter_by(user_id=user_id, status="success")
        .order_by(LoginLog.login_time.desc())
        .first()
    )
    last_login = last_login_log.login_time.isoformat() if last_login_log else None

    # Get device information
    devices = Device.query.filter_by(user_id=user_id).all()
    device_list = []
    for device in devices:
        device_list.append(
            {
                "device_id": device.device_id,
                "device_name": device.device_name,
                "is_trusted": device.is_trusted,
                "last_active": (
                    device.last_active.isoformat() if device.last_active else None
                ),
            }
        )

    return (
        jsonify(
            {
                "total_logins": total_logins,
                "failed_logins": failed_logins,
                "last_login": last_login,
                "devices": device_list,
            }
        ),
        200,
    )


@auth_bp.route("/my-profile", methods=["GET"])
@jwt_required()
def get_my_profile():
    current_user_id = get_jwt_identity()
    user = get_user_by_identity(current_user_id)

    if not user:
        return jsonify({"msg": "User not found"}), 404

    from models import FaceEmbedding, QRCode

    face = FaceEmbedding.query.filter_by(user_id=user.id).first()
    qr = QRCode.query.filter_by(user_id=user.id).first()

    return (
        jsonify(
            {
                "id": user.id,
                "name": user.name,
                "username": user.username,
                "mobile_number": user.mobile_number,
                "role": user.role.value,
                "area": user.area,
                "address": user.address,
                "id_proof": user.id_proof,
                "is_active": user.is_active,
                "last_login": user.last_login.isoformat() if user.last_login else None,
                "has_biometric": face is not None,
                "qr_token": qr.qr_token if qr else None,
            }
        ),
        200,
    )


@auth_bp.route("/my-team", methods=["GET"])
@jwt_required()
def get_my_team():
    current_user_id = get_jwt_identity()
    user = get_user_by_identity(current_user_id)

    if not user or user.role != UserRole.ADMIN:
        return jsonify({"msg": "Access Denied"}), 403

    # For now, let's say "My Team" for an Admin is all field agents
    # Or we can keep it as manager_id if hierarchy is still desired between admins/agents
    team = User.query.filter_by(role=UserRole.FIELD_AGENT).all()
    team_list = []
    for member in team:
        face = FaceEmbedding.query.filter_by(user_id=member.id).first()
        team_list.append(
            {
                "id": member.id,
                "name": member.name,
                "mobile_number": member.mobile_number,
                "role": member.role.value,
                "is_active": member.is_active,
                "is_locked": member.is_locked,
                "has_biometric": face is not None,
            }
        )
    return jsonify(team_list), 200


@auth_bp.route("/stats/performance", methods=["GET"])
@jwt_required()
def get_performance_stats():
    identity = get_jwt_identity()
    user = get_user_by_identity(identity)

    if not user or user.role != UserRole.ADMIN:
        return jsonify({"msg": "Access Denied"}), 403

    # 1. Role Distribution
    roles_count = (
        db.session.query(User.role, db.func.count(User.id)).group_by(User.role).all()
    )
    role_dist = {r.name.lower(): count for r, count in roles_count}

    # 2. Biometric Adoption Rate
    total_users = User.query.count()
    users_with_bio = FaceEmbedding.query.join(User).count()
    bio_rate = (users_with_bio / total_users * 100) if total_users > 0 else 0

    # 3. Last 7 days login activity
    today = datetime.utcnow().date()
    activity_data = []
    for i in range(7):
        date = today - timedelta(days=i)
        count = LoginLog.query.filter(db.func.date(LoginLog.login_time) == date).count()
        activity_data.append({"date": date.isoformat(), "count": count})

    return (
        jsonify(
            {
                "role_distribution": role_dist,
                "biometric_adoption": round(bio_rate, 2),
                "login_activity": list(reversed(activity_data)),
            }
        ),
        200,
    )
