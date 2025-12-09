#!/bin/bash
#===============================================================================
# Lab 3 - Dashboard Installation Script
# 
# Run this on puppet-master to install and start the automation dashboard.
#
# Usage:
#   sudo bash install-dashboard.sh
#===============================================================================

set -e

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║       Lab 3 - Installing Automation Dashboard                 ║"
echo "╚═══════════════════════════════════════════════════════════════╝"

# Install dependencies
echo "[*] Installing Python and Flask..."
apt update
apt install -y python3 python3-pip python3-venv

# Create dashboard directory
DASHBOARD_DIR="/opt/lab3-dashboard"
mkdir -p ${DASHBOARD_DIR}

# Copy files (assuming running from automation directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp -r ${SCRIPT_DIR}/dashboard/* ${DASHBOARD_DIR}/ 2>/dev/null || true
cp ${SCRIPT_DIR}/auto-setup.sh ${DASHBOARD_DIR}/ 2>/dev/null || true
cp ${SCRIPT_DIR}/bootstrap.sh ${DASHBOARD_DIR}/ 2>/dev/null || true

# If files don't exist, download from GitHub
if [ ! -f "${DASHBOARD_DIR}/app.py" ]; then
    echo "[*] Downloading from GitHub..."
    cd /tmp
    git clone https://github.com/Grupp2SN24/lab3-multisite-enterprise.git || true
    cp -r /tmp/lab3-multisite-enterprise/automation/dashboard/* ${DASHBOARD_DIR}/
    cp /tmp/lab3-multisite-enterprise/automation/auto-setup.sh ${DASHBOARD_DIR}/
    cp /tmp/lab3-multisite-enterprise/automation/bootstrap.sh ${DASHBOARD_DIR}/
fi

# Create virtual environment
echo "[*] Creating Python virtual environment..."
cd ${DASHBOARD_DIR}
python3 -m venv venv
source venv/bin/activate
pip install flask pyyaml

# Create systemd service
echo "[*] Creating systemd service..."
cat > /etc/systemd/system/lab3-dashboard.service << 'EOF'
[Unit]
Description=Lab 3 Automation Dashboard
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/lab3-dashboard
Environment="PATH=/opt/lab3-dashboard/venv/bin"
ExecStart=/opt/lab3-dashboard/venv/bin/python app.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Add routes for serving static files
cat > ${DASHBOARD_DIR}/routes.py << 'EOF'
# Additional routes for serving scripts
from flask import send_file, Response
import os

def add_routes(app):
    @app.route('/auto-setup.sh')
    def serve_auto_setup():
        script_path = os.path.join(os.path.dirname(__file__), 'auto-setup.sh')
        if os.path.exists(script_path):
            with open(script_path, 'r') as f:
                return Response(f.read(), mimetype='text/plain')
        return "Script not found", 404
    
    @app.route('/bootstrap')
    @app.route('/bootstrap.sh')
    def serve_bootstrap():
        script_path = os.path.join(os.path.dirname(__file__), 'bootstrap.sh')
        if os.path.exists(script_path):
            with open(script_path, 'r') as f:
                return Response(f.read(), mimetype='text/plain')
        return "Script not found", 404
EOF

# Update app.py to include routes
if ! grep -q "routes.py" ${DASHBOARD_DIR}/app.py; then
    # Add import at the end of app.py
    cat >> ${DASHBOARD_DIR}/app.py << 'EOF'

# Import additional routes
try:
    from routes import add_routes
    add_routes(app)
except ImportError:
    pass
EOF
fi

# Enable and start service
echo "[*] Starting dashboard service..."
systemctl daemon-reload
systemctl enable lab3-dashboard
systemctl restart lab3-dashboard

# Wait for startup
sleep 3

# Check status
if systemctl is-active --quiet lab3-dashboard; then
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║              DASHBOARD INSTALLED SUCCESSFULLY! ✓              ║"
    echo "╠═══════════════════════════════════════════════════════════════╣"
    echo "║                                                               ║"
    echo "║  Dashboard URL:  http://$(hostname -I | awk '{print $1}'):5000    ║"
    echo "║                                                               ║"
    echo "║  On new VMs, run:                                             ║"
    echo "║  curl -s http://$(hostname -I | awk '{print $1}'):5000/bootstrap | bash  ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
else
    echo "[ERROR] Dashboard failed to start!"
    systemctl status lab3-dashboard
    exit 1
fi
