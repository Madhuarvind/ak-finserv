from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from models import db, User, Loan, LoanDocument, SystemSetting, EMISchedule
from datetime import datetime
import os
from werkzeug.utils import secure_filename

document_bp = Blueprint("document", __name__)

UPLOAD_FOLDER = "uploads/loan_documents"
ALLOWED_EXTENSIONS = {"pdf", "jpg", "jpeg", "png", "doc", "docx"}

# Ensure upload directory exists
os.makedirs(UPLOAD_FOLDER, exist_ok=True)


def allowed_file(filename):
    return "." in filename and filename.rsplit(".", 1)[1].lower() in ALLOWED_EXTENSIONS


@document_bp.route("/loan/<int:loan_id>/upload", methods=["POST"])
@jwt_required()
def upload_loan_document(loan_id):
    """Upload a document for a loan"""
    identity = get_jwt_identity()
    user = User.query.filter(
        (User.username == identity) | (User.id == identity)
    ).first()

    if not user:
        return jsonify({"msg": "User not found"}), 404

    Loan.query.get_or_404(loan_id)

    if "file" not in request.files:
        return jsonify({"msg": "No file provided"}), 400

    file = request.files["file"]
    doc_type = request.form.get(
        "doc_type", "other"
    )  # agreement, signature, id_proof, other

    if file.filename == "":
        return jsonify({"msg": "No file selected"}), 400

    if file and allowed_file(file.filename):
        filename = secure_filename(file.filename)
        timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        unique_filename = f"{loan_id}_{doc_type}_{timestamp}_{filename}"
        filepath = os.path.join(UPLOAD_FOLDER, unique_filename)

        file.save(filepath)

        # Save to database
        document = LoanDocument(
            loan_id=loan_id,
            doc_type=doc_type,
            file_path=filepath,
            uploaded_at=datetime.utcnow(),
        )
        db.session.add(document)
        db.session.commit()

        return (
            jsonify(
                {
                    "msg": "Document uploaded successfully",
                    "document_id": document.id,
                    "filename": unique_filename,
                }
            ),
            201,
        )

    return jsonify({"msg": "Invalid file type"}), 400


@document_bp.route("/loan/<int:loan_id>/documents", methods=["GET"])
@jwt_required()
def get_loan_documents(loan_id):
    """Get all documents for a loan"""
    Loan.query.get_or_404(loan_id)

    documents = LoanDocument.query.filter_by(loan_id=loan_id).all()

    return (
        jsonify(
            [
                {
                    "id": doc.id,
                    "doc_type": doc.doc_type,
                    "filename": os.path.basename(doc.file_path),
                    "uploaded_at": doc.uploaded_at.isoformat(),
                }
                for doc in documents
            ]
        ),
        200,
    )


@document_bp.route("/document/<int:doc_id>", methods=["DELETE"])
@jwt_required()
def delete_document(doc_id):
    """Delete a document"""
    identity = get_jwt_identity()
    user = User.query.filter(
        (User.username == identity) | (User.id == identity)
    ).first()

    if user.role.value != "admin":
        return jsonify({"msg": "Admin access required"}), 403

    document = LoanDocument.query.get_or_404(doc_id)

    # Delete file from disk
    if os.path.exists(document.file_path):
        os.remove(document.file_path)

    db.session.delete(document)
    db.session.commit()

    return jsonify({"msg": "Document deleted"}), 200


@document_bp.route("/loan/<int:loan_id>/penalty-summary", methods=["GET"])
@jwt_required()
def get_penalty_summary(loan_id):
    """Calculate real-time penalty for overdue EMIs"""
    loan = Loan.query.get_or_404(loan_id)

    # Fetch system settings
    grace_period_setting = SystemSetting.query.get("grace_period_days")
    penalty_setting = SystemSetting.query.get("penalty_amount")

    grace_period = int(grace_period_setting.value) if grace_period_setting else 3
    penalty_per_emi = float(penalty_setting.value) if penalty_setting else 50.0

    today = datetime.utcnow()
    overdue_emis = EMISchedule.query.filter(
        EMISchedule.loan_id == loan_id,
        EMISchedule.status != "paid",
        EMISchedule.due_date < today,
    ).all()

    penalty_details = []
    total_penalty = 0

    for emi in overdue_emis:
        days_overdue = (today - emi.due_date).days

        if days_overdue > grace_period:
            # Calculate penalty: base penalty + additional for each week overdue
            weeks_overdue = max(0, (days_overdue - grace_period) // 7)
            emi_penalty = penalty_per_emi + (weeks_overdue * 10)  # ₹10 per week

            penalty_details.append(
                {
                    "emi_no": emi.emi_no,
                    "due_date": emi.due_date.isoformat(),
                    "days_overdue": days_overdue,
                    "penalty": emi_penalty,
                    "emi_amount": emi.amount,
                    "pending_balance": emi.balance,
                }
            )

            total_penalty += emi_penalty

    return (
        jsonify(
            {
                "loan_id": loan.loan_id,
                "total_penalty": total_penalty,
                "grace_period_days": grace_period,
                "base_penalty": penalty_per_emi,
                "overdue_count": len(overdue_emis),
                "penalties": penalty_details,
            }
        ),
        200,
    )
