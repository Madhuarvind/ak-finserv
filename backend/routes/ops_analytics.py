from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from models import db, User, Customer, UserRole, Loan, Line
from utils.optimization_engine import OptimizationEngine
from datetime import datetime

ops_bp = Blueprint("ops", __name__)

@ops_bp.route("/auto-assign-workers", methods=["POST"])
@jwt_required()
def auto_assign_workers():
    identity = get_jwt_identity()
    print(f"DEBUG: Optimization request by identity: {identity}")
    admin = User.query.filter_by(id=identity).first() or \
            User.query.filter_by(username=identity).first() or \
            User.query.filter_by(mobile_number=identity).first()

    if not admin:
        return jsonify({"msg": "Access Denied"}), 403

    current_role = admin.role.value if hasattr(admin.role, 'value') else admin.role
    if current_role != UserRole.ADMIN.value:
        print(f"DEBUG: Access Denied for {identity}. Admin found: {admin.name if admin else 'None'}")
        return jsonify({"msg": "Access Denied"}), 403

    data = request.get_json()
    area_filter = data.get("area")
    max_per_worker = data.get("max_per_worker")
    if max_per_worker is None:
        max_per_worker = 50
    print(f"DEBUG: area_filter: '{area_filter}', max_per_worker: {max_per_worker}")

    # 1. Fetch active field agents
    workers_query = User.query.filter_by(role=UserRole.FIELD_AGENT, is_active=True)
    if area_filter:
        workers_query = workers_query.filter_by(area=area_filter)
    
    workers_list = workers_query.all()
    
    # 2. Fetch unassigned customers
    customers_query = Customer.query.filter_by(status='active')
    if area_filter:
        customers_query = customers_query.filter_by(area=area_filter)
    
    customers_list = customers_query.all()

    print(f"DEBUG: workers_list len: {len(workers_list)}")
    print(f"DEBUG: customers_list len: {len(customers_list)}")
    if not workers_list or not customers_list:
        return jsonify({
            "msg": "no_workers_or_customers_available",
            "debug": {
                "workers_found": len(workers_list),
                "customers_found": len(customers_list),
                "area_filter": area_filter,
                "total_active_customers": Customer.query.filter_by(status='active').count(),
                "total_active_agents": User.query.filter_by(role=UserRole.FIELD_AGENT, is_active=True).count()
            }
        }), 400

    # 3. Prepare data for optimization engine
    # Use area averages as proxy for missing coordinates
    gps_custs = [c for c in customers_list if c.latitude and c.longitude]
    avg_lat = sum(c.latitude for c in gps_custs) / len(gps_custs) if gps_custs else 12.9716
    avg_lng = sum(c.longitude for c in gps_custs) / len(gps_custs) if gps_custs else 77.5946

    optimized_workers = []
    for w in workers_list:
        # Check if worker has assigned_customers relationship
        w_custs = []
        if hasattr(w, 'assigned_customers'):
            w_custs = [c for c in (w.assigned_customers or []) if c.latitude]
        
        lat = sum(c.latitude for c in w_custs) / len(w_custs) if w_custs else avg_lat
        lng = sum(c.longitude for c in w_custs) / len(w_custs) if w_custs else avg_lng
        optimized_workers.append({'id': w.id, 'lat': lat, 'lng': lng})

    optimized_customers = [
        {'id': c.id, 'lat': c.latitude or avg_lat, 'lng': c.longitude or avg_lng} 
        for c in customers_list
    ]

    # 4. Run Optimization
    try:
        assignments = OptimizationEngine.assign_workers_to_customers(
            optimized_workers, 
            optimized_customers, 
            max_per_worker=max_per_worker
        )
    except Exception as e:
        print(f"CRITICAL: Optimization Engine Error: {e}")
        return jsonify({"msg": "optimization_error", "error": str(e)}), 500

    if not assignments:
        return jsonify({"msg": "optimization_failed"}), 500

    # 5. apply Assignments (Dry Run option?)
    dry_run = data.get("dry_run", False)
    if not dry_run:
        for assign in assignments:
            worker_id = assign['worker_id']
            customer_ids = assign['customer_ids']
            Customer.query.filter(Customer.id.in_(customer_ids)).update(
                {Customer.assigned_worker_id: worker_id}, 
                synchronize_session=False
            )
        db.session.commit()

    return jsonify({
        "msg": "optimization_complete",
        "assignments": assignments,
        "dry_run": dry_run
    }), 200

@ops_bp.route("/budget-suggestion", methods=["GET"])
@jwt_required()
def get_budget_suggestion():
    total_fund = float(request.args.get("fund", 1000000))
    
    # Simple logic: group loans by type or area to suggest limits
    # For now, let's group by AREA as 'categories'
    areas = db.session.query(Customer.area).filter(Customer.area.isnot(None)).filter(Customer.area != '').distinct().all()
    categories = []
    
    # Mock data with more variation to ensure IP finds a solution
    for i, (area_name,) in enumerate(areas):
        categories.append({
            'id': area_name,
            'name': area_name,
            'roi': 12.0 + (i * 2), # Vary ROI
            'risk_weight': 0.05 + (i * 0.05) # Vary Risk
        })

    if not categories:
        return jsonify({"msg": "no_areas_found"}), 400

    print(f"DEBUG: Optimizing budget for {len(categories)} categories")
    suggestion = OptimizationEngine.optimize_budget(total_fund, categories)
    
    return jsonify({
        "fund_limit": total_fund,
        "suggestions": suggestion
    }), 200