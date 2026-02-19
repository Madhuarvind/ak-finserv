from flask import Flask
from flask_cors import CORS
import os
from extensions import db, jwt


def create_app():
    app = Flask(__name__)
    CORS(
        app,
        resources={
            r"/*": {
                "origins": "*",
                "methods": ["GET", "POST", "OPTIONS", "PUT", "DELETE", "PATCH"],
                "allow_headers": ["Content-Type", "Authorization"],
            }
        },
    )

    # Configuration - Using MySQL/PostgreSQL
    db_url = os.getenv("DATABASE_URL")
    if db_url and db_url.startswith("postgres://"):
        db_url = db_url.replace("postgres://", "postgresql://", 1)
    
    app.config["SQLALCHEMY_DATABASE_URI"] = db_url or "mysql+pymysql://root:MYSQL@localhost:3306/vasool_drive"
    app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False
    app.config["JWT_SECRET_KEY"] = os.getenv(
        "JWT_SECRET_KEY", "vasool-drive-secret-keys"
    )  # Change in production

    db.init_app(app)
    jwt.init_app(app)

    from routes.auth import auth_bp
    from routes.collection import collection_bp
    from routes.line import line_bp
    from routes.customer import customer_bp
    from routes.loan import loan_bp
    from routes.reports import reports_bp
    from routes.settings import settings_bp
    from routes.document import document_bp
    from routes.analytics import analytics_bp
    from routes.security import security_bp
    from routes.settlement import settlement_bp
    from routes.admin_tools import admin_tools_bp
    from routes.ops_analytics import ops_bp
    from routes.worker_tracking import tracking_bp

    # Pre-load face verification model
    try:
        from utils.face_utils import model  # noqa: F401

        print("AI Model loaded successfully")
    except Exception as e:
        print(f"Error loading AI Model: {e}")

    app.register_blueprint(auth_bp, url_prefix="/api/auth")
    app.register_blueprint(customer_bp, url_prefix="/api/customer")
    app.register_blueprint(collection_bp, url_prefix="/api/collection")
    app.register_blueprint(line_bp, url_prefix="/api/line")
    app.register_blueprint(loan_bp, url_prefix="/api/loan")
    app.register_blueprint(reports_bp, url_prefix="/api/reports")
    app.register_blueprint(settings_bp, url_prefix="/api/settings")
    app.register_blueprint(document_bp, url_prefix="/api/document")
    app.register_blueprint(analytics_bp, url_prefix="/api/analytics")
    app.register_blueprint(security_bp, url_prefix="/api/security")
    app.register_blueprint(settlement_bp, url_prefix="/api/settlement")
    app.register_blueprint(admin_tools_bp, url_prefix="/api/admin")
    app.register_blueprint(ops_bp, url_prefix="/api/ops")
    app.register_blueprint(tracking_bp, url_prefix="/api/worker")

    # Create tables if they don't exist
    with app.app_context():
        db.create_all()

    return app


if __name__ == "__main__":
    app = create_app()
    with app.app_context():
        db.create_all()
    host = os.getenv("HOST", "0.0.0.0")  # nosec B104
    port = int(os.getenv("PORT", 5000))
    app.run(debug=True, host=host, port=port)  # nosec B104
