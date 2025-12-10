#!/bin/bash
#===============================================================================
# Lab 3 - PXE Server Auto Setup Script
# Grupp 2 SN24
#
# This script automatically configures the PXE server for Branch A
# Run after basic Debian install with correct MAC address (0c:20:01:00:00:10)
#
# Usage: curl -s http://192.168.122.127:5000/auto-setup-pxe.sh | bash
#===============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
DASHBOARD_URL="${DASHBOARD_URL:-http://192.168.122.127:5000}"
PUPPET_SERVER="192.168.122.127"
PUPPET_FQDN="puppet-master.lab3.local"

# PXE Configuration
PXE_IP="10.20.1.10"
PXE_NETMASK="255.255.255.0"
PXE_GATEWAY="10.20.1.1"
THIN_CLIENT_MAC="0c:20:01:00:00:20"
THIN_CLIENT_IP="10.20.1.20"

export DEBIAN_FRONTEND=noninteractive

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

get_mac() {
    ip link show ens4 2>/dev/null | grep ether | awk '{print $2}' || \
    ip link show eth0 2>/dev/null | grep ether | awk '{print $2}'
}

update_status() {
    curl -s -X POST "${DASHBOARD_URL}/api/status" \
        -H "Content-Type: application/json" \
        -d "{\"mac\": \"${MAC}\", \"status\": \"$1\", \"stage\": \"$2\"}" \
        >/dev/null 2>&1 || true
}

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║       Lab 3 - PXE Server Auto Setup                           ║"
echo "║                    Grupp 2 SN24                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

#===============================================================================
# Step 1: Setup internet via ens5
#===============================================================================
log_info "Setting up internet access via ens5..."
if ! grep -q "auto ens5" /etc/network/interfaces 2>/dev/null; then
    cat >> /etc/network/interfaces << 'EOF'

auto ens5
iface ens5 inet dhcp
EOF
fi
ifup ens5 2>/dev/null || dhclient ens5 2>/dev/null || true
sleep 2

echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4

if ! ping -c 1 8.8.8.8 &>/dev/null; then
    log_error "No internet connectivity!"
    exit 1
fi
log_success "Internet OK"

#===============================================================================
# Step 2: Get MAC and notify dashboard
#===============================================================================
MAC=$(get_mac)
log_info "MAC address: ${MAC}"
update_status "configuring" "starting pxe setup"

#===============================================================================
# Step 3: Set hostname
#===============================================================================
log_info "Setting hostname..."
hostnamectl set-hostname pxe-server
echo "pxe-server" > /etc/hostname
log_success "Hostname set to pxe-server"

#===============================================================================
# Step 4: Configure network
#===============================================================================
log_info "Configuring network interfaces..."
cat > /etc/network/interfaces << EOF
auto lo
iface lo inet loopback

auto ens4
iface ens4 inet static
    address ${PXE_IP}
    netmask ${PXE_NETMASK}
    gateway ${PXE_GATEWAY}

auto ens5
iface ens5 inet dhcp
EOF

ifdown ens4 2>/dev/null || true
ifup ens4 2>/dev/null || true
log_success "Network configured: ${PXE_IP}"

update_status "configuring" "network configured"

#===============================================================================
# Step 5: Install packages
#===============================================================================
log_info "Installing PXE packages..."
apt-get update
apt-get install -y -o Dpkg::Options::=--force-confdef \
    isc-dhcp-server tftpd-hpa apache2 pxelinux syslinux-common wget curl git

log_success "Packages installed"
update_status "configuring" "packages installed"

#===============================================================================
# Step 6: Configure DHCP server
#===============================================================================
log_info "Configuring DHCP server..."
cat > /etc/dhcp/dhcpd.conf << EOF
option domain-name "branch-a.lab3.local";
option domain-name-servers 8.8.8.8, 8.8.4.4;
default-lease-time 600;
max-lease-time 7200;
authoritative;

subnet 10.20.1.0 netmask 255.255.255.0 {
  range 10.20.1.100 10.20.1.150;
  option routers ${PXE_GATEWAY};
  option broadcast-address 10.20.1.255;
  next-server ${PXE_IP};
  filename "pxelinux.0";
}

