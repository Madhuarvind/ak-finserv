from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from models import db, User, Customer, Loan, Collection, UserRole, EMISchedule
from datetime import datetime, timedelta
from sqlalchemy import func, case

reports_bp = Blueprint('reports', __name__)

def get_admin_user():
    identity = get_jwt_identity()
    user = User.query.filter((User.username == identity) | (User.id == identity) | (User.mobile_number == identity)).first()
    if user and user.role == UserRole.ADMIN:
        return user
    return None

@reports_bp.route('/stats/kpi', methods=['GET'])
@jwt_required()
def get_kpi_stats():
    """Top-level KPIs for Admin Dashboard"""
    if not get_admin_user():
        return jsonify({"msg": "Admin access required"}), 403

    try:
        total_customers = Customer.query.count()
        active_loans = Loan.query.filter_by(status='active').count()
        
        # Disbursed (Total Principal)
        total_disbursed = db.session.query(func.sum(Loan.principal_amount)).scalar() or 0
        
        # Collected (Approved collections only)
        total_collected = db.session.query(func.sum(Collection.amount)).filter_by(status='approved').scalar() or 0
        
        # Outstanding (Principal + Interest pending - Collected)
        # Actually in our model Loan.pending_amount tracks this directly
        outstanding_balance = db.session.query(func.sum(Loan.pending_amount)).filter(Loan.status.in_(['active', 'approved'])).scalar() or 0
        
        # Overdue Amount: Sum of unpaid EMIs where due_date < today
        today = datetime.utcnow()
        overdue_amount = db.session.query(func.sum(EMISchedule.balance)).filter(
            EMISchedule.status != 'paid',
            EMISchedule.due_date < today
        ).scalar() or 0

        return jsonify({
            "total_customers": total_customers,
            "active_loans": active_loans,
            "total_disbursed": float(total_disbursed),
            "total_collected": float(total_collected),
            "outstanding_balance": float(outstanding_balance),
            "overdue_amount": float(overdue_amount)
        }), 200
        
    except Exception as e:
        print(f"KPI Error: {e}")
        return jsonify({"msg": str(e)}), 500

@reports_bp.route('/daily', methods=['GET'])
@jwt_required()
def get_daily_report():
    """Collections for a specific date range"""
    if not get_admin_user():
        return jsonify({"msg": "Admin access required"}), 403
    
    start_date_str = request.args.get('start_date')
    end_date_str = request.args.get('end_date')
    
    try:
        start_date = datetime.fromisoformat(start_date_str) if start_date_str else datetime.utcnow().replace(hour=0, minute=0, second=0)
        end_date = datetime.fromisoformat(end_date_str) if end_date_str else datetime.utcnow().replace(hour=23, minute=59, second=59)
        
        collections = Collection.query.filter(
            Collection.created_at >= start_date,
            Collection.created_at <= end_date
        ).order_by(Collection.created_at.desc()).all()
        
        report = []
        for c in collections:
            report.append({
                "id": c.id,
                "amount": c.amount,
                "mode": c.payment_mode,
                "status": c.status,
                "time": c.created_at.isoformat() + 'Z',
                "agent_name": c.agent.name if c.agent else "Unknown",
                "customer_name": c.loan.customer.name if c.loan and c.loan.customer else "Unknown",
                "loan_id": c.loan.loan_id if c.loan else "N/A"
            })
            
        summary = {
            "total": sum(c.amount for c in collections if c.status == 'approved'),
            "count": len(collections),
            "cash": sum(c.amount for c in collections if c.status == 'approved' and c.payment_mode == 'cash'),
            "upi": sum(c.amount for c in collections if c.status == 'approved' and c.payment_mode == 'upi'),
        }
        
        return jsonify({"report": report, "summary": summary}), 200
        
    except Exception as e:
        return jsonify({"msg": str(e)}), 500

