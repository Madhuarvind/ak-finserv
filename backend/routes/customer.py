from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from models import db, User, Customer, UserRole, CustomerVersion, CustomerNote, Loan
from datetime import datetime
import uuid

customer_bp = Blueprint('customer', __name__)

@customer_bp.route('/sync', methods=['POST'])
@jwt_required()
def sync_customers():
    """
    Receives a list of customers created offline.
    Returns a mapping of {local_id: server_id, ...} and {local_id: error}
    """
    print("=== SYNC CUSTOMER REQUEST RECEIVED ===")
    identity = get_jwt_identity()
    user = User.query.filter((User.mobile_number == identity) | (User.username == identity) | (User.id == identity)).first()
    
    if not user:
        print(f"User not found for identity: {identity}")
        return jsonify({"msg": "User not found"}), 404

    data = request.get_json()
    print(f"Request data: {data}")
    customers_to_sync = data.get('customers', [])
    print(f"Number of customers to sync: {len(customers_to_sync)}")
    
    success_map = {}
    error_map = {}
    
    current_year = datetime.now().year

    for cust_data in customers_to_sync:
        local_id = cust_data.get('local_id')
        try:
            # Check for duplicate by mobile number
            existing = Customer.query.filter_by(mobile_number=cust_data['mobile_number']).first()
            if existing:
                # If already exists, return the existing ID
                success_map[local_id] = {
                    'server_id': existing.id,
                    'customer_id': existing.customer_id,
                    'status': 'duplicate' 
                }
                continue

            # Generate Unique Customer ID
            count = Customer.query.filter(Customer.created_at >= datetime(current_year, 1, 1)).count()
            cust_unique_id = f"CUST-{current_year}-{str(count + 1).zfill(6)}"
            
            # Double check uniqueness loop
            while Customer.query.filter_by(customer_id=cust_unique_id).first():
                count += 1
                cust_unique_id = f"CUST-{current_year}-{str(count + 1).zfill(6)}"

            new_customer = Customer(
                name=cust_data['name'],
                mobile_number=cust_data['mobile_number'],
                address=cust_data.get('address'),
                area=cust_data.get('area'),
                customer_id=cust_unique_id,
                assigned_worker_id=user.id if user.role == UserRole.FIELD_AGENT else None,
                id_proof_number=cust_data.get('id_proof_number'),
                profile_image=cust_data.get('profile_image'),
                status='active',
                latitude=cust_data.get('latitude'),
                longitude=cust_data.get('longitude'),
                created_at=datetime.utcnow() 
            )
            
            db.session.add(new_customer)
            db.session.flush()
            
            success_map[local_id] = {
                'server_id': new_customer.id,
                'customer_id': new_customer.customer_id,
                'status': 'created'
            }
            
        except Exception as e:
            db.session.rollback()
            error_map[local_id] = str(e)
            continue

    db.session.commit()
    
    response_data = {
        "msg": "Sync complete",
        "synced": success_map,
        "errors": error_map
    }
    print(f"=== SYNC RESPONSE: {response_data} ===")
    return jsonify(response_data), 200

@customer_bp.route('/create', methods=['POST'])
@jwt_required()
def create_customer_online():
    """Create customer directly on server (for web/online mode)"""
    print("=== CREATE CUSTOMER ONLINE ===")
    identity = get_jwt_identity()
    user = User.query.filter((User.mobile_number == identity) | (User.username == identity) | (User.id == identity)).first()
    
    if not user:
        return jsonify({"msg": "User not found"}), 404

    data = request.get_json()
    print(f"Customer data: {data}")
    
    try:
        # Check for duplicate
        existing = Customer.query.filter_by(mobile_number=data['mobile_number']).first()
        if existing:
            return jsonify({
                "msg": "Customer with this mobile number already exists",
                "customer_id": existing.customer_id
            }), 400

        # Generate Unique Customer ID
        current_year = datetime.now().year
        count = Customer.query.filter(Customer.created_at >= datetime(current_year, 1, 1)).count()
        cust_unique_id = f"CUST-{current_year}-{str(count + 1).zfill(6)}"
        
        while Customer.query.filter_by(customer_id=cust_unique_id).first():
            count += 1
            cust_unique_id = f"CUST-{current_year}-{str(count + 1).zfill(6)}"

        new_customer = Customer(
            name=data['name'],
            mobile_number=data['mobile_number'],
            address=data.get('address'),
            area=data.get('area'),
            customer_id=cust_unique_id,
            assigned_worker_id=user.id if user.role == UserRole.FIELD_AGENT else None,
            id_proof_number=data.get('id_proof_number'),
            latitude=data.get('latitude'),
            longitude=data.get('longitude'),
            profile_image=data.get('profile_image'),
            status='active',
            created_at=datetime.utcnow()
        )
        
        db.session.add(new_customer)
        db.session.commit()
        
        print(f"Customer created: {new_customer.customer_id}")
        
        return jsonify({
            "msg": "Customer created successfully",
            "customer_id": new_customer.customer_id,
            "server_id": new_customer.id
        }), 201
        
    except Exception as e:
        db.session.rollback()
        print(f"Error creating customer: {e}")
        return jsonify({"msg": str(e)}), 500