host thin-client-a {
  hardware ethernet ${THIN_CLIENT_MAC};
  fixed-address ${THIN_CLIENT_IP};
}
EOF

echo 'INTERFACESv4="ens4"' > /etc/default/isc-dhcp-server
log_success "DHCP configured"

#===============================================================================
# Step 7: Setup TFTP
#===============================================================================
log_info "Setting up TFTP boot environment..."
mkdir -p /var/lib/tftpboot/pxelinux.cfg
mkdir -p /var/lib/tftpboot/debian

# Copy boot files
cp /usr/lib/PXELINUX/pxelinux.0 /var/lib/tftpboot/
cp /usr/lib/syslinux/modules/bios/ldlinux.c32 /var/lib/tftpboot/
cp /usr/lib/syslinux/modules/bios/libutil.c32 /var/lib/tftpboot/
cp /usr/lib/syslinux/modules/bios/libcom32.c32 /var/lib/tftpboot/
cp /usr/lib/syslinux/modules/bios/vesamenu.c32 /var/lib/tftpboot/

# Create PXE menu
cat > /var/lib/tftpboot/pxelinux.cfg/default << EOF
DEFAULT vesamenu.c32
PROMPT 0
TIMEOUT 100
ONTIMEOUT debian

MENU TITLE PXE Boot Menu - Lab 3 Branch A

LABEL debian
  MENU LABEL Install Debian Thin Client (Automated)
  KERNEL debian/linux
  APPEND initrd=debian/initrd.gz auto=true priority=critical url=http://${PXE_IP}/preseed/thin-client.cfg debian-installer/locale=sv_SE keyboard-configuration/xkb-keymap=se netcfg/get_hostname=thin-client-a netcfg/get_domain=branch-a.lab3.local

LABEL local
  MENU LABEL Boot from local disk
  LOCALBOOT 0
EOF

log_success "TFTP configured"
update_status "configuring" "tftp configured"

#===============================================================================
# Step 8: Download Debian netboot files
#===============================================================================
log_info "Downloading Debian netboot files (this may take a minute)..."
cd /var/lib/tftpboot/debian
wget -q http://deb.debian.org/debian/dists/bookworm/main/installer-amd64/current/images/netboot/debian-installer/amd64/linux
wget -q http://deb.debian.org/debian/dists/bookworm/main/installer-amd64/current/images/netboot/debian-installer/amd64/initrd.gz
log_success "Netboot files downloaded"

#===============================================================================
# Step 9: Create preseed file
#===============================================================================
log_info "Creating preseed file for thin-client..."
mkdir -p /var/www/html/preseed

cat > /var/www/html/preseed/thin-client.cfg << 'PRESEEDEOF'
# Localization
d-i debian-installer/locale string sv_SE.UTF-8
d-i keyboard-configuration/xkb-keymap select se

# Network
d-i netcfg/choose_interface select auto
d-i netcfg/get_hostname string thin-client-a
d-i netcfg/get_domain string branch-a.lab3.local

# Mirror
d-i mirror/country string manual
d-i mirror/http/hostname string deb.debian.org
d-i mirror/http/directory string /debian
d-i mirror/http/proxy string

# Clock
d-i clock-setup/utc boolean true
d-i time/zone string Europe/Stockholm

# Partitioning
d-i partman-auto/method string regular
d-i partman-auto/choose_recipe select atomic
d-i partman/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true

# Users
d-i passwd/root-login boolean true
d-i passwd/root-password password debian
d-i passwd/root-password-again password debian
d-i passwd/user-fullname string Debian User
d-i passwd/username string debian
d-i passwd/user-password password debian
d-i passwd/user-password-again password debian
d-i user-setup/allow-password-weak boolean true

# Packages
tasksel tasksel/first multiselect standard, ssh-server
d-i pkgsel/include string sudo curl wget vim freerdp2-x11
popularity-contest popularity-contest/participate boolean false

# Bootloader
d-i grub-installer/only_debian boolean true
d-i grub-installer/bootdev string default

# Post-install: Network + Puppet
d-i preseed/late_command string \
  in-target bash -c 'cat > /etc/network/interfaces << NETCFG