@reports_bp.route('/outstanding', methods=['GET'])
@jwt_required()
def get_outstanding_report():
    """List of all loans with pending balance"""
    if not get_admin_user():
        return jsonify({"msg": "Admin access required"}), 403
        
    try:
        loans = Loan.query.filter(Loan.pending_amount > 0).order_by(Loan.pending_amount.desc()).all()
        
        report = []
        for l in loans:
            customer_name = l.customer.name if l.customer else "Unknown"
            area = l.customer.area if l.customer else "Unknown"
            mobile = l.customer.mobile_number if l.customer else "N/A"
            
            report.append({
                "loan_id": l.loan_id,
                "customer_name": customer_name,
                "mobile": mobile,
                "area": area,
                "principal": l.principal_amount,
                "pending": l.pending_amount,
                "status": l.status,
                "days_active": (datetime.utcnow() - l.created_at).days
            })
            
        return jsonify(report), 200
    except Exception as e:
        return jsonify({"msg": str(e)}), 500

@reports_bp.route('/performance', methods=['GET'])
@jwt_required()
def get_performance_report():
    """Agent Performance Metrics"""
    if not get_admin_user():
        return jsonify({"msg": "Admin access required"}), 403
        
    try:
        agents = User.query.filter_by(role=UserRole.FIELD_AGENT).all()
        report = []
        
        for agent in agents:
            collected = db.session.query(func.sum(Collection.amount)).filter_by(agent_id=agent.id, status='approved').scalar() or 0
            assigned_cust = Customer.query.filter_by(assigned_worker_id=agent.id).count()
            
            report.append({
                "agent_id": agent.id,
                "name": agent.name,
                "collected": float(collected),
                "assigned_customers": assigned_cust,
                # "target": agent.target_amount # If we had this field
            })
            
        return jsonify(report), 200
    except Exception as e:
        return jsonify({"msg": str(e)}), 500

@reports_bp.route('/risk/overdue', methods=['GET'])
@jwt_required()
def get_overdue_report():
    """List of customers with overdue EMIs"""
    if not get_admin_user():
        return jsonify({"msg": "Admin access required"}), 403
    
    try:
        today = datetime.utcnow()
        overdue_emis = db.session.query(
            EMISchedule, Loan, Customer
        ).join(Loan, EMISchedule.loan_id == Loan.id)\
         .join(Customer, Loan.customer_id == Customer.id)\
         .filter(
            EMISchedule.status != 'paid',
            EMISchedule.due_date < today
         ).all()
         
        report_map = {}
        
        for emi, loan, cust in overdue_emis:
            if cust.id not in report_map:
                report_map[cust.id] = {
                    "customer_name": cust.name,
                    "mobile": cust.mobile_number,
                    "area": cust.area,
                    "total_overdue": 0,
                    "missed_emis": 0,
                    "oldest_due_date": emi.due_date.isoformat() + 'Z'
                }
            
            report_map[cust.id]['total_overdue'] += emi.balance
            report_map[cust.id]['missed_emis'] += 1
            if emi.due_date.isoformat() + 'Z' < report_map[cust.id]['oldest_due_date']:
               report_map[cust.id]['oldest_due_date'] = emi.due_date.isoformat() + 'Z'

        return jsonify(list(report_map.values())), 200
        
    except Exception as e:
        return jsonify({"msg": str(e)}), 500
@reports_bp.route('/work-targets', methods=['GET'])
@jwt_required()
def get_work_targets():
    """Customers with EMIs due today or overdue"""
    if not get_admin_user():
        return jsonify({"msg": "Admin access required"}), 403
    
    try:
        today = datetime.utcnow().date()
        # Fetch EMIs due on or before today that are not paid
        targets = db.session.query(
            EMISchedule, Loan, Customer, User
        ).join(Loan, EMISchedule.loan_id == Loan.id)\
         .join(Customer, Loan.customer_id == Customer.id)\
         .outerjoin(User, Loan.assigned_worker_id == User.id)\
         .filter(
            EMISchedule.status != 'paid',
            func.date(EMISchedule.due_date) <= today
         ).order_by(EMISchedule.due_date.asc()).all()
         
        report = []
        for emi, loan, cust, agent in targets:
            report.append({
                "customer_name": cust.name,
                "amount_due": emi.amount,
                "due_date": emi.due_date.isoformat() + 'Z',
                "loan_id": loan.loan_id,
                "area": cust.area,
                "agent_name": agent.name if agent else "Unassigned",
                "is_overdue": emi.due_date.date() < today
            })
            
        return jsonify(report), 200
    except Exception as e:
        return jsonify({"msg": str(e)}), 500
