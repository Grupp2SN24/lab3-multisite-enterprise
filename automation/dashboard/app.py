#!/usr/bin/env python3
"""
Lab 3 Automation Dashboard
Grupp 2 SN24

Provides:
- REST API for auto-discovery of new hosts
- Web dashboard for monitoring deployment status
- Automatic Puppet certificate signing
- Dynamic script serving for all .sh files
"""

from flask import Flask, jsonify, request, render_template_string, Response
import os
import subprocess
import datetime

app = Flask(__name__)

# Host registry - maps MAC addresses to configurations
HOST_REGISTRY = {
    # DC SERVICES VRF (10.10.0.0/24)
    "0c:10:00:00:00:10": {"hostname": "haproxy-1", "ip": "10.10.0.10", "role": "loadbalancer", "os": "debian", "vrf": "SERVICES"},
    "0c:10:00:00:00:11": {"hostname": "haproxy-2", "ip": "10.10.0.11", "role": "loadbalancer", "os": "debian", "vrf": "SERVICES"},
    "0c:10:00:00:00:21": {"hostname": "web-1", "ip": "10.10.0.21", "role": "webserver", "os": "debian", "vrf": "SERVICES"},
    "0c:10:00:00:00:22": {"hostname": "web-2", "ip": "10.10.0.22", "role": "webserver", "os": "debian", "vrf": "SERVICES"},
    "0c:10:00:00:00:23": {"hostname": "web-3", "ip": "10.10.0.23", "role": "webserver", "os": "debian", "vrf": "SERVICES"},
    "0c:10:00:00:00:31": {"hostname": "terminal-1", "ip": "10.10.0.31", "role": "terminal", "os": "almalinux", "vrf": "SERVICES"},
    "0c:10:00:00:00:32": {"hostname": "terminal-2", "ip": "10.10.0.32", "role": "terminal", "os": "almalinux", "vrf": "SERVICES"},
    "0c:10:00:00:00:40": {"hostname": "nfs-server", "ip": "10.10.0.40", "role": "nfs", "os": "debian", "vrf": "SERVICES"},
    "0c:10:00:00:00:50": {"hostname": "ssh-bastion", "ip": "10.10.0.50", "role": "bastion", "os": "debian", "vrf": "SERVICES"},
    
    # DC MGMT VRF (10.0.0.0/24)
    "0c:00:00:00:00:10": {"hostname": "puppet-master", "ip": "10.0.0.10", "role": "puppet", "os": "debian", "vrf": "MGMT"},
    
    # Branch A USER VRF (10.20.1.0/24)
    "0c:20:01:00:00:10": {"hostname": "pxe-server", "ip": "10.20.1.10", "role": "pxe", "os": "debian", "vrf": "USER-A"},
    "0c:20:01:00:00:20": {"hostname": "thin-client-a", "ip": "10.20.1.20", "role": "thinclient", "os": "debian", "vrf": "USER-A"},
    
    # Branch B USER VRF (10.20.2.0/24)
    "0c:20:02:00:00:10": {"hostname": "windows-client", "ip": "10.20.2.10", "role": "thinclient", "os": "windows", "vrf": "USER-B"},
}

# Network configuration per VRF
VRF_CONFIG = {
    "SERVICES": {"gateway": "10.10.0.1", "netmask": "255.255.255.0", "routes": ["10.20.1.0/24", "10.20.2.0/24", "10.0.0.0/24"]},
    "MGMT": {"gateway": "10.0.0.1", "netmask": "255.255.255.0", "routes": []},
    "USER-A": {"gateway": "10.20.1.1", "netmask": "255.255.255.0", "routes": ["10.10.0.0/24"]},
    "USER-B": {"gateway": "10.20.2.1", "netmask": "255.255.255.0", "routes": ["10.10.0.0/24"]},
}

# Runtime state - tracks deployment status
deployment_status = {}

# Activity log
activity_log = []

# Dashboard directory (where scripts are stored)
DASHBOARD_DIR = "/opt/lab3-dashboard"