auto lo
iface lo inet loopback

auto ens4
iface ens4 inet dhcp
    up ip route add 10.10.0.0/24 via 10.20.1.1
NETCFG'; \
  in-target bash -c 'cd /tmp && wget -q https://apt.puppet.com/puppet8-release-bookworm.deb && dpkg -i puppet8-release-bookworm.deb && apt-get update && apt-get install -y puppet-agent'; \
  in-target bash -c 'echo "192.168.122.127 puppet-master.lab3.local puppet-master puppet" >> /etc/hosts'; \
  in-target bash -c 'mkdir -p /etc/puppetlabs/puppet && echo -e "[main]\nserver = puppet-master.lab3.local" > /etc/puppetlabs/puppet/puppet.conf'; \
  in-target bash -c 'echo "debian ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers'

d-i finish-install/reboot_in_progress note
PRESEEDEOF

log_success "Preseed file created"
update_status "configuring" "preseed created"

#===============================================================================
# Step 10: Start services
#===============================================================================
log_info "Starting PXE services..."
systemctl enable isc-dhcp-server tftpd-hpa apache2
systemctl restart tftpd-hpa
systemctl restart apache2
systemctl restart isc-dhcp-server

log_success "Services started"

#===============================================================================
# Step 11: Install Puppet agent
#===============================================================================
log_info "Installing Puppet agent..."
sed -i '/puppet-master/d' /etc/hosts
sed -i '/puppet/d' /etc/hosts
echo "${PUPPET_SERVER} ${PUPPET_FQDN} puppet-master puppet" >> /etc/hosts

cd /tmp
wget -q https://apt.puppet.com/puppet8-release-bookworm.deb
dpkg -i puppet8-release-bookworm.deb
apt-get update
apt-get install -y puppet-agent

cat > /etc/puppetlabs/puppet/puppet.conf << EOF
[main]
server = ${PUPPET_FQDN}
EOF

log_success "Puppet agent installed"

#===============================================================================
# Step 12: Register with Puppet
#===============================================================================
log_info "Registering with Puppet master..."
/opt/puppetlabs/bin/puppet agent --test --waitforcert 30 || true

#===============================================================================
# Step 13: Verify setup
#===============================================================================
log_info "Verifying PXE setup..."
echo ""
echo "Service Status:"
systemctl is-active isc-dhcp-server && echo "  DHCP: ✓ Running" || echo "  DHCP: ✗ Failed"
systemctl is-active tftpd-hpa && echo "  TFTP: ✓ Running" || echo "  TFTP: ✗ Failed"
systemctl is-active apache2 && echo "  Apache: ✓ Running" || echo "  Apache: ✗ Failed"

echo ""
echo "Files:"
[ -f /var/lib/tftpboot/pxelinux.0 ] && echo "  pxelinux.0: ✓" || echo "  pxelinux.0: ✗"
[ -f /var/lib/tftpboot/debian/linux ] && echo "  debian/linux: ✓" || echo "  debian/linux: ✗"
[ -f /var/lib/tftpboot/debian/initrd.gz ] && echo "  debian/initrd.gz: ✓" || echo "  debian/initrd.gz: ✗"
[ -f /var/www/html/preseed/thin-client.cfg ] && echo "  preseed: ✓" || echo "  preseed: ✗"

#===============================================================================
# Done!
#===============================================================================
update_status "ready" "pxe server ready"

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║              PXE SERVER SETUP COMPLETE! ✓                     ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "║  Hostname: pxe-server                                         ║"
echo "║  IP: ${PXE_IP}                                            ║"
echo "║  DHCP Range: 10.20.1.100 - 10.20.1.150                       ║"
echo "║  Thin-client MAC: ${THIN_CLIENT_MAC}                       ║"
echo "║  Thin-client IP: ${THIN_CLIENT_IP}                            ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "║  NEXT: Create thin-client-a VM in GNS3                        ║"
echo "║  - MAC: 0c:20:01:00:00:20                                     ║"
echo "║  - Boot: Network first                                        ║"
echo "║  - Connect ens4 to LAN-SW-A                                   ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
