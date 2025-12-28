from app import create_app
from extensions import db
import sqlalchemy

app = create_app()

def reset_database():
    with app.app_context():
        print("Connecting to database...")
        try:
            # Check connection
            db.session.execute(sqlalchemy.text("SELECT 1"))
            print("Database connection successful.")
            
            print("Dropping all tables...")
            # Drop tables in reverse order of dependencies
            db.drop_all()
            print("All tables dropped.")
            
            print("Creating all tables...")
            db.create_all()
            print("All tables created successfully.")
            
            # Now seed the data
            from seed import seed_data
            print("Seeding data...")
            seed_data()
            print("Data seeded successfully.")
            
        except Exception as e:
            print(f"Error resetting database: {e}")

if __name__ == "__main__":
    reset_database()
