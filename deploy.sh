#!/bin/bash
# Arun Finance - Production Deployment Script
# Run this script on your Ubuntu 22.04 server

set -e  # Exit on error

echo "🚀 Starting Arun Finance Deployment..."

# Variables (UPDATE THESE)
APP_DIR="/var/www/arun_finance"
DOMAIN="api.yourdomain.com"
DB_HOST="localhost"
DB_NAME="arun_finance_db"
DB_USER="arun_user"
DB_PASS="CHANGE_THIS_PASSWORD"

# 1. Update system
echo "📦 Updating system packages..."
sudo apt update && sudo apt upgrade -y

# 2. Install dependencies
echo "📦 Installing dependencies..."
sudo apt install -y python3-pip python3-venv nginx mysql-server certbot python3-certbot-nginx git

# 3. Clone/Update repository
if [ ! -d "$APP_DIR" ]; then
    echo "📥 Cloning repository..."
    sudo mkdir -p $APP_DIR
    sudo chown $USER:$USER $APP_DIR
    git clone https://github.com/YOUR_USERNAME/Arun_Finance.git $APP_DIR
else
    echo "🔄 Updating repository..."
    cd $APP_DIR
    git pull origin main
fi

cd $APP_DIR/backend

# 4. Set up Python virtual environment
echo "🐍 Setting up Python environment..."
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# 5. Configure environment variables
echo "⚙️  Creating .env file..."
cat > .env <<EOF
SQLALCHEMY_DATABASE_URI=mysql+pymysql://$DB_USER:$DB_PASS@$DB_HOST/$DB_NAME
JWT_SECRET_KEY=$(openssl rand -hex 32)
HOST=0.0.0.0
PORT=8000
FLASK_DEBUG=False
EOF

# 6. Set up database
echo "💾 Setting up database..."
sudo mysql -e "CREATE DATABASE IF NOT EXISTS $DB_NAME;"
sudo mysql -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
sudo mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

# 7. Initialize database tables
echo "🗄️  Initializing database..."
python -c "from app import create_app; from extensions import db; app = create_app(); app.app_context().push(); db.create_all()"

# 8. Configure Gunicorn systemd service
echo "⚙️  Configuring Gunicorn service..."
sudo tee /etc/systemd/system/gunicorn.service > /dev/null <<EOF
[Unit]
Description=Gunicorn instance for Arun Finance
After=network.target

[Service]
User=$USER
Group=www-data
WorkingDirectory=$APP_DIR/backend
Environment="PATH=$APP_DIR/backend/venv/bin"
ExecStart=$APP_DIR/backend/venv/bin/gunicorn -c gunicorn_config.py app:app

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable gunicorn
sudo systemctl start gunicorn

# 9. Configure Nginx
echo "🌐 Configuring Nginx..."
sudo cp nginx_app.conf /etc/nginx/sites-available/arun_finance
sudo sed -i "s/api.yourdomain.com/$DOMAIN/g" /etc/nginx/sites-available/arun_finance
sudo ln -sf /etc/nginx/sites-available/arun_finance /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx

# 10. Configure SSL with Certbot
echo "🔒 Setting up SSL..."
sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN

# 11. Configure firewall
echo "🛡️  Configuring firewall..."
sudo ufw allow 'Nginx Full'
sudo ufw allow OpenSSH
sudo ufw --force enable

echo "✅ Deployment complete!"
echo "📱 Your API is now live at https://$DOMAIN"
echo "🔄 To update: git pull && sudo systemctl restart gunicorn"