# HTML Template for Dashboard
DASHBOARD_HTML = """
<!DOCTYPE html>
<html>
<head>
    <title>Lab 3 - Deployment Dashboard</title>
    <meta http-equiv="refresh" content="5">
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 20px; background: #1a1a2e; color: #eee; }
        h1 { color: #00d4ff; border-bottom: 2px solid #00d4ff; padding-bottom: 10px; }
        h2 { color: #00d4ff; margin-top: 30px; }
        .container { max-width: 1400px; margin: 0 auto; }
        .stats { display: flex; gap: 20px; margin-bottom: 30px; }
        .stat-box { background: #16213e; padding: 20px; border-radius: 10px; flex: 1; text-align: center; }
        .stat-box h3 { margin: 0; font-size: 36px; }
        .stat-box p { margin: 5px 0 0 0; color: #888; }
        .stat-box.green h3 { color: #00ff88; }
        .stat-box.yellow h3 { color: #ffcc00; }
        .stat-box.red h3 { color: #ff4444; }
        .stat-box.blue h3 { color: #00d4ff; }
        table { width: 100%; border-collapse: collapse; background: #16213e; border-radius: 10px; overflow: hidden; }
        th { background: #0f3460; padding: 15px; text-align: left; color: #00d4ff; }
        td { padding: 12px 15px; border-bottom: 1px solid #0f3460; }
        tr:hover { background: #1a1a3e; }
        .status { padding: 5px 12px; border-radius: 20px; font-size: 12px; font-weight: bold; }
        .status-ready { background: #00ff88; color: #000; }
        .status-configuring { background: #ffcc00; color: #000; }
        .status-pending { background: #888; color: #fff; }
        .status-error { background: #ff4444; color: #fff; }
        .vrf-tag { padding: 3px 8px; border-radius: 5px; font-size: 11px; }
        .vrf-services { background: #0066cc; }
        .vrf-mgmt { background: #cc6600; }
        .vrf-user { background: #6600cc; }
        .actions { margin-top: 30px; }
        .btn { padding: 12px 24px; margin-right: 10px; border: none; border-radius: 5px; cursor: pointer; font-size: 14px; }
        .btn-primary { background: #00d4ff; color: #000; }
        .btn-danger { background: #ff4444; color: #fff; }
        .btn-success { background: #00ff88; color: #000; }
        .log-box { background: #0a0a15; padding: 15px; border-radius: 10px; margin-top: 20px; max-height: 300px; overflow-y: auto; font-family: monospace; font-size: 12px; }
        .log-entry { margin: 2px 0; }
        .log-time { color: #666; }
        .log-info { color: #00d4ff; }
        .log-success { color: #00ff88; }
        .log-error { color: #ff4444; }
        .scripts-box { background: #16213e; padding: 15px; border-radius: 10px; margin-top: 20px; }
        .scripts-box code { background: #0a0a15; padding: 2px 6px; border-radius: 3px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Lab 3 Multi-Site Enterprise - Deployment Dashboard</h1>
        <p>Grupp 2 SN24 | Auto-refresh: 5s</p>
        
        <div class="stats">
            <div class="stat-box green">
                <h3>{{ stats.ready }}</h3>
                <p>Ready</p>
            </div>
            <div class="stat-box yellow">
                <h3>{{ stats.configuring }}</h3>
                <p>Configuring</p>
            </div>
            <div class="stat-box red">
                <h3>{{ stats.pending }}</h3>
                <p>Pending</p>
            </div>
            <div class="stat-box blue">
                <h3>{{ stats.total }}</h3>
                <p>Total Hosts</p>
            </div>
        </div>
        
        <h2>📊 Host Status</h2>
        <table>
            <tr>
                <th>Hostname</th>
                <th>IP Address</th>
                <th>Role</th>
                <th>VRF</th>
                <th>OS</th>
                <th>Status</th>
                <th>Last Seen</th>
            </tr>
            {% for mac, host in hosts.items() %}
            <tr>
                <td><strong>{{ host.hostname }}</strong></td>
                <td>{{ host.ip }}</td>
                <td>{{ host.role }}</td>
                <td><span class="vrf-tag vrf-{{ host.vrf.lower().split('-')[0] }}">{{ host.vrf }}</span></td>
                <td>{{ host.os }}</td>
                <td>
                    {% if mac in status and status[mac].status == 'ready' %}
                    <span class="status status-ready">✓ READY</span>
                    {% elif mac in status and status[mac].status == 'configuring' %}
                    <span class="status status-configuring">⟳ CONFIGURING</span>
                    {% elif mac in status and status[mac].status == 'error' %}
                    <span class="status status-error">✗ ERROR</span>
                    {% else %}
                    <span class="status status-pending">○ PENDING</span>
                    {% endif %}
                </td>
                <td>
                    {% if mac in status %}
                    {{ status[mac].last_seen }}
                    {% else %}
                    -
                    {% endif %}
                </td>
            </tr>
            {% endfor %}
        </table>
        
        <div class="actions">
            <h2>🔧 Actions</h2>
            <button class="btn btn-success" onclick="signAllCerts()">Sign All Puppet Certs</button>
            <button class="btn btn-primary" onclick="refreshStatus()">Refresh Status</button>
            <button class="btn btn-danger" onclick="resetAll()">Reset All Status</button>
        </div>
        
        <h2>📜 Available Scripts</h2>
        <div class="scripts-box">
            <p><strong>Debian hosts:</strong> <code>curl -s http://{{ request.host }}/auto-setup.sh | bash</code></p>
            <p><strong>AlmaLinux hosts:</strong> <code>curl -s http://{{ request.host }}/auto-setup-alma.sh | bash</code></p>
            <p><strong>Quick bootstrap:</strong> <code>curl -s http://{{ request.host }}/bootstrap | bash</code></p>
        </div>
        
        <h2>📜 Recent Activity</h2>
        <div class="log-box">
            {% for log in logs[-20:] %}
            <div class="log-entry">
                <span class="log-time">[{{ log.time }}]</span>
                <span class="log-{{ log.level }}">{{ log.message }}</span>
            </div>
            {% endfor %}
        </div>
    </div>
    
    <script>
        function signAllCerts() {
            fetch('/api/sign-certs', {method: 'POST'})
                .then(r => r.json())
                .then(d => { alert(d.message); location.reload(); });
        }
        function refreshStatus() { location.reload(); }
        function resetAll() {
            if(confirm('Reset all deployment status?')) {
                fetch('/api/reset', {method: 'POST'})
                    .then(r => r.json())
                    .then(d => { alert(d.message); location.reload(); });
            }
        }
    </script>
</body>
</html>
"""


