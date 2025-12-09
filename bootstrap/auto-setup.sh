#!/bin/bash
#===============================================================================
# Lab 3 - Auto Setup Script 
# Grupp 2 SN24
#
# FIXED: Added DEBIAN_FRONTEND=noninteractive to prevent dpkg prompts
#
# Usage: curl -s http://DASHBOARD_IP:5000/auto-setup.sh | bash
#===============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
DASHBOARD_URL="${DASHBOARD_URL:-http://192.168.122.127:5000}"
PUPPET_SERVER="192.168.122.127"
PUPPET_FQDN="puppet-master.lab3.local"
REPO_URL="https://github.com/Grupp2SN24/lab3-multisite-enterprise.git"

# ============================================================================
# CRITICAL FIX: Prevent ALL interactive prompts from dpkg/apt
# ============================================================================
export DEBIAN_FRONTEND=noninteractive
export APT_LISTCHANGES_FRONTEND=none
APT_OPTS="-o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confnew"

#===============================================================================
# Helper Functions
#===============================================================================

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

get_mac() {
    if ip link show ens4 &>/dev/null; then
        ip link show ens4 | grep ether | awk '{print $2}'
    elif ip link show eth0 &>/dev/null; then
        ip link show eth0 | grep ether | awk '{print $2}'
    fi
}

update_status() {
    local status=$1
    local stage=$2
    curl -s -X POST "${DASHBOARD_URL}/api/status" \
        -H "Content-Type: application/json" \
        -d "{\"mac\": \"${MAC}\", \"status\": \"${status}\", \"stage\": \"${stage}\"}" \
        >/dev/null 2>&1 || true
}

# Non-interactive apt install wrapper
apt_install() {
    apt-get install -y $APT_OPTS "$@"
}

#===============================================================================
# MAC to Host Mapping
#===============================================================================

get_host_config() {
    local mac=$1
    case "$mac" in
        "0c:10:00:00:00:10") echo "haproxy-1|10.10.0.10|loadbalancer|SERVICES" ;;
        "0c:10:00:00:00:11") echo "haproxy-2|10.10.0.11|loadbalancer|SERVICES" ;;
        "0c:10:00:00:00:21") echo "web-1|10.10.0.21|webserver|SERVICES" ;;
        "0c:10:00:00:00:22") echo "web-2|10.10.0.22|webserver|SERVICES" ;;
        "0c:10:00:00:00:23") echo "web-3|10.10.0.23|webserver|SERVICES" ;;
        "0c:10:00:00:00:31") echo "terminal-1|10.10.0.31|terminal|SERVICES" ;;
        "0c:10:00:00:00:32") echo "terminal-2|10.10.0.32|terminal|SERVICES" ;;
        "0c:10:00:00:00:40") echo "nfs-server|10.10.0.40|nfs|SERVICES" ;;
        "0c:10:00:00:00:50") echo "ssh-bastion|10.10.0.50|bastion|SERVICES" ;;
        "0c:20:01:00:00:20") echo "thin-client-a|10.20.1.20|thinclient|USER-A" ;;
        "0c:20:02:00:00:10") echo "windows-client|10.20.2.10|thinclient|USER-B" ;;
        *) echo "" ;;
    esac
}

#===============================================================================
# Main Script
#===============================================================================

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║       Lab 3 Multi-Site Enterprise - Auto Setup v3.0           ║"
echo "║          (Fixed: No interactive prompts)                      ║"
echo "║                    Grupp 2 SN24                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Ensure internet via ens5
log_info "Setting up internet access via ens5 (NAT)..."
if ! grep -q "auto ens5" /etc/network/interfaces 2>/dev/null; then
    cat >> /etc/network/interfaces << 'EOF'

auto ens5
iface ens5 inet dhcp
EOF
fi
ifup ens5 2>/dev/null || dhclient ens5 2>/dev/null || true
sleep 2

# Force IPv4
echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4 2>/dev/null || true

# Test internet
if ! ping -c 1 8.8.8.8 &>/dev/null; then
    log_error "No internet! Check ens5/NAT connection."
    exit 1
fi
log_success "Internet OK"

# Step 2: Get MAC address
log_info "Detecting MAC address..."
MAC=$(get_mac)
if [ -z "$MAC" ]; then
    log_error "Could not detect MAC address!"
    exit 1
fi
log_success "MAC: ${MAC}"

# Step 3: Lookup host configuration
log_info "Looking up host configuration..."
HOST_CONFIG=$(get_host_config "$MAC")

if [ -z "$HOST_CONFIG" ]; then
    log_error "Unknown MAC address: $MAC"
    log_warn "Register this MAC in the dashboard or add to script."
    exit 1
fi

# Parse config
HOSTNAME=$(echo "$HOST_CONFIG" | cut -d'|' -f1)
IP=$(echo "$HOST_CONFIG" | cut -d'|' -f2)
ROLE=$(echo "$HOST_CONFIG" | cut -d'|' -f3)
VRF=$(echo "$HOST_CONFIG" | cut -d'|' -f4)

log_success "Host identified:"
echo "  Hostname: ${HOSTNAME}"
echo "  IP: ${IP}"
echo "  Role: ${ROLE}"
echo "  VRF: ${VRF}"

update_status "configuring" "host identified"

# Step 4: Set hostname
log_info "Setting hostname to ${HOSTNAME}..."
hostnamectl set-hostname "${HOSTNAME}"
echo "${HOSTNAME}" > /etc/hostname
log_success "Hostname set"

# Step 5: Install base packages and clone repo
log_info "Installing packages and cloning repo..."
apt-get update
apt_install curl wget git

cd /tmp
rm -rf lab3-multisite-enterprise
git clone ${REPO_URL}
log_success "Repository cloned"

update_status "configuring" "repository cloned"

