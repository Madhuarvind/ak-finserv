from flask import Blueprint, request, jsonify
from extensions import db
from models import User, OTPLog, UserRole, LoginLog, Device
from flask_jwt_extended import create_access_token, create_refresh_token, jwt_required, get_jwt_identity
import bcrypt
import random
import os
from datetime import datetime, timedelta

auth_bp = Blueprint('auth', __name__)

@auth_bp.route('/send-otp', methods=['POST'])
def send_otp():
    data = request.get_json()
    mobile_number = data.get('mobile_number')
    
    # Basic Rate Limiting: Check if OTP was requested for this mobile in the last 60 seconds
    last_otp = OTPLog.query.filter_by(mobile_number=mobile_number).order_by(OTPLog.created_at.desc()).first()
    if last_otp and (datetime.utcnow() - last_otp.created_at).total_seconds() < 60:
        return jsonify({"msg": "Please wait a minute"}), 429

    if not mobile_number:
        return jsonify({"msg": "Mobile number required"}), 400

    user = User.query.filter_by(mobile_number=mobile_number).first()
    if not user:
        return jsonify({"msg": "User not found. Contact Admin."}), 404

    # Generate 4-digit OTP for simplicity
    otp = str(random.randint(1000, 9999))
    expires_at = datetime.utcnow() + timedelta(minutes=5)
    
    otp_entry = OTPLog(mobile_number=mobile_number, otp_code=otp, expires_at=expires_at)
    db.session.add(otp_entry)
    db.session.commit()
    
    # Secure Simulation: Log to file instead of returning in JSON
    os.makedirs('logs', exist_ok=True)
    with open('logs/sms_simulation.log', 'a', encoding='utf-8') as f:
        f.write(f"[{datetime.utcnow()}] OTP for {mobile_number}: {otp}\n")
    
    return jsonify({"msg": "OTP Sent"}), 200

@auth_bp.route('/verify-otp', methods=['POST'])
def verify_otp():
    data = request.get_json()
    mobile_number = data.get('mobile_number')
    otp_code = data.get('otp')
    
    otp_entry = OTPLog.query.filter_by(mobile_number=mobile_number, otp_code=otp_code, is_used=False).first()
    
    if not otp_entry or otp_entry.expires_at < datetime.utcnow():
        return jsonify({"msg": "Invalid or expired OTP"}), 400

    otp_entry.is_used = True
    db.session.commit()
    
    user = User.query.filter_by(mobile_number=mobile_number).first()
    
    # Return a temporary token to allow setting PIN
    access_token = create_access_token(identity=mobile_number)
    return jsonify({
        "msg": "OTP Verified", 
        "access_token": access_token, 
        "is_first_login": user.is_first_login
    }), 200