def log_activity(message, level="info"):
    """Add entry to activity log"""
    activity_log.append({
        "time": datetime.datetime.now().strftime("%H:%M:%S"),
        "message": message,
        "level": level
    })
    # Keep only last 100 entries
    if len(activity_log) > 100:
        activity_log.pop(0)


# ============================================================================
# DYNAMIC SCRIPT SERVING - Serves any .sh file from DASHBOARD_DIR
# ============================================================================

@app.route('/<script_name>')
def serve_script(script_name):
    """
    Dynamically serve any .sh file from the dashboard directory.
    This handles: /bootstrap, /bootstrap.sh, /auto-setup.sh, /auto-setup-alma.sh, etc.
    """
    # Handle /bootstrap -> bootstrap.sh
    if script_name == 'bootstrap':
        script_name = 'bootstrap.sh'
    
    # Only serve .sh files for security
    if not script_name.endswith('.sh'):
        return None  # Let other routes handle non-.sh requests
    
    script_path = os.path.join(DASHBOARD_DIR, script_name)
    
    if os.path.exists(script_path) and os.path.isfile(script_path):
        try:
            with open(script_path, 'r') as f:
                content = f.read()
            log_activity(f"Served script: {script_name}", "info")
            return Response(content, mimetype='text/plain')
        except Exception as e:
            log_activity(f"Error reading {script_name}: {e}", "error")
            return Response(f"Error reading script: {e}", status=500, mimetype='text/plain')
    else:
        log_activity(f"Script not found: {script_name}", "error")
        return Response(f"Script not found: {script_name}", status=404, mimetype='text/plain')


# ============================================================================
# API ENDPOINTS
# ============================================================================

@app.route('/')
def dashboard():
    """Main dashboard view"""
    stats = {
        "ready": sum(1 for s in deployment_status.values() if s.get('status') == 'ready'),
        "configuring": sum(1 for s in deployment_status.values() if s.get('status') == 'configuring'),
        "pending": len(HOST_REGISTRY) - len(deployment_status),
        "total": len(HOST_REGISTRY)
    }
    return render_template_string(
        DASHBOARD_HTML, 
        hosts=HOST_REGISTRY, 
        status=deployment_status, 
        stats=stats,
        logs=activity_log
    )


@app.route('/api/discover', methods=['POST'])
def discover():
    """
    Called by new hosts to get their configuration.
    Expects JSON: {"mac": "xx:xx:xx:xx:xx:xx"}
    Returns: hostname, ip, role, network config
    """
    data = request.get_json()
    mac = data.get('mac', '').lower()
    
    log_activity(f"Discovery request from MAC: {mac}", "info")
    
    if mac not in HOST_REGISTRY:
        log_activity(f"Unknown MAC address: {mac}", "error")
        return jsonify({"error": "Unknown MAC address", "mac": mac}), 404
    
    host = HOST_REGISTRY[mac]
    vrf = VRF_CONFIG[host['vrf']]
    
    # Update status
    deployment_status[mac] = {
        "status": "configuring",
        "last_seen": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "stage": "discovered"
    }
    
    log_activity(f"Host discovered: {host['hostname']} ({host['ip']})", "success")
    
    # Build response with full configuration
    response = {
        "hostname": host['hostname'],
        "ip": host['ip'],
        "netmask": vrf['netmask'],
        "gateway": vrf['gateway'],
        "role": host['role'],
        "os": host['os'],
        "vrf": host['vrf'],
        "routes": vrf['routes'],
        "puppet_server": "puppet-master.lab3.local",
        "puppet_ip": "192.168.122.40",
        "repo_url": "https://github.com/Grupp2SN24/lab3-multisite-enterprise.git"
    }
    
    return jsonify(response)


