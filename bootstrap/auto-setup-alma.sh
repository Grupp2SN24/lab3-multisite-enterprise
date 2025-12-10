#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
#  Lab 3 - AlmaLinux Terminal Server Auto Setup v1.0
#  For: terminal-1 (10.10.0.31), terminal-2 (10.10.0.32)
#═══════════════════════════════════════════════════════════════════════════════

set -e

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║     Lab 3 - AlmaLinux Terminal Server Setup v1.0              ║"
echo "╚═══════════════════════════════════════════════════════════════╝"

# Detect which terminal server based on current IP or ask
CURRENT_IP=$(hostname -I | awk '{print $1}' | grep -oE '10\.10\.0\.[0-9]+' || echo "")

if [[ "$CURRENT_IP" == "10.10.0.31" ]]; then
    HOSTNAME="terminal-1"
    IP="10.10.0.31"
elif [[ "$CURRENT_IP" == "10.10.0.32" ]]; then
    HOSTNAME="terminal-2"
    IP="10.10.0.32"
else
    echo ""
    echo "Which terminal server is this?"
    echo "  1) terminal-1 (10.10.0.31)"
    echo "  2) terminal-2 (10.10.0.32)"
    read -p "Enter choice [1-2]: " choice
    case $choice in
        1) HOSTNAME="terminal-1"; IP="10.10.0.31" ;;
        2) HOSTNAME="terminal-2"; IP="10.10.0.32" ;;
        *) echo "Invalid choice"; exit 1 ;;
    esac
fi

GATEWAY="10.10.0.1"
NETMASK="24"
PUPPET_SERVER="192.168.122.40"
NFS_SERVER="10.10.0.40"

echo ""
echo "[INFO] Configuring as: $HOSTNAME ($IP)"
echo ""

#───────────────────────────────────────────────────────────────────────────────
# Set hostname
#───────────────────────────────────────────────────────────────────────────────
echo "[INFO] Setting hostname to $HOSTNAME..."
hostnamectl set-hostname $HOSTNAME
echo "[OK] Hostname set"

#───────────────────────────────────────────────────────────────────────────────
# Configure network with nmcli
#───────────────────────────────────────────────────────────────────────────────
echo "[INFO] Configuring network..."

# Find the interface name (usually eth0, ens3, or enp0s3)
IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | head -1)
echo "[INFO] Detected interface: $IFACE"

# Remove existing connections for this interface
nmcli con delete "services" 2>/dev/null || true
nmcli con delete "Wired connection 1" 2>/dev/null || true

# Create new connection
nmcli con add type ethernet con-name "services" ifname "$IFACE" \
    ipv4.addresses "$IP/$NETMASK" \
    ipv4.gateway "$GATEWAY" \
    ipv4.method manual \
    autoconnect yes

# Add routes to branch networks
nmcli con mod "services" +ipv4.routes "10.20.1.0/24 $GATEWAY"
nmcli con mod "services" +ipv4.routes "10.20.2.0/24 $GATEWAY"
nmcli con mod "services" +ipv4.routes "10.0.0.0/24 $GATEWAY"

# Activate connection
nmcli con up "services"

echo "[OK] Network configured"

#───────────────────────────────────────────────────────────────────────────────
# Install EPEL and XRDP
#───────────────────────────────────────────────────────────────────────────────
echo "[INFO] Installing EPEL repository..."
dnf install -y epel-release

echo "[INFO] Installing XRDP and desktop environment..."
dnf install -y xrdp xorg-x11-server-Xorg xorg-x11-xinit
dnf groupinstall -y "Server with GUI" --skip-broken || dnf install -y xfce4-session xfwm4 || true

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

# Also create labuser for testing
if ! id "labuser" &>/dev/null; then
    useradd -m labuser
    echo "labpass123" | passwd --stdin labuser
fi
echo "[OK] Created labuser (password: labpass123)"

#───────────────────────────────────────────────────────────────────────────────
# Setup NFS mount for shared home directories
#───────────────────────────────────────────────────────────────────────────────
echo "[INFO] Setting up NFS mount..."
dnf install -y nfs-utils

mkdir -p /mnt/nfs-home

# Add to fstab if not already there
if ! grep -q "$NFS_SERVER:/srv/nfs/home" /etc/fstab; then
    echo "$NFS_SERVER:/srv/nfs/home /mnt/nfs-home nfs defaults 0 0" >> /etc/fstab
fi

# Try to mount (may fail if NFS server not reachable yet)
mount /mnt/nfs-home 2>/dev/null && echo "[OK] NFS mounted" || echo "[WARN] NFS mount failed - will retry on boot"

#───────────────────────────────────────────────────────────────────────────────
# Install Puppet agent
#───────────────────────────────────────────────────────────────────────────────
echo "[INFO] Installing Puppet agent..."
rpm -Uvh https://yum.puppet.com/puppet8-release-el-9.noarch.rpm || true
dnf install -y puppet-agent

# Configure Puppet
cat > /etc/puppetlabs/puppet/puppet.conf << CONF
[main]
server = puppet-master.lab3.local
CONF

# Add hosts entry
sed -i '/puppet-master/d' /etc/hosts
sed -i '/puppet/d' /etc/hosts
echo "$PUPPET_SERVER puppet-master.lab3.local puppet-master puppet" >> /etc/hosts

echo "[OK] Puppet agent installed"

#───────────────────────────────────────────────────────────────────────────────
# Register with Puppet master (will fail if puppetserver not running)
#───────────────────────────────────────────────────────────────────────────────
echo "[INFO] Attempting Puppet registration..."
/opt/puppetlabs/bin/puppet agent --test --waitforcert 10 2>/dev/null || echo "[WARN] Puppet master not available - register later"

#───────────────────────────────────────────────────────────────────────────────
# Done!
#───────────────────────────────────────────────────────────────────────────────
echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                    SETUP COMPLETE! ✓                          ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "║  Hostname: $HOSTNAME"
echo "║  IP: $IP"
echo "║  XRDP: Port 3389"
echo "║  Users: user01-user20 (password123), labuser (labpass123)"
echo "║  NFS: /mnt/nfs-home → $NFS_SERVER:/srv/nfs/home"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "Test RDP connection:"
echo "  xfreerdp /v:$IP /u:labuser /p:labpass123"
echo ""
