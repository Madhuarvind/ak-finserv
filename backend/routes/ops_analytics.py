from flask import Blueprint, jsonify, request
from flask_jwt_extended import jwt_required, get_jwt_identity
from models import db, User, Customer, UserRole
from utils.optimization_engine import OptimizationEngine

ops_bp = Blueprint("ops", __name__)

@ops_bp.route("/auto-assign-workers", methods=["POST"])
@jwt_required()
def auto_assign_workers():
    # 1. Fetch available workers
    # Handle role stored as String or Enum
    workers = User.query.filter(User.role == UserRole.FIELD_AGENT).all()
    
    # 2. Fetch customers (filter by area if needed)
    data = request.get_json() or {}
    area_filter = data.get("area")
    
    query = Customer.query
    if area_filter and area_filter.lower() != "all":
        query = query.filter(Customer.area.ilike(f"%{area_filter}%"))
    
    customers = query.all()

    # 3. Format for Engine
    # Ensure lat/lng are floats (handle nulls)
    worker_list = []
    for w in workers:
        if w.latitude and w.longitude:
             worker_list.append({"id": w.id, "lat": float(w.latitude), "lng": float(w.longitude)})
    
    customer_list = []
    for c in customers:
        if c.latitude and c.longitude:
            customer_list.append({"id": c.id, "lat": float(c.latitude), "lng": float(c.longitude)})

    if not worker_list:
        return jsonify({"msg": "no_workers_with_location", "assignments": [], "debug": {"workers_found": 0}}), 200
    
    if not customer_list:
        return jsonify({"msg": "no_customers_with_location", "assignments": [], "debug": {"customers_found": 0}}), 200

    # 4. Run Optimization
    # max_per_worker default 50
    max_pw = int(data.get("max_per_worker", 50))
    assignments = OptimizationEngine.assign_workers_to_customers(worker_list, customer_list, max_per_worker=max_pw)

    # 5. Apply? (Only if dry_run=False)
    is_dry_run = data.get("dry_run", False)
    
    if not is_dry_run:
        # Applying assignments
        try:
            for item in assignments:
                wid = item["worker_id"]
                cids = item["customer_ids"]
                if cids:
                    # Update DB
                    Customer.query.filter(Customer.id.in_(cids)).update(
                        {Customer.assigned_worker_id: wid}, synchronize_session=False
                    )
            db.session.commit()
            return jsonify({"msg": "optimization_complete", "assignments": assignments}), 200
        except Exception as e:
            db.session.rollback()
            return jsonify({"msg": "error_applying", "error": str(e)}), 500

    return jsonify({"msg": "preview", "assignments": assignments, 
                    "debug": {"workers_found": len(worker_list), "customers_found": len(customer_list), "area_filter": area_filter}}), 200

@ops_bp.route("/budget-suggestion", methods=["GET"])
@jwt_required()
def budget_suggestion():
    try:
        fund = float(request.args.get("fund", 1000000))
        
        # Mock categories for now (or fetch from DB if we had LoanProducts table)
        # This provides a real demonstration of the Linear Programming solver
        categories = [
            {"id": 1, "name": "Gold Loan", "roi": 12.0, "risk_weight": 0.05},
            {"id": 2, "name": "Personal Loan", "roi": 18.0, "risk_weight": 0.20},
            {"id": 3, "name": "Business Loan", "roi": 15.0, "risk_weight": 0.15},
            {"id": 4, "name": "Micro Finance", "roi": 24.0, "risk_weight": 0.30}
        ]

        result = OptimizationEngine.optimize_budget(fund, categories)
        
        # Map back IDs to Names for UI
        suggestions = {}
        if result:
            for cat in categories:
                amt = result.get(str(cat["id"]), 0)
                if amt > 0:
                    suggestions[cat["name"]] = amt
        
        return jsonify({"suggestions": suggestions}), 200
    except Exception as e:
        return jsonify({"msg": "error", "error": str(e)}), 500
