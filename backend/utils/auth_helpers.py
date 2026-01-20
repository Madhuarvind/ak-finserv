from models import User, UserRole

def get_user_by_identity(identity):
    """
    Safely retrieves a user by identity (Username, Mobile, or ID).
    Handles type checks to avoid PostgreSQL integer casting errors.
    """
    if not identity:
        return None
        
    query = User.query
    
    # safe check for ID (integer)
    is_id = False
    if isinstance(identity, int):
        is_id = True
    elif isinstance(identity, str) and identity.isdigit():
        is_id = True
        identity = int(identity)

    if is_id:
        user = query.filter(
            (User.mobile_number == str(identity))
            | (User.username == str(identity))
            | (User.name.ilike(str(identity)))
            | (User.id == identity)
        ).first()
    else:
        # Identity is a string (Name/Username/Mobile), NOT an ID
        user = query.filter(
            (User.mobile_number == identity)
            | (User.username == identity)
            | (User.name.ilike(identity))
        ).first()
        

def get_admin_user():
    from flask_jwt_extended import get_jwt_identity
    identity = get_jwt_identity()
    user = get_user_by_identity(identity)
    
    if user:
        # Normalize role check (handles Enum vs String)
        role_val = user.role.value if hasattr(user.role, 'value') else str(user.role)
        if str(role_val).lower() == "admin":
            return user
    return None