# Step 6: Copy network configuration from repo
log_info "Configuring network from repo..."
REPO_DIR="/tmp/lab3-multisite-enterprise"

case "${HOSTNAME}" in
    haproxy-1)
        cp "${REPO_DIR}/configs/dc/services/haproxy-1/etc/network/interfaces" /etc/network/interfaces
        ;;
    haproxy-2)
        cp "${REPO_DIR}/configs/dc/services/haproxy-2/etc/network/interfaces" /etc/network/interfaces
        ;;
    web-1)
        cp "${REPO_DIR}/configs/dc/services/web-1/etc/network/interfaces" /etc/network/interfaces
        ;;
    web-2)
        cp "${REPO_DIR}/configs/dc/services/web-2/etc/network/interfaces" /etc/network/interfaces
        ;;
    web-3)
        cp "${REPO_DIR}/configs/dc/services/web-3/etc/network/interfaces" /etc/network/interfaces
        ;;
    nfs-server)
        cp "${REPO_DIR}/configs/dc/services/nfs-server/etc/network/interfaces" /etc/network/interfaces
        ;;
    ssh-bastion)
        cp "${REPO_DIR}/configs/dc/services/ssh-bastion/etc/network/interfaces" /etc/network/interfaces
        ;;
    thin-client-a)
        cp "${REPO_DIR}/configs/branch-a/thin-client-a/etc/network/interfaces" /etc/network/interfaces
        ;;
    *)
        log_warn "No pre-made network config for ${HOSTNAME}, using default"
        cat > /etc/network/interfaces << EOF
auto lo
iface lo inet loopback

auto ens4
iface ens4 inet static
    address ${IP}
    netmask 255.255.255.0

auto ens5
iface ens5 inet dhcp
EOF
        ;;
esac

log_success "Network configured"

# Step 7: Apply network and restart
log_info "Applying network configuration..."
ip addr flush dev ens4 2>/dev/null || true
ifdown ens4 2>/dev/null || true
ifup ens4 2>/dev/null || true

sleep 2
if ip addr show ens4 | grep -q "${IP}"; then
    log_success "ens4 has IP ${IP}"
else
    log_warn "ens4 IP not visible yet"
fi

update_status "configuring" "network configured"

# Step 8: Install role-specific packages (NON-INTERACTIVE!)
log_info "Installing role-specific packages for: ${ROLE}..."

case "${ROLE}" in
    loadbalancer)
        apt_install haproxy keepalived nfdump
        
        cp "${REPO_DIR}/configs/dc/services/${HOSTNAME}/etc/haproxy/haproxy.cfg" /etc/haproxy/haproxy.cfg
        cp "${REPO_DIR}/configs/dc/services/${HOSTNAME}/etc/keepalived/keepalived.conf" /etc/keepalived/keepalived.conf
        
        mkdir -p /var/cache/nfdump
        nfcapd -D -w /var/cache/nfdump -p 2055 -l /var/cache/nfdump 2>/dev/null || true
        
        systemctl enable haproxy keepalived
        systemctl restart haproxy keepalived
        log_success "HAProxy + Keepalived installed and started"
        ;;
        
    webserver)
        apt_install apache2
        echo "<h1>Lab 3 - Server: ${HOSTNAME}</h1><p>IP: ${IP}</p><p>Served via HAProxy</p>" > /var/www/html/index.html
        systemctl enable apache2
        systemctl restart apache2
        log_success "Apache installed and started"
        ;;
        
    terminal)
        apt_install xrdp nfs-common || true
        
        for i in $(seq -w 1 20); do
            useradd -m "user${i}" 2>/dev/null || true
            echo "user${i}:password123" | chpasswd
        done
        
        systemctl enable xrdp 2>/dev/null || true
        systemctl restart xrdp 2>/dev/null || true
        log_success "XRDP installed"
        ;;
        
    nfs)
        apt_install nfs-kernel-server
        mkdir -p /srv/nfs/home
        chmod 777 /srv/nfs/home
        cp "${REPO_DIR}/configs/dc/services/nfs-server/etc/exports" /etc/exports
        systemctl enable nfs-kernel-server
        systemctl restart nfs-kernel-server
        exportfs -ra
        log_success "NFS server installed"
        ;;
        
    bastion)
        # THIS IS THE FIX - using apt_install with non-interactive options
        apt_install openssh-server libpam-google-authenticator
        systemctl enable ssh
        systemctl restart ssh
        log_success "SSH bastion installed"
        ;;
        
    thinclient)
        apt_install freerdp2-x11 xorg
        log_success "Thin client packages installed"
        ;;
esac

update_status "configuring" "role packages installed"

# Step 9: Install Puppet agent
log_info "Installing Puppet agent..."

sed -i '/puppet-master/d' /etc/hosts
sed -i '/puppet/d' /etc/hosts
echo "${PUPPET_SERVER} ${PUPPET_FQDN} puppet-master puppet" >> /etc/hosts

cd /tmp
wget -q https://apt.puppet.com/puppet8-release-bookworm.deb || true
dpkg -i puppet8-release-bookworm.deb 2>/dev/null || true
apt-get update
apt_install puppet-agent

cat > /etc/puppetlabs/puppet/puppet.conf << EOF
[main]
server = ${PUPPET_FQDN}
EOF

log_success "Puppet agent installed"

update_status "configuring" "puppet installed"

# Step 10: Register with Puppet
log_info "Registering with Puppet master..."
/opt/puppetlabs/bin/puppet agent --test --waitforcert 30 || true

# Done!
update_status "ready" "deployment complete"

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                    SETUP COMPLETE! ✓                          ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "║  Hostname: ${HOSTNAME}"
echo "║  IP: ${IP}"
echo "║  Role: ${ROLE}"
echo "║  Status: READY"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