@customer_bp.route('/qr/<string:qr_code>', methods=['GET'])
@jwt_required()
def get_customer_by_qr(qr_code):
    """
    Get customer by scanning QR code.
    Interprets QR code as:
    1. customer_id (Exact match)
    2. mobile_number (Exact match)
    """
    print(f"=== QR SCAN REQUEST: {qr_code} ===")
    
    # 1. Try Customer ID
    customer = Customer.query.filter_by(customer_id=qr_code).first()
    
    # 2. Try Mobile Number
    if not customer:
        customer = Customer.query.filter_by(mobile_number=qr_code).first()
        
    if not customer:
        return jsonify({"msg": "Customer not found"}), 404
        
    # Check if customer has active loan for quick collection
    active_loan = Loan.query.filter_by(customer_id=customer.id, status='active').first()
    
    return jsonify({
        "id": customer.id,
        "customer_id": customer.customer_id,
        "name": customer.name,
        "mobile": customer.mobile_number,
        "area": customer.area,
        "profile_image": customer.profile_image,
        "active_loan_id": active_loan.id if active_loan else None,
        "collection_route": '/collection_entry' # Hint to frontend where to go
    }), 200

@customer_bp.route('/list', methods=['GET'])
@jwt_required()
def list_customers():
    identity = get_jwt_identity()
    user = User.query.filter((User.mobile_number == identity) | (User.username == identity) | (User.id == identity)).first()
    
    if not user:
        return jsonify({"msg": "User not found"}), 404
        
    page = request.args.get('page', 1, type=int)
    per_page = request.args.get('per_page', 50, type=int)
    search = request.args.get('search', '')
    
    query = Customer.query
    
    # RLS: Workers only see their own customers
    if user.role == UserRole.FIELD_AGENT:
        filters = [Customer.assigned_worker_id == user.id]
        if user.area:
            filters.append(Customer.area == user.area)
        query = query.filter(db.or_(*filters))
        
    if search:
        search_term = f"%{search}%"
        query = query.filter(
            (Customer.name.ilike(search_term)) | 
            (Customer.mobile_number.ilike(search_term)) |
            (Customer.customer_id.ilike(search_term))
        )
        
    pagination = query.order_by(Customer.created_at.desc()).paginate(page=page, per_page=per_page, error_out=False)
    
    return jsonify({
        "customers": [{
            "id": c.id,
            "customer_id": c.customer_id,
            "name": c.name,
            "mobile": c.mobile_number,
            "area": c.area,
            "address": c.address,
            "status": c.status,
            "assigned_worker_id": c.assigned_worker_id
        } for c in pagination.items],
        "total": pagination.total,
        "pages": pagination.pages,
        "current_page": page
    }), 200

@customer_bp.route('/<int:id>', methods=['GET'])
@jwt_required()
def get_customer_detail(id):
    customer = Customer.query.get_or_404(id)
    customer_loans = Loan.query.filter_by(customer_id=id).all()
    
    loans = [{
        "id": l.id,
        "amount": l.principal_amount,
        "status": l.status,
        "pending_amount": l.pending_amount,
        "loan_id": l.loan_id
    } for l in customer_loans]

    # Prioritize 'active' loan, then 'approved' loan for the dashboard spotlight
    active_loan_obj = next((l for l in customer_loans if l.status == 'active'), None)
    if not active_loan_obj:
        active_loan_obj = next((l for l in customer_loans if l.status == 'approved'), None)
    
    active_loan = {
        "id": active_loan_obj.id,
        "loan_id": active_loan_obj.loan_id,
        "amount": active_loan_obj.principal_amount,
        "interest_rate": active_loan_obj.interest_rate,
        "tenure": active_loan_obj.tenure,
        "tenure_unit": active_loan_obj.tenure_unit,
        "status": active_loan_obj.status
    } if active_loan_obj else None

    return jsonify({
        "id": customer.id,
        "customer_id": customer.customer_id,
        "name": customer.name,
        "mobile": customer.mobile_number,
        "address": customer.address,
        "area": customer.area,
        "assigned_worker_id": customer.assigned_worker_id,
        "status": customer.status,
        "profile_image": customer.profile_image,
        "id_proof_number": customer.id_proof_number,
        "id_proof_type": customer.id_proof_type,
        "alternate_contact": customer.alternate_contact,
        "family_head_name": customer.family_head_name,
        "occupation": customer.occupation,
        "latitude": customer.latitude,
        "longitude": customer.longitude,
        "is_locked": customer.is_locked,
        "version": customer.version,
        "created_at": customer.created_at.isoformat() + 'Z',
        "loans": loans,
        "active_loan": active_loan
    }), 200