@auth_bp.route('/set-pin', methods=['POST'])
def set_pin():
    data = request.get_json()
    name = data.get('name', '').strip() # Usually get from JWT identity in real scenario
    pin = data.get('pin')
    
    if not pin or len(pin) != 4:
        return jsonify({"msg": "4-digit PIN required"}), 400

    user = User.query.filter(User.name.ilike(name)).first()
    if not user:
        return jsonify({"msg": "User not found"}), 404

    hashed_pin = bcrypt.hashpw(pin.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
    user.pin_hash = hashed_pin
    user.is_first_login = False
    db.session.commit()
    
    return jsonify({"msg": "PIN Set Successfully"}), 200

@auth_bp.route('/login-pin', methods=['POST'])
def login_pin():
    try:
        data = request.get_json()
        name = data.get('name', '').strip()
        pin = data.get('pin')
        
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
        if bcrypt.checkpw(pin.encode('utf-8'), user.pin_hash.encode('utf-8')):
            user.last_login = datetime.utcnow()
            
            # Simple Audit success login
            log = LoginLog(user_id=user.id, status='success', ip_address=request.remote_addr)
            db.session.add(log)
            db.session.commit()
            
            access_token = create_access_token(identity=name)
            refresh_token = create_refresh_token(identity=name)
            
            print(f"Login success for: {name}")
            return jsonify({
                "msg": "Login success",
                "access_token": access_token,
                "refresh_token": refresh_token,
                "role": user.role.value,
                "is_active": user.is_active,
                "is_locked": user.is_locked
            }), 200
        else:
            print(f"Login failed: Invalid PIN for {name}")
            return jsonify({"msg": "invalid_pin"}), 401
            
    except Exception as e:
        print(f"Login Pin Error: {str(e)}")
        # Return error details temporarily to help debugging
        return jsonify({"msg": "server_error", "error": str(e)}), 500

@auth_bp.route('/verify-face-login', methods=['POST'])
def verify_face_login():
    try:
        data = request.get_json()
        name = data.get('name', '').strip()
        embedding = data.get('embedding')
        device_id = data.get('device_id')
        
        if not name or not embedding:
            return jsonify({"msg": "Name and face data required"}), 400
        
        user = User.query.filter(User.name.ilike(name)).first()
        
        if not user:
            # Log failure: User not found
            log = LoginLog(status='failed', device_info=request.headers.get('User-Agent'), ip_address=request.remote_addr)
            db.session.add(log)
            db.session.commit()
            return jsonify({"msg": "Invalid Login"}), 401
        
        if user.is_locked:
            return jsonify({"msg": "Account locked. Contact Admin."}), 403
        
        # Retrieve stored face embedding
        from models import FaceEmbedding
        stored_face = FaceEmbedding.query.filter_by(user_id=user.id).first()
        
        if not stored_face:
            return jsonify({"msg": "Face not registered. Please use PIN login."}), 401
        
        # Compare embeddings using cosine similarity
        import numpy as np
        stored_embedding = np.array(stored_face.embedding_data)
        submitted_embedding = np.array(embedding)
        
        # Cosine similarity: dot product / (norm1 * norm2)
        similarity = np.dot(stored_embedding, submitted_embedding) / (
            np.linalg.norm(stored_embedding) * np.linalg.norm(submitted_embedding)
        )
        
        # Threshold for face match (0.85 is typical for face recognition)
        if similarity >= 0.85:
            # Face verified -> Check Device Binding
            if user.device_binding_enabled and device_id:
                trusted_device = Device.query.filter_by(user_id=user.id, is_trusted=True).first()
                if trusted_device and trusted_device.device_id != device_id:
                    # Audit failed login (Device Mismatch)
                    log = LoginLog(
                        user_id=user.id, 
                        status='failed_device_mismatch', 
                        device_info=request.headers.get('User-Agent'),
                        ip_address=request.remote_addr
                    )
                    db.session.add(log)
                    db.session.commit()
                    return jsonify({"msg": "Login blocked on new device. Contact Admin."}), 403
                
                # Update or create device record
                device = Device.query.filter_by(user_id=user.id, device_id=device_id).first()
                if not device:
                    device = Device(user_id=user.id, device_id=device_id, device_name=request.headers.get('User-Agent', 'Unknown'))
                    db.session.add(device)
                else:
                    device.last_active = datetime.utcnow()
            
            user.last_login = datetime.utcnow()
            
            # Audit success login
            log = LoginLog(user_id=user.id, status='success_face', device_info=request.headers.get('User-Agent'), ip_address=request.remote_addr)
            db.session.add(log)
            db.session.commit()
            
            access_token = create_access_token(identity=name)
            refresh_token = create_refresh_token(identity=name)
            
            return jsonify({
                "msg": "Face verified successfully",
                "access_token": access_token,
                "refresh_token": refresh_token,
                "role": user.role.value,
                "is_active": user.is_active,
                "is_locked": user.is_locked
            }), 200
        else:
            return jsonify({"msg": "Face not recognized"}), 401
    except Exception as e:
        print(f"Face Verify Error: {str(e)}")
        return jsonify({"msg": "server_error", "error": str(e)}), 500


@auth_bp.route('/admin-login', methods=['POST'])
def admin_login():
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')

    if not username or not password:
        return jsonify({"msg": "Username and password required"}), 400

    user = User.query.filter_by(username=username).first()
    if not user or user.role != UserRole.ADMIN:
        return jsonify({"msg": "Access Denied"}), 403

    if not user.password_hash or not bcrypt.checkpw(password.encode('utf-8'), user.password_hash.encode('utf-8')):
        # Audit failed login
        log = LoginLog(user_id=user.id, status='failed', device_info=request.headers.get('User-Agent'), ip_address=request.remote_addr)
        db.session.add(log)
        db.session.commit()
        return jsonify({"msg": "Invalid Password"}), 401

    # Direct login success - no OTP
    user.last_login = datetime.utcnow()
    
    # Audit success login
    log = LoginLog(user_id=user.id, status='success', device_info=request.headers.get('User-Agent'), ip_address=request.remote_addr)
    db.session.add(log)
    db.session.commit()
    
    access_token = create_access_token(identity=username)
    refresh_token = create_refresh_token(identity=username)
    
    return jsonify({
        "msg": "Login success",
        "access_token": access_token,
        "refresh_token": refresh_token,
        "role": user.role.value,
        "is_active": user.is_active,
        "is_locked": user.is_locked
    }), 200

@auth_bp.route('/admin-verify', methods=['POST'])
def admin_verify():
    data = request.get_json()
    mobile_number = data.get('mobile_number')
    otp_code = data.get('otp')
    
    otp_entry = OTPLog.query.filter_by(mobile_number=mobile_number, otp_code=otp_code, is_used=False).first()
    
    if not otp_entry or otp_entry.expires_at < datetime.utcnow():
        return jsonify({"msg": "Invalid or expired OTP"}), 400

    otp_entry.is_used = True
    user = User.query.filter_by(mobile_number=mobile_number).first()
    user.last_login = datetime.utcnow()
    
    # Audit success login
    log = LoginLog(user_id=user.id, status='success', device_info=request.headers.get('User-Agent'), ip_address=request.remote_addr)
    db.session.add(log)
    db.session.commit()
    
    access_token = create_access_token(identity=mobile_number)
    refresh_token = create_refresh_token(identity=mobile_number)
    
    return jsonify({
        "msg": "Login success",
        "access_token": access_token,
        "refresh_token": refresh_token,
        "role": user.role.value
    }), 200

@auth_bp.route('/refresh-token', methods=['POST'])
@jwt_required(refresh=True)
def refresh_token():
    current_user = get_jwt_identity()
    new_token = create_access_token(identity=current_user)
    return jsonify({"access_token": new_token}), 200


@auth_bp.route('/register-worker', methods=['POST'])
@jwt_required()
def register_worker():
    identity = get_jwt_identity()
    admin = User.query.filter((User.mobile_number == identity) | (User.username == identity)).first()
    
    if not admin or admin.role != UserRole.ADMIN:
        return jsonify({"msg": "Access Denied"}), 403

    data = request.get_json()
    name = data.get('name', '').strip()
    mobile = data.get('mobile_number', '').strip()
    pin = data.get('pin')
    area = data.get('area')
    address = data.get('address')
    id_proof = data.get('id_proof')

    if not mobile or not pin or not name:
        return jsonify({"msg": "Name, mobile and PIN are required"}), 400

    if User.query.filter_by(mobile_number=mobile).first():
        return jsonify({"msg": "Mobile number already exists"}), 400

    if User.query.filter(User.name.ilike(name)).first():
        return jsonify({"msg": "Worker name already exists"}), 400

    hashed_pin = bcrypt.hashpw(pin.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
    
    new_worker = User(
        name=name,
        mobile_number=mobile,
        pin_hash=hashed_pin,
        area=area,
        address=address,
        id_proof=id_proof,
        role=UserRole.FIELD_AGENT,
        is_first_login=False
    )
    db.session.add(new_worker)
    db.session.flush() # Get user ID before commit

    # Generate QR Token
    import secrets
    qr_token = secrets.token_hex(16)
    from models import QRCode
    new_qr = QRCode(user_id=new_worker.id, qr_token=qr_token)
    db.session.add(new_qr)
    
    db.session.commit()

    return jsonify({
        "msg": "Worker created successfully", 
        "user_id": new_worker.id,
        "qr_token": qr_token
    }), 201

@auth_bp.route('/register-face', methods=['POST'])
@jwt_required()
def register_face():
    identity = get_jwt_identity()
    admin = User.query.filter((User.mobile_number == identity) | (User.username == identity)).first()
    
    if not admin or admin.role != UserRole.ADMIN:
        return jsonify({"msg": "Access Denied"}), 403

    data = request.get_json()
    user_id = data.get('user_id')
    embedding = data.get('embedding')
    device_id = data.get('device_id')

    if not user_id or not embedding:
        return jsonify({"msg": "User ID and biometric data required"}), 400

    from models import FaceEmbedding
    new_face = FaceEmbedding(
        user_id=user_id,
        embedding_data=embedding,
        device_id=device_id
    )
    db.session.add(new_face)
    db.session.commit()

    return jsonify({"msg": "Face registered successfully"}), 201

@auth_bp.route('/users', methods=['GET'])
@jwt_required()
def list_users():
    identity = get_jwt_identity()
    admin = User.query.filter((User.mobile_number == identity) | (User.username == identity)).first()
    
    if not admin or admin.role != UserRole.ADMIN:
        return jsonify({"msg": "Access Denied"}), 403

    users = User.query.all()
    user_list = []
    for u in users:
        # Check if device is bound
        has_device = Device.query.filter_by(user_id=u.id, is_trusted=True).first() is not None
        user_list.append({
            "id": u.id,
            "name": u.name,
            "mobile_number": u.mobile_number,
            "role": u.role.value,
            "area": u.area,
            "id_proof": u.id_proof,
            "is_active": u.is_active,
            "is_locked": u.is_locked,
            "has_device_bound": has_device
        })
    
    return jsonify(user_list), 200

@auth_bp.route('/reset-device', methods=['POST'])
@jwt_required()
def reset_device():
    identity = get_jwt_identity()
    admin = User.query.filter((User.mobile_number == identity) | (User.username == identity)).first()
    
    if not admin or admin.role != UserRole.ADMIN:
        return jsonify({"msg": "Access Denied"}), 403

    data = request.get_json()
    user_id = data.get('user_id')
    
    if not user_id:
        return jsonify({"msg": "User ID required"}), 400

    # Delete or untrust devices for this user
    Device.query.filter_by(user_id=user_id).delete()
    db.session.commit()

    return jsonify({"msg": "Device binding reset"}), 200


@auth_bp.route('/audit-logs', methods=['GET'])
@jwt_required()
def get_audit_logs():
    identity = get_jwt_identity()
    admin = User.query.filter((User.mobile_number == identity) | (User.username == identity)).first()
    
    if not admin or admin.role != UserRole.ADMIN:
        return jsonify({"msg": "Access Denied"}), 403

    logs = LoginLog.query.order_by(LoginLog.login_time.desc()).limit(100).all()
    log_data = []
    for l in logs:
        # Try to join with user to get name
        u = User.query.get(l.user_id) if l.user_id else None
        log_data.append({
            "id": l.id,
            "user_name": u.name if u else "Unknown",
            "mobile": u.mobile_number if u else "N/A",
            "time": l.login_time.isoformat(),
            "status": l.status,
            "device": l.device_info,
            "ip": l.ip_address
        })
    
    return jsonify(log_data), 200

