from app import create_app
from extensions import db
from models import User, UserRole
import bcrypt

app = create_app()

def seed_data():
    with app.app_context():
        # Create DB tables
        db.create_all()
        
        # Create test admin
        admin_mobile = "9876543210"
        admin_pin = "1111"
        admin_password = "Admin@123"
        
        hashed_pin = bcrypt.hashpw(admin_pin.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
        hashed_password = bcrypt.hashpw(admin_password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

        admin = User.query.filter_by(mobile_number=admin_mobile).first()
        if not admin:
            admin = User(
                mobile_number=admin_mobile,
                username="admin",
                business_name="Vasool Drive",
                pin_hash=hashed_pin,
                password_hash=hashed_password,
                role=UserRole.ADMIN,
                is_first_login=False
            )
            db.session.add(admin)
            print(f"Created admin user: {admin_mobile} (User: admin, Business: Vasool Drive)")
        else:
            admin.username = "admin"
            admin.business_name = "Vasool Drive"
            admin.password_hash = hashed_password
            admin.pin_hash = hashed_pin
            print(f"Updated admin user {admin_mobile} with username and business name.")

        # Create Madhu admin
        madhu_mobile = "7904235240"
        madhu_pin = "2222"
        madhu_password = "Admin@123"
        
        hashed_pin_m = bcrypt.hashpw(madhu_pin.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
        hashed_password_m = bcrypt.hashpw(madhu_password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

        madhu = User.query.filter_by(mobile_number=madhu_mobile).first()
        if not madhu:
            madhu = User(
                mobile_number=madhu_mobile,
                username="madhu",
                business_name="Vasool Drive",
                pin_hash=hashed_pin_m,
                password_hash=hashed_password_m,
                role=UserRole.ADMIN,
                is_first_login=False
            )
            db.session.add(madhu)
            print(f"Created admin user: {madhu_mobile} (Madhu)")
        else:
            madhu.username = "madhu"
            madhu.business_name = "Vasool Drive"
            madhu.password_hash = hashed_password_m
            madhu.pin_hash = hashed_pin_m
            print(f"Updated admin user {madhu_mobile} (Madhu)")

        db.session.commit()

if __name__ == "__main__":
    seed_data()