@app.route('/api/status', methods=['POST'])
def update_status():
    """
    Called by hosts to update their deployment status.
    Expects JSON: {"mac": "xx:xx:xx:xx:xx:xx", "status": "configuring|ready|error", "stage": "..."}
    """
    data = request.get_json()
    mac = data.get('mac', '').lower()
    status = data.get('status', 'unknown')
    stage = data.get('stage', '')
    
    if mac in HOST_REGISTRY:
        deployment_status[mac] = {
            "status": status,
            "last_seen": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "stage": stage
        }
        hostname = HOST_REGISTRY[mac]['hostname']
        log_activity(f"{hostname}: {status} - {stage}", "success" if status == "ready" else "info")
        return jsonify({"ok": True})
    
    return jsonify({"error": "Unknown MAC"}), 404


@app.route('/api/hosts')
def list_hosts():
    """Return all registered hosts and their status"""
    result = []
    for mac, host in HOST_REGISTRY.items():
        entry = host.copy()
        entry['mac'] = mac
        entry['deployment_status'] = deployment_status.get(mac, {"status": "pending"})
        result.append(entry)
    return jsonify(result)


@app.route('/api/scripts')
def list_scripts():
    """Return list of available scripts"""
    scripts = []
    if os.path.exists(DASHBOARD_DIR):
        for f in os.listdir(DASHBOARD_DIR):
            if f.endswith('.sh'):
                scripts.append({
                    "name": f,
                    "url": f"/{f}",
                    "size": os.path.getsize(os.path.join(DASHBOARD_DIR, f))
                })
    return jsonify(scripts)


@app.route('/api/sign-certs', methods=['POST'])
def sign_certs():
    """Sign all pending Puppet certificates"""
    try:
        result = subprocess.run(
            ['/opt/puppetlabs/bin/puppetserver', 'ca', 'sign', '--all'],
            capture_output=True, text=True, timeout=30
        )
        log_activity(f"Signed Puppet certificates", "success")
        return jsonify({"message": "Certificates signed", "output": result.stdout})
    except Exception as e:
        log_activity(f"Failed to sign certs: {e}", "error")
        return jsonify({"error": str(e)}), 500


@app.route('/api/reset', methods=['POST'])
def reset_status():
    """Reset all deployment status"""
    global deployment_status
    deployment_status = {}
    log_activity("Reset all deployment status", "info")
    return jsonify({"message": "Status reset"})


@app.route('/api/bootstrap/<os_type>')
def get_bootstrap_script(os_type):
    """Return bootstrap script for given OS"""
    if os_type == 'debian':
        script = """#!/bin/bash
# Auto-generated bootstrap for Debian
set -e
PUPPET_SERVER="192.168.122.40"
PUPPET_FQDN="puppet-master.lab3.local"

cd /tmp
wget -q https://apt.puppet.com/puppet8-release-bookworm.deb
dpkg -i puppet8-release-bookworm.deb
apt update
apt install -y puppet-agent

cat > /etc/puppetlabs/puppet/puppet.conf << CONF
[main]
server = ${PUPPET_FQDN}
CONF

echo "${PUPPET_SERVER} ${PUPPET_FQDN} puppet-master puppet" >> /etc/hosts
/opt/puppetlabs/bin/puppet agent --test --waitforcert 60 || true
"""
    elif os_type == 'almalinux':
        script = """#!/bin/bash
# Auto-generated bootstrap for AlmaLinux
set -e
PUPPET_SERVER="192.168.122.40"
PUPPET_FQDN="puppet-master.lab3.local"

rpm -Uvh https://yum.puppet.com/puppet8-release-el-9.noarch.rpm || true
dnf install -y puppet-agent

cat > /etc/puppetlabs/puppet/puppet.conf << CONF
[main]
server = ${PUPPET_FQDN}
CONF

echo "${PUPPET_SERVER} ${PUPPET_FQDN} puppet-master puppet" >> /etc/hosts
/opt/puppetlabs/bin/puppet agent --test --waitforcert 60 || true
"""
    else:
        return "Unknown OS", 404
    
    return script, 200, {'Content-Type': 'text/plain'}


if __name__ == '__main__':
    log_activity("Dashboard started", "success")
    app.run(host='0.0.0.0', port=5000, debug=True)
