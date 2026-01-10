@echo off
echo Starting Vasool Drive Backend in Production Mode...
echo Ensure you have installed requirements: pip install -r requirements.txt

:: Set environment variables (Load from .env if you use python-dotenv loading in app.py or here)
:: For Windows, we can use waitress for production-like serving if gunicorn is not available
:: pip install waitress

python -c "import waitress; from app import app; waitress.serve(app, host='0.0.0.0', port=5000)"

pause
