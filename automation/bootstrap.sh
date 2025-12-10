#!/bin/bash
#===============================================================================
# Lab 3 - Quick Bootstrap
# 
# Run this on ANY new VM (Debian or AlmaLinux) to auto-configure it.
#
# Usage:
#   curl -s http://10.10.0.40:5000/bootstrap | bash
#
# Or if dashboard not available, run with manual role:
#   curl -s https://raw.githubusercontent.com/Grupp2SN24/lab3-multisite-enterprise/main/automation/auto-setup.sh | bash
#===============================================================================

# Try to get the full auto-setup script from dashboard
DASHBOARD_URL="${DASHBOARD_URL:-http://10.10.0.40:5000}"

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║       Lab 3 - Quick Bootstrap                                 ║"
echo "╚═══════════════════════════════════════════════════════════════╝"

# First, ensure we have network on ens5 (NAT)
if [ ! -f /etc/network/interfaces ] || ! grep -q "ens5" /etc/network/interfaces; then
    echo "[*] Setting up NAT interface (ens5)..."
    mkdir -p /etc/network
    cat >> /etc/network/interfaces << 'EOF'

auto ens5
iface ens5 inet dhcp
EOF
fi

# Bring up ens5
ifup ens5 2>/dev/null || dhclient ens5 2>/dev/null || true
sleep 2

# Force IPv4
echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4 2>/dev/null || true

# Install curl if needed
if ! command -v curl &>/dev/null; then
    apt update && apt install -y curl 2>/dev/null || dnf install -y curl 2>/dev/null
fi

# Try dashboard first
echo "[*] Attempting to contact dashboard at ${DASHBOARD_URL}..."
if curl -s --connect-timeout 5 "${DASHBOARD_URL}" >/dev/null 2>&1; then
    echo "[✓] Dashboard available, running auto-setup..."
    curl -s "${DASHBOARD_URL}/auto-setup.sh" | bash
else
    echo "[!] Dashboard not available, running manual setup..."
    echo "[!] Please ensure MAC address is registered in dashboard first."
    
    # Fallback: try GitHub
    curl -s https://raw.githubusercontent.com/Grupp2SN24/lab3-multisite-enterprise/main/automation/auto-setup.sh | bash
fi
