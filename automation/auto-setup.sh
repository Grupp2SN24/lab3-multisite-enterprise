#!/bin/bash
#===============================================================================
# Lab 3 - Auto Setup Script
# Grupp 2 SN24
#
# This script automatically configures a new VM by:
# 1. Getting its MAC address
# 2. Calling the Flask API to get configuration
# 3. Setting hostname, network, and installing Puppet
#
# Usage: curl -s http://DASHBOARD_IP:5000/auto-setup.sh | bash
#===============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DASHBOARD_URL="${DASHBOARD_URL:-http://192.168.122.40:5000}"
PUPPET_SERVER="192.168.122.40"
PUPPET_FQDN="puppet-master.lab3.local"

#===============================================================================
# Helper Functions
#===============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Get MAC address of ens4 (internal network interface)
get_mac() {
    # Try ens4 first, then eth0
    if ip link show ens4 &>/dev/null; then
        ip link show ens4 | grep ether | awk '{print $2}'
    elif ip link show eth0 &>/dev/null; then
        ip link show eth0 | grep ether | awk '{print $2}'
    else
        # Get first non-loopback interface MAC
        ip link | grep -A1 'state UP' | grep ether | head -1 | awk '{print $2}'
    fi
}

# Update status on dashboard
update_status() {
    local status=$1
    local stage=$2
    curl -s -X POST "${DASHBOARD_URL}/api/status" \
        -H "Content-Type: application/json" \
        -d "{\"mac\": \"${MAC}\", \"status\": \"${status}\", \"stage\": \"${stage}\"}" \
        >/dev/null 2>&1 || true
}

# Detect OS type
detect_os() {
    if [ -f /etc/debian_version ]; then
        echo "debian"
    elif [ -f /etc/redhat-release ]; then
        echo "almalinux"
    else
        echo "unknown"
    fi
}

#===============================================================================
# Main Script
#===============================================================================

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║       Lab 3 Multi-Site Enterprise - Auto Setup                ║"
echo "║                    Grupp 2 SN24                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Ensure ens5 (NAT) is up for internet access
log_info "Ensuring internet connectivity via ens5..."
if ! grep -q "ens5" /etc/network/interfaces 2>/dev/null; then
    cat >> /etc/network/interfaces << 'EOF'

auto ens5
iface ens5 inet dhcp
EOF
fi
ifup ens5 2>/dev/null || dhclient ens5 2>/dev/null || true
sleep 2

# Force IPv4 to avoid IPv6 issues in GNS3
echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4 2>/dev/null || true

# Test internet
if ping -c 1 8.8.8.8 &>/dev/null; then
    log_success "Internet connectivity OK"
else
    log_error "No internet connectivity!"
    exit 1
fi

# Step 2: Get MAC address
log_info "Detecting MAC address..."
MAC=$(get_mac)
if [ -z "$MAC" ]; then
    log_error "Could not detect MAC address!"
    exit 1
fi
log_success "MAC address: ${MAC}"

# Step 3: Call dashboard API to get configuration
log_info "Contacting dashboard for configuration..."
CONFIG=$(curl -s -X POST "${DASHBOARD_URL}/api/discover" \
    -H "Content-Type: application/json" \
    -d "{\"mac\": \"${MAC}\"}")

if echo "$CONFIG" | grep -q "error"; then
    log_error "Dashboard returned error: $CONFIG"
    log_warn "This MAC is not registered. Please add it to the dashboard."
    exit 1
fi

# Parse configuration
HOSTNAME=$(echo "$CONFIG" | grep -o '"hostname":"[^"]*"' | cut -d'"' -f4)
IP=$(echo "$CONFIG" | grep -o '"ip":"[^"]*"' | cut -d'"' -f4)
NETMASK=$(echo "$CONFIG" | grep -o '"netmask":"[^"]*"' | cut -d'"' -f4)
GATEWAY=$(echo "$CONFIG" | grep -o '"gateway":"[^"]*"' | cut -d'"' -f4)
ROLE=$(echo "$CONFIG" | grep -o '"role":"[^"]*"' | cut -d'"' -f4)
OS_TYPE=$(echo "$CONFIG" | grep -o '"os":"[^"]*"' | cut -d'"' -f4)
VRF=$(echo "$CONFIG" | grep -o '"vrf":"[^"]*"' | cut -d'"' -f4)

log_success "Configuration received:"
echo "  Hostname: ${HOSTNAME}"
echo "  IP: ${IP}"
echo "  Gateway: ${GATEWAY}"
echo "  Role: ${ROLE}"
echo "  VRF: ${VRF}"

update_status "configuring" "configuration received"

# Step 4: Set hostname
log_info "Setting hostname to ${HOSTNAME}..."
hostnamectl set-hostname "${HOSTNAME}"
echo "${HOSTNAME}" > /etc/hostname
log_success "Hostname set"

# Step 5: Configure network interface ens4 (internal)
log_info "Configuring network interface ens4..."

# Determine routes based on VRF
case "${VRF}" in
    "SERVICES")
        ROUTES="    up ip route add 10.20.1.0/24 via ${GATEWAY}
    up ip route add 10.20.2.0/24 via ${GATEWAY}
    up ip route add 10.0.0.0/24 via ${GATEWAY}"
        ;;
    "USER-A")
        ROUTES="    up ip route add 10.10.0.0/24 via ${GATEWAY}"
        ;;
    "USER-B")
        ROUTES="    up ip route add 10.10.0.0/24 via ${GATEWAY}"
        ;;
    *)
        ROUTES=""
        ;;
esac

# Write network configuration
cat > /etc/network/interfaces << EOF
auto lo
iface lo inet loopback

