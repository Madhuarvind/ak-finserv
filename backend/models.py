from extensions import db
from datetime import datetime
import enum

class UserRole(enum.Enum):
    ADMIN = 'admin'
    FIELD_AGENT = 'field_agent'
    MANAGER = 'manager'

class User(db.Model):
    __tablename__ = 'users'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), unique=True, nullable=False) # Full Name
    mobile_number = db.Column(db.String(15), unique=True, nullable=False)
    pin_hash = db.Column(db.String(255), nullable=True) # For Field Agents
    password_hash = db.Column(db.String(255), nullable=True) # For Admin
    role = db.Column(db.Enum(UserRole), default=UserRole.FIELD_AGENT)
    
    # Username Auth for Admin
    username = db.Column(db.String(50), unique=True, nullable=True)
    business_name = db.Column(db.String(100), nullable=True)
    
    # Professional Business Fields
    area = db.Column(db.String(100), nullable=True)
    address = db.Column(db.Text, nullable=True)
    id_proof = db.Column(db.String(50), nullable=True)
    
    is_active = db.Column(db.Boolean, default=True)
    is_locked = db.Column(db.Boolean, default=False)
    device_binding_enabled = db.Column(db.Boolean, default=True)
    is_first_login = db.Column(db.Boolean, default=True)
    last_login = db.Column(db.DateTime, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

class FaceEmbedding(db.Model):
    __tablename__ = 'face_embeddings'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    embedding_data = db.Column(db.JSON, nullable=False) # Stores face features
    device_id = db.Column(db.String(100), nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

class QRCode(db.Model):
    __tablename__ = 'qr_codes'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    qr_token = db.Column(db.String(255), unique=True, nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

class LoginLog(db.Model):
    __tablename__ = 'login_logs'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'))
    login_time = db.Column(db.DateTime, default=datetime.utcnow)
    ip_address = db.Column(db.String(45))
    device_info = db.Column(db.String(255))
    status = db.Column(db.String(20)) # 'success', 'failed'

class Device(db.Model):
    __tablename__ = 'devices'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'))
    device_id = db.Column(db.String(100), unique=True)
    device_name = db.Column(db.String(100))
    is_trusted = db.Column(db.Boolean, default=True)
    last_active = db.Column(db.DateTime, default=datetime.utcnow)

class OTPLog(db.Model):
    __tablename__ = 'otp_logs'
    id = db.Column(db.Integer, primary_key=True)
    mobile_number = db.Column(db.String(15), nullable=False)
    otp_code = db.Column(db.String(6), nullable=False)
    expires_at = db.Column(db.DateTime, nullable=False)
    is_used = db.Column(db.Boolean, default=False)
