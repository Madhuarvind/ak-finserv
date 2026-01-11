"""
AI-Based Risk Prediction Module
Uses payment patterns and loan history to predict default risk
"""

from datetime import datetime
from models import db, Customer, Loan, Collection, EMISchedule


class RiskPredictor:
    """
    Hybrid ML + Rule-based Risk Scoring
    Scores range from 0-100 (Higher = More Risk)
    """

    @staticmethod
    def calculate_risk_score(customer_id):
        """Calculate comprehensive risk score for a customer"""
        customer = Customer.query.get(customer_id)
        if not customer:
            return {"error": "Customer not found"}

        # Get active loan
        active_loan = Loan.query.filter_by(
            customer_id=customer_id, status="active"
        ).first()

        if not active_loan:
            # No active loan = minimal risk
            return {
                "customer_id": customer_id,
                "risk_score": 10,
                "risk_level": "LOW",
                "factors": {"status": "No active loan"},
            }

        # Feature Extraction
        features = RiskPredictor._extract_features(customer_id, active_loan)

        # Calculate score using weighted factors
        risk_score = RiskPredictor._calculate_weighted_score(features)

        # Classify risk level
        if risk_score < 30:
            risk_level = "LOW"
            color = "green"
        elif risk_score < 60:
            risk_level = "MEDIUM"
            color = "orange"
        else:
            risk_level = "HIGH"
            color = "red"

        return {
            "customer_id": customer_id,
            "customer_name": customer.name,
            "loan_id": active_loan.loan_id,
            "risk_score": round(risk_score, 2),
            "risk_level": risk_level,
            "color": color,
            "factors": features,
            "recommendations": RiskPredictor._get_recommendations(risk_level, features),
        }

    @staticmethod
    def _extract_features(customer_id, loan):
        """Extract ML features from customer & loan data"""
        features = {}

        # 1. Overdue EMI Count
        today = datetime.utcnow()
        overdue_emis = EMISchedule.query.filter(
            EMISchedule.loan_id == loan.id,
            EMISchedule.status != "paid",
            EMISchedule.due_date < today,
        ).count()
        features["overdue_count"] = overdue_emis

        # 2. Payment Consistency (% of EMIs paid on time)
        total_emis = EMISchedule.query.filter_by(loan_id=loan.id).count()
        paid_emis = EMISchedule.query.filter_by(loan_id=loan.id, status="paid").count()
        features["payment_rate"] = (
            (paid_emis / total_emis * 100) if total_emis > 0 else 100
        )

        # 3. Days Since Last Payment
        last_collection = (
            Collection.query.filter_by(loan_id=loan.id, status="approved")
            .order_by(Collection.created_at.desc())
            .first()
        )

        if last_collection:
            days_since_payment = (today - last_collection.created_at).days
            features["days_since_payment"] = days_since_payment
        else:
            features["days_since_payment"] = 999  # No payment yet

        # 4. Partial Payment Frequency (indicator of financial stress)
        partial_payments = Collection.query.filter(
            Collection.loan_id == loan.id, Collection.status == "approved"
        ).all()

        emis = EMISchedule.query.filter_by(loan_id=loan.id).all()
        if emis:
            avg_emi = sum(e.amount for e in emis) / len(emis)
            partial_count = sum(1 for p in partial_payments if p.amount < avg_emi * 0.8)
            features["partial_payment_ratio"] = (
                (partial_count / len(partial_payments) * 100) if partial_payments else 0
            )
        else:
            features["partial_payment_ratio"] = 0

        # 5. Loan Utilization (pending amount vs total payable)
        if loan.pending_amount > 0:
            total_payable = (
                sum(e.amount for e in emis) if emis else loan.principal_amount
            )
            features["utilization_pct"] = (
                (loan.pending_amount / total_payable * 100) if total_payable > 0 else 0
            )
        else:
            features["utilization_pct"] = 0

        # 6. Tenure Progress (how far into the loan)
        if emis:
            paid_emis_count = EMISchedule.query.filter_by(
                loan_id=loan.id, status="paid"
            ).count()
            features["tenure_progress_pct"] = paid_emis_count / len(emis) * 100
        else:
            features["tenure_progress_pct"] = 0

        return features

    @staticmethod
    def _calculate_weighted_score(features):
        """
        Weighted risk scoring algorithm
        Higher score = Higher risk
        """
        score = 0

        # Overdue EMIs (Most Critical - 35 points max)
        overdue = features.get("overdue_count", 0)
        if overdue == 0:
            score += 0
        elif overdue <= 2:
            score += 15
        elif overdue <= 5:
            score += 25
        else:
            score += 35

        # Payment Rate (25 points max - inverse scoring)
        payment_rate = features.get("payment_rate", 100)
        score += (100 - payment_rate) * 0.25

        # Days Since Last Payment (20 points max)
        days = features.get("days_since_payment", 0)
        if days > 60:
            score += 20
        elif days > 30:
            score += 15
        elif days > 15:
            score += 10
        else:
            score += max(0, days * 0.3)

        # Partial Payment Ratio (15 points max)
        partial_ratio = features.get("partial_payment_ratio", 0)
        score += partial_ratio * 0.15

        # High Utilization Late in Tenure (5 points)
        utilization = features.get("utilization_pct", 0)
        progress = features.get("tenure_progress_pct", 0)
        if progress > 50 and utilization > 70:
            score += 5

        return min(score, 100)  # Cap at 100

    @staticmethod
    def _get_recommendations(risk_level, features):
        """Generate actionable recommendations"""
        recs = []

        if risk_level == "HIGH":
            recs.append("⚠️ Schedule immediate field visit")
            recs.append("📞 Contact guarantor")
            if features.get("overdue_count", 0) > 3:
                recs.append("⚖️ Consider legal notice")

        elif risk_level == "MEDIUM":
            recs.append("📞 Call customer for payment reminder")
            recs.append("📅 Offer EMI restructuring if needed")

        else:  # LOW
            recs.append("✅ Customer performing well")
            recs.append("💡 Consider for repeat loan")

        # Specific recommendations
        if features.get("days_since_payment", 0) > 30:
            recs.append("⏰ No payment in 30+ days - Urgent follow-up")

        if features.get("partial_payment_ratio", 0) > 40:
            recs.append("💸 Frequent partial payments - Check financial stability")

        return recs

    @staticmethod
    def get_portfolio_risk_overview():
        """Get risk distribution across all active loans"""
        active_customers = (
            db.session.query(Loan.customer_id)
            .filter(Loan.status == "active")
            .distinct()
            .all()
        )

        risk_summary = {"LOW": [], "MEDIUM": [], "HIGH": []}

        for (customer_id,) in active_customers:
            result = RiskPredictor.calculate_risk_score(customer_id)
            if "error" not in result:
                risk_summary[result["risk_level"]].append(result)

        return {
            "total_customers": len(active_customers),
            "high_risk_count": len(risk_summary["HIGH"]),
            "medium_risk_count": len(risk_summary["MEDIUM"]),
            "low_risk_count": len(risk_summary["LOW"]),
            "high_risk_customers": risk_summary["HIGH"],
            "medium_risk_customers": risk_summary["MEDIUM"][:10],  # Top 10
        }