auto ens4
iface ens4 inet static
    address ${IP}
    netmask ${NETMASK}
${ROUTES}

auto ens5
iface ens5 inet dhcp
EOF

# Apply network configuration
ifdown ens4 2>/dev/null || true
ifup ens4 2>/dev/null || ip addr add ${IP}/24 dev ens4 && ip link set ens4 up

log_success "Network configured"

update_status "configuring" "network configured"

# Step 6: Install required packages
log_info "Installing required packages..."
DETECTED_OS=$(detect_os)

if [ "$DETECTED_OS" = "debian" ]; then
    apt update
    apt install -y curl wget git
elif [ "$DETECTED_OS" = "almalinux" ]; then
    dnf install -y curl wget git
fi

log_success "Packages installed"

# Step 7: Clone repository and apply configs
log_info "Cloning configuration repository..."
cd /tmp
rm -rf lab3-multisite-enterprise
git clone https://github.com/Grupp2SN24/lab3-multisite-enterprise.git

update_status "configuring" "repository cloned"

# Step 8: Apply role-specific configuration from repo
log_info "Applying role-specific configuration for: ${ROLE}..."

REPO_DIR="/tmp/lab3-multisite-enterprise"

case "${ROLE}" in
    "loadbalancer")
        log_info "Installing HAProxy and Keepalived..."
        apt install -y haproxy keepalived
        cp "${REPO_DIR}/configs/dc/services/haproxy-1/etc/haproxy/haproxy.cfg" /etc/haproxy/haproxy.cfg
        
        # Determine if MASTER or BACKUP based on IP
        if [ "${IP}" = "10.10.0.10" ]; then
            cp "${REPO_DIR}/configs/dc/services/haproxy-1/etc/keepalived/keepalived.conf" /etc/keepalived/keepalived.conf
        else
            cp "${REPO_DIR}/configs/dc/services/haproxy-2/etc/keepalived/keepalived.conf" /etc/keepalived/keepalived.conf
        fi
        
        systemctl enable haproxy keepalived
        systemctl restart haproxy keepalived
        ;;
        
    "webserver")
        log_info "Installing Apache..."
        apt install -y apache2
        echo "<h1>Lab 3 - Server: ${HOSTNAME}</h1><p>IP: ${IP}</p><p>Served via HAProxy</p>" > /var/www/html/index.html
        systemctl enable apache2
        systemctl restart apache2
        ;;
        
    "terminal")
        log_info "Installing XRDP..."
        if [ "$DETECTED_OS" = "almalinux" ]; then
            dnf install -y epel-release
            dnf install -y xrdp xorg-x11-server-Xorg
            firewall-cmd --permanent --add-port=3389/tcp || true
            firewall-cmd --reload || true
        else
            apt install -y xrdp
        fi
        
        # Create users
        for i in $(seq -w 1 20); do
            useradd -m "user${i}" 2>/dev/null || true
            echo "user${i}:password123" | chpasswd
        done
        
        systemctl enable xrdp
        systemctl restart xrdp
        ;;
        
    "nfs")
        log_info "Installing NFS server..."
        apt install -y nfs-kernel-server
        mkdir -p /srv/nfs/home
        chmod 777 /srv/nfs/home
        echo '/srv/nfs/home   10.10.0.0/24(rw,sync,no_subtree_check,no_root_squash)' > /etc/exports
        systemctl enable nfs-kernel-server
        systemctl restart nfs-kernel-server
        exportfs -ra
        ;;
        
    "bastion")
        log_info "Installing SSH with MFA..."
        apt install -y openssh-server libpam-google-authenticator
        systemctl enable ssh
        systemctl restart ssh
        ;;
        
    "thinclient")
        log_info "Installing thin client packages..."
        apt install -y freerdp2-x11 xorg
        ;;
        
    *)
        log_warn "Unknown role: ${ROLE}, skipping role-specific setup"
        ;;
esac

log_success "Role-specific configuration applied"

update_status "configuring" "role configuration applied"

# Step 9: Install and configure Puppet agent
log_info "Installing Puppet agent..."

# Add Puppet server to hosts
sed -i '/puppet-master/d' /etc/hosts
sed -i '/puppet/d' /etc/hosts
echo "${PUPPET_SERVER} ${PUPPET_FQDN} puppet-master puppet" >> /etc/hosts

if [ "$DETECTED_OS" = "debian" ]; then
    cd /tmp
    wget -q https://apt.puppet.com/puppet8-release-bookworm.deb
    dpkg -i puppet8-release-bookworm.deb
    apt update
    apt install -y puppet-agent
elif [ "$DETECTED_OS" = "almalinux" ]; then
    rpm -Uvh https://yum.puppet.com/puppet8-release-el-9.noarch.rpm || true
    dnf install -y puppet-agent
fi

# Configure Puppet
cat > /etc/puppetlabs/puppet/puppet.conf << EOF
[main]
server = ${PUPPET_FQDN}
EOF

log_success "Puppet agent installed"

update_status "configuring" "puppet agent installed"

# Step 10: Register with Puppet master
log_info "Registering with Puppet master..."
/opt/puppetlabs/bin/puppet agent --test --waitforcert 30 || true

# Step 11: Done!
update_status "ready" "deployment complete"

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                    SETUP COMPLETE! ✓                          ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "║  Hostname: ${HOSTNAME}"
echo "║  IP: ${IP}"
echo "║  Role: ${ROLE}"
echo "║  Puppet: Registered (certificate pending)"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo "  1. Sign Puppet certificate on master:"
echo "     sudo /opt/puppetlabs/bin/puppetserver ca sign --all"
echo "  2. Run Puppet agent again:"
echo "     sudo /opt/puppetlabs/bin/puppet agent --test"
echo ""