@customer_bp.route('/<int:id>', methods=['PUT'])
@jwt_required()
def update_customer(id):
    customer = Customer.query.get_or_404(id)
    data = request.get_json()
    
    # Allow updating basic fields
    if 'name' in data: customer.name = data['name']
    if 'mobile' in data: customer.mobile_number = data['mobile']
    if 'address' in data: customer.address = data['address']
    if 'area' in data: customer.area = data['area']
    if 'status' in data: customer.status = data['status']
    if 'id_proof_number' in data: customer.id_proof_number = data['id_proof_number']
    if 'id_proof_type' in data: customer.id_proof_type = data['id_proof_type']
    if 'alternate_contact' in data: customer.alternate_contact = data['alternate_contact']
    if 'family_head_name' in data: customer.family_head_name = data['family_head_name']
    if 'occupation' in data: customer.occupation = data['occupation']
    if 'assigned_worker_id' in data: customer.assigned_worker_id = data['assigned_worker_id']
    if 'latitude' in data: customer.latitude = data['latitude']
    if 'longitude' in data: customer.longitude = data['longitude']
    if 'profile_image' in data: customer.profile_image = data['profile_image']

    try:
        db.session.commit()
        return jsonify({"msg": "Customer updated successfully"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": str(e)}), 500

# Phase 3A: Production-Grade Customer Management Routes

@customer_bp.route('/<int:id>/status', methods=['PUT'])
@jwt_required()
def update_customer_status(id):
    """Update customer lifecycle status with validation"""
    from utils.customer_lifecycle import validate_status_transition
    
    identity = get_jwt_identity()
    user = User.query.filter((User.mobile_number == identity) | (User.username == identity) | (User.id == identity)).first()
    
    if not user:
        return jsonify({"msg": "User not found"}), 404
    
    customer = Customer.query.get_or_404(id)
    data = request.get_json()
    new_status = data.get('status')
    reason = data.get('reason', '')
    
    if not new_status:
        return jsonify({"msg": "Status required"}), 400
    
    # Validate transition
    is_valid, message = validate_status_transition(customer.status, new_status, user.role.value)
    if not is_valid:
        return jsonify({"msg": message}), 400
    
    # Create version record
    version = CustomerVersion(
        customer_id=customer.id,
        version_number=customer.version + 1,
        changed_by=user.id,
        changes={'status': {'from': customer.status, 'to': new_status}},
        reason=reason
    )
    
    customer.status = new_status
    customer.version += 1
    
    db.session.add(version)
    db.session.commit()
    
    return jsonify({
        "msg": "Status updated successfully",
        "new_status": new_status,
        "version": customer.version
    }), 200

@customer_bp.route('/check-duplicate', methods=['POST'])
@jwt_required()
def check_duplicate():
    """Check for potential duplicate customers"""
    data = request.get_json()
    name = data.get('name', '').strip()
    mobile = data.get('mobile_number', '').strip()
    area = data.get('area', '').strip()
    
    duplicates = []
    
    # Exact mobile match
    if mobile:
        exact_mobile = Customer.query.filter_by(mobile_number=mobile).first()
        if exact_mobile:
            duplicates.append({
                'type': 'exact_mobile',
                'customer_id': exact_mobile.customer_id,
                'name': exact_mobile.name,
                'mobile': exact_mobile.mobile_number,
                'area': exact_mobile.area,
                'confidence': 'high'
            })
    
    # Fuzzy name + area match
    if name and area:
        similar = Customer.query.filter(
            Customer.name.ilike(f"%{name}%"),
            Customer.area == area
        ).limit(5).all()
        
        for sim in similar:
            if sim.mobile_number != mobile:
                duplicates.append({
                    'type': 'similar_name_area',
                    'customer_id': sim.customer_id,
                    'name': sim.name,
                    'mobile': sim.mobile_number,
                    'area': sim.area,
                    'confidence': 'medium'
                })
    
    return jsonify({
        "duplicates_found": len(duplicates) > 0,
        "count": len(duplicates),
        "duplicates": duplicates
    }), 200

@customer_bp.route('/<int:id>/notes', methods=['POST'])
@jwt_required()
def add_customer_note(id):
    """Add a note to customer"""
    
    identity = get_jwt_identity()
    user = User.query.filter((User.mobile_number == identity) | (User.username == identity) | (User.id == identity)).first()
    
    if not user:
        return jsonify({"msg": "User not found"}), 404
    
    customer = Customer.query.get_or_404(id)
    data = request.get_json()
    
    note = CustomerNote(
        customer_id=customer.id,
        worker_id=user.id,
        note_text=data.get('note_text', ''),
        is_important=data.get('is_important', False)
    )
    
    db.session.add(note)
    db.session.commit()
    
    return jsonify({"msg": "Note added successfully"}), 201

@customer_bp.route('/<int:id>/notes', methods=['GET'])
@jwt_required()
def get_customer_notes(id):
    """Get all notes for a customer"""
    
    customer = Customer.query.get_or_404(id)
    notes = CustomerNote.query.filter_by(customer_id=id).order_by(CustomerNote.created_at.desc()).all()
    
    return jsonify({
        "notes": [{
            "id": n.id,
            "note_text": n.note_text,
            "worker_id": n.worker_id,
            "worker_name": n.worker.name if n.worker else "Unknown",
            "created_at": n.created_at.isoformat() + 'Z',
            "is_important": n.is_important
        } for n in notes]
    }), 200

@customer_bp.route('/<int:id>/lock', methods=['POST'])
@jwt_required()
def lock_customer(id):
    """Lock a customer (admin only)"""
    identity = get_jwt_identity()
    user = User.query.filter((User.mobile_number == identity) | (User.username == identity) | (User.id == identity)).first()
    
    if not user or user.role != UserRole.ADMIN:
        return jsonify({"msg": "Admin access required"}), 403
    
    customer = Customer.query.get_or_404(id)
    
    customer.is_locked = True
    customer.locked_by = user.id
    customer.locked_at = datetime.utcnow()
    
    db.session.commit()
    
    return jsonify({"msg": "Customer locked successfully"}), 200

@customer_bp.route('/<int:id>/unlock', methods=['POST'])
@jwt_required()
def unlock_customer(id):
    """Unlock a customer (admin only)"""
    identity = get_jwt_identity()
    user = User.query.filter((User.mobile_number == identity) | (User.username == identity) | (User.id == identity)).first()
    
    if not user or user.role != UserRole.ADMIN:
        return jsonify({"msg": "Admin access required"}), 403
    
    customer = Customer.query.get_or_404(id)
    
    customer.is_locked = False
    customer.locked_by = None
    customer.locked_at = None
    
    db.session.commit()
    
    return jsonify({"msg": "Customer unlocked successfully"}), 200

@customer_bp.route('/<int:id>/timeline', methods=['GET'])
@jwt_required()
def get_customer_timeline(id):
    """Get activity timeline for customer"""
    
    customer = Customer.query.get_or_404(id)
    
    versions = CustomerVersion.query.filter_by(customer_id=id).order_by(CustomerVersion.changed_at.desc()).limit(10).all()
    notes = CustomerNote.query.filter_by(customer_id=id).order_by(CustomerNote.created_at.desc()).limit(10).all()
    
    timeline = []
    
    for v in versions:
        timeline.append({
            'type': 'version',
            'action': 'Updated' if v.version_number > 1 else 'Created',
            'timestamp': v.changed_at.isoformat() + 'Z',
            'user': v.changer.name if v.changer else 'System',
            'changes': v.changes,
            'reason': v.reason
        })
    
    for n in notes:
        timeline.append({
            'type': 'note',
            'action': 'Added Note',
            'timestamp': n.created_at.isoformat() + 'Z',
            'user': n.worker.name if n.worker else 'Unknown',
            'content': n.note_text,
            'is_important': n.is_important
        })
    
    timeline.sort(key=lambda x: x['timestamp'], reverse=True)
    
    return jsonify({"timeline": timeline[:15]}), 200