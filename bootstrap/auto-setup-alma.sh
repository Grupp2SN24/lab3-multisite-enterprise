#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
#  Lab 3 - AlmaLinux Terminal Server Auto Setup v2.1
#  For: terminal-1 (10.10.0.31), terminal-2 (10.10.0.32)
#  Uses MAC address discovery via dashboard API (same as Debian script)
#═══════════════════════════════════════════════════════════════════════════════

set -e

DASHBOARD_URL="http://192.168.122.127:5000"
PUPPET_SERVER="192.168.122.127"
NFS_SERVER="10.10.0.40"

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║     Lab 3 - AlmaLinux Terminal Server Setup v2.1              ║"
echo "╚═══════════════════════════════════════════════════════════════╝"

#───────────────────────────────────────────────────────────────────────────────
# Detect interfaces
#───────────────────────────────────────────────────────────────────────────────
IFACE_SERVICES=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | head -1)
IFACE_NAT=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | tail -1)
MAC_ADDRESS=$(cat /sys/class/net/$IFACE_SERVICES/address)

echo "[INFO] Services interface: $IFACE_SERVICES (MAC: $MAC_ADDRESS)"
echo "[INFO] NAT interface: $IFACE_NAT"

#───────────────────────────────────────────────────────────────────────────────
# Ensure NAT interface is up for internet access during setup
#───────────────────────────────────────────────────────────────────────────────
echo "[INFO] Ensuring NAT interface has connectivity..."
nmcli con delete "nat" 2>/dev/null || true
nmcli con delete "Wired connection 2" 2>/dev/null || true
nmcli con add type ethernet con-name "nat" ifname "$IFACE_NAT" ipv4.method auto autoconnect yes
nmcli con up "nat"
sleep 2

#───────────────────────────────────────────────────────────────────────────────
# Discover configuration from dashboard API using MAC address
#───────────────────────────────────────────────────────────────────────────────
echo "[INFO] Discovering configuration from dashboard..."

CONFIG=$(curl -s -X POST "$DASHBOARD_URL/api/discover" \
    -H "Content-Type: application/json" \
    -d "{\"mac\": \"$MAC_ADDRESS\"}")

if echo "$CONFIG" | grep -q "error"; then
    echo "[ERROR] Failed to get configuration from dashboard!"
    echo "[ERROR] MAC $MAC_ADDRESS not found in registry"
    echo "$CONFIG"
    exit 1
fi

# Parse JSON response
HOSTNAME=$(echo "$CONFIG" | grep -o '"hostname"[^,]*' | cut -d'"' -f4)
IP=$(echo "$CONFIG" | grep -o '"ip"[^,]*' | cut -d'"' -f4)
NETMASK=$(echo "$CONFIG" | grep -o '"netmask"[^,]*' | cut -d'"' -f4)
GATEWAY=$(echo "$CONFIG" | grep -o '"gateway"[^,]*' | cut -d'"' -f4)

echo "[OK] Discovered: $HOSTNAME ($IP)"

#───────────────────────────────────────────────────────────────────────────────
# Set hostname
#───────────────────────────────────────────────────────────────────────────────
echo "[INFO] Setting hostname to $HOSTNAME..."
hostnamectl set-hostname $HOSTNAME
echo "[OK] Hostname set"

#───────────────────────────────────────────────────────────────────────────────
# Configure services network
#───────────────────────────────────────────────────────────────────────────────
echo "[INFO] Configuring services network..."

nmcli con delete "services" 2>/dev/null || true
nmcli con delete "Wired connection 1" 2>/dev/null || true

# Convert netmask to CIDR if needed
if [[ "$NETMASK" == "255.255.255.0" ]]; then
    CIDR="24"
else
    CIDR="24"
fi

nmcli con add type ethernet con-name "services" ifname "$IFACE_SERVICES" \
    ipv4.addresses "$IP/$CIDR" \
    ipv4.gateway "$GATEWAY" \
    ipv4.dns "8.8.8.8,8.8.4.4" \
    ipv4.method manual \
    autoconnect yes

# Add routes to branch networks
nmcli con mod "services" +ipv4.routes "10.20.1.0/24 $GATEWAY"
nmcli con mod "services" +ipv4.routes "10.20.2.0/24 $GATEWAY"
nmcli con mod "services" +ipv4.routes "10.0.0.0/24 $GATEWAY"

nmcli con up "services"
echo "[OK] Network configured"

#───────────────────────────────────────────────────────────────────────────────
# Update status: configuring
#───────────────────────────────────────────────────────────────────────────────
curl -s -X POST "$DASHBOARD_URL/api/status" \
    -H "Content-Type: application/json" \
    -d "{\"mac\": \"$MAC_ADDRESS\", \"status\": \"configuring\", \"stage\": \"installing packages\"}" || true

#───────────────────────────────────────────────────────────────────────────────
# Install EPEL and XRDP
#───────────────────────────────────────────────────────────────────────────────
echo "[INFO] Installing EPEL repository..."
dnf install -y epel-release

echo "[INFO] Installing XRDP and desktop environment..."
dnf install -y xrdp xorg-x11-server-Xorg xorg-x11-xinit
dnf groupinstall -y "Server with GUI" --skip-broken 2>/dev/null || dnf install -y xfce4-session xfwm4 2>/dev/null || true

echo "[INFO] Enabling XRDP service..."
systemctl enable xrdp
systemctl start xrdp
echo "[OK] XRDP installed and started"

#───────────────────────────────────────────────────────────────────────────────
# Configure firewall
#───────────────────────────────────────────────────────────────────────────────
echo "[INFO] Configuring firewall..."
if systemctl is-active --quiet firewalld; then
    firewall-cmd --permanent --add-port=3389/tcp
    firewall-cmd --reload
    echo "[OK] Firewall configured"
else
    echo "[SKIP] Firewalld not running"
fi

#───────────────────────────────────────────────────────────────────────────────
# Create lab users (20 users as per requirements)
#───────────────────────────────────────────────────────────────────────────────
echo "[INFO] Creating lab users..."
for i in $(seq -w 1 20); do
    USERNAME="user$i"
    if ! id "$USERNAME" &>/dev/null; then
        useradd -m "$USERNAME"
        echo "password123" | passwd --stdin "$USERNAME"
    fi
done
echo "[OK] Created 20 lab users (user01-user20, password: password123)"

if ! id "labuser" &>/dev/null; then
    useradd -m labuser
    echo "labpass123" | passwd --stdin labuser
fi
echo "[OK] Created labuser (password: labpass123)"

#───────────────────────────────────────────────────────────────────────────────
# Setup NFS mount
#───────────────────────────────────────────────────────────────────────────────
echo "[INFO] Setting up NFS mount..."
dnf install -y nfs-utils

mkdir -p /mnt/nfs-home

if ! grep -q "$NFS_SERVER:/srv/nfs/home" /etc/fstab; then
    echo "$NFS_SERVER:/srv/nfs/home /mnt/nfs-home nfs defaults 0 0" >> /etc/fstab
fi

mount /mnt/nfs-home 2>/dev/null && echo "[OK] NFS mounted" || echo "[WARN] NFS mount failed - will retry on boot"

#───────────────────────────────────────────────────────────────────────────────
# Install Puppet agent
#───────────────────────────────────────────────────────────────────────────────
echo "[INFO] Installing Puppet agent..."
rpm -Uvh https://yum.puppet.com/puppet8-release-el-9.noarch.rpm || true
dnf install -y puppet-agent

cat > /etc/puppetlabs/puppet/puppet.conf << CONF
[main]
server = puppet-master.lab3.local
CONF

sed -i '/puppet-master/d' /etc/hosts
sed -i '/puppet/d' /etc/hosts
echo "$PUPPET_SERVER puppet-master.lab3.local puppet-master puppet" >> /etc/hosts

echo "[OK] Puppet agent installed"

echo "[INFO] Attempting Puppet registration..."
/opt/puppetlabs/bin/puppet agent --test --waitforcert 10 2>/dev/null || echo "[WARN] Puppet master not available - register later"

#───────────────────────────────────────────────────────────────────────────────
# Update status: ready
#───────────────────────────────────────────────────────────────────────────────
curl -s -X POST "$DASHBOARD_URL/api/status" \
    -H "Content-Type: application/json" \
    -d "{\"mac\": \"$MAC_ADDRESS\", \"status\": \"ready\", \"stage\": \"complete\"}" || true

#───────────────────────────────────────────────────────────────────────────────
# Done!
#───────────────────────────────────────────────────────────────────────────────
echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                    SETUP COMPLETE! ✓                          ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "║  Hostname: $HOSTNAME"
echo "║  IP: $IP"
echo "║  MAC: $MAC_ADDRESS"
echo "║  XRDP: Port 3389"
echo "║  Users: user01-user20 (password123), labuser (labpass123)"
echo "║  NFS: /mnt/nfs-home → $NFS_SERVER:/srv/nfs/home"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "Test RDP connection:"
echo "  xfreerdp /v:$IP /u:labuser /p:labpass123"
echo ""
