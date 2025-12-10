# Lab 3 Automationsguide

## Grupp 2 SN24

---

# 📋 MAC-adresslista

**Sätt dessa MAC-adresser på ens4 (första nätverkskortet) i GNS3 innan du startar VM:en.**

| Enhet | MAC-adress | IP (sätts automatiskt) | OS | Roll |
|-------|------------|------------------------|-----|------|
| **DATACENTER - SERVICES VRF** |
| haproxy-1 | `0c:10:00:00:00:10` | 10.10.0.10 | Debian 12 | Load Balancer (VRRP Master) |
| haproxy-2 | `0c:10:00:00:00:11` | 10.10.0.11 | Debian 12 | Load Balancer (VRRP Backup) |
| web-1 | `0c:10:00:00:00:21` | 10.10.0.21 | Debian 12 | Apache Web Server |
| web-2 | `0c:10:00:00:00:22` | 10.10.0.22 | Debian 12 | Apache Web Server |
| web-3 | `0c:10:00:00:00:23` | 10.10.0.23 | Debian 12 | Apache Web Server |
| terminal-1 | `0c:10:00:00:00:31` | 10.10.0.31 | **AlmaLinux 9** | XRDP Terminal Server |
| terminal-2 | `0c:10:00:00:00:32` | 10.10.0.32 | **AlmaLinux 9** | XRDP Terminal Server |
| nfs-server | `0c:10:00:00:00:40` | 10.10.0.40 | Debian 12 | NFS File Server |
| ssh-bastion | `0c:10:00:00:00:50` | 10.10.0.50 | Debian 12 | SSH Gateway + MFA |
| **DATACENTER - MGMT VRF** |
| puppet-master | `0c:00:00:00:00:10` | 10.0.0.10 | Debian 12 | Puppet Server + Dashboard |
| **BRANCH A** |
| thin-client-a | `0c:20:01:00:00:20` | 10.20.1.20 | Debian 12 | Thin Client |
| **BRANCH B** |
| windows-client | `0c:20:02:00:00:10` | 10.20.2.10 | Windows 10 | Thin Client |

---

# 🔌 Nätverkskopplingar

Varje VM har **två nätverkskort**:

| Interface | Koppling | Syfte |
|-----------|----------|-------|
| **ens4** | Service-switch (SERVICES-SW, LAN-SW-A, etc.) | Intern trafik |
| **ens5** | **MGT-switch** | Internet via DHCP |

**Viktigt:** ens5 måste vara kopplad till MGT-switch/NAT-moln för att få internet via DHCP. Detta behövs för att kunna köra bootstrap-scriptet.

---

# 🚀 Deployment

## Ordning

```
1. Routrar (Cisco)           ← Konfigurera först
2. Puppet-Master             ← Måste vara igång innan klienter
3. Alla andra servrar        ← Automatiskt via bootstrap
```

---

## Del 1: Routrar (Cisco)

Routrarna konfigureras manuellt med copy-paste. Se fullständiga konfigurationer i:
- `configs/provider/` - PE1, PE2, PE-A, PE-B
- `configs/dc/routers/` - CE-DC
- `configs/branch-a/` - CE-A
- `configs/branch-b/` - CE-B

**Verifiera att BGP är uppe innan du fortsätter:**
```
show ip bgp summary
```
Alla sessioner ska vara "Established".

---

## Del 2: Puppet-Master

**Puppet-Master måste vara igång INNAN du deployar andra servrar!**

### Steg 1: Skapa VM i GNS3

| Parameter | Värde |
|-----------|-------|
| MAC-adress (ens4) | `0c:00:00:00:00:10` |
| OS | Debian 12 |
| RAM | 4096 MB |
| ens4 | MGMT-SW |
| ens5 | MGT (NAT) |

### Steg 2: Konfigurera nätverk

```bash
cat > /etc/network/interfaces << 'EOF'
auto lo
iface lo inet loopback

auto ens4
iface ens4 inet static
    address 10.0.0.10
    netmask 255.255.255.0

auto ens5
iface ens5 inet dhcp
EOF

systemctl restart networking
```

### Steg 3: Installera Puppet Server

```bash
hostnamectl set-hostname puppet-master

apt update
apt install -y wget git curl python3 python3-pip python3-venv

# Klona repot
cd /tmp
git clone https://github.com/Grupp2SN24/lab3-multisite-enterprise.git

# Installera Puppet
wget https://apt.puppet.com/puppet8-release-bookworm.deb
dpkg -i puppet8-release-bookworm.deb
apt update
apt install -y puppetserver puppet-agent

# Konfigurera
cat > /etc/puppetlabs/puppet/puppet.conf << 'EOF'
[main]
server = puppet-master.lab3.local
certname = puppet-master.lab3.local
EOF

echo "127.0.0.1 puppet-master.lab3.local puppet-master puppet" >> /etc/hosts

# Starta Puppet Server
systemctl enable puppetserver
systemctl start puppetserver
```

### Steg 4: Installera Flask Dashboard

```bash
mkdir -p /opt/lab3-dashboard
cd /opt/lab3-dashboard

# Kopiera filer från repo
cp -r /tmp/lab3-multisite-enterprise/automation/dashboard/* .
cp /tmp/lab3-multisite-enterprise/bootstrap/auto-setup.sh .
cp /tmp/lab3-multisite-enterprise/bootstrap/auto-setup-alma.sh .

# Installera Flask
python3 -m venv venv
source venv/bin/activate
pip install flask pyyaml

# Skapa service
cat > /etc/systemd/system/lab3-dashboard.service << 'EOF'
[Unit]
Description=Lab 3 Dashboard
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/lab3-dashboard
Environment="PATH=/opt/lab3-dashboard/venv/bin"
ExecStart=/opt/lab3-dashboard/venv/bin/python app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable lab3-dashboard
systemctl start lab3-dashboard
```

### Steg 5: Verifiera

```bash
# Puppet Server
systemctl status puppetserver

# Dashboard
systemctl status lab3-dashboard
curl http://localhost:5000
```

**Dashboard är nu på: http://192.168.122.127:5000**

---

## Del 3: HAProxy-1

### Steg 1: Skapa VM i GNS3

| Parameter | Värde |
|-----------|-------|
| MAC-adress (ens4) | `0c:10:00:00:00:10` |
| OS | Debian 12 |
| ens4 | SERVICES-SW |
| ens5 | MGT (NAT) |

### Steg 2: Konfigurera internet (ens5)

```bash
cat >> /etc/network/interfaces << 'EOF'

auto ens5
iface ens5 inet dhcp
EOF

ifup ens5
```

### Steg 3: Kör bootstrap

```bash
curl -s http://192.168.122.127:5000/auto-setup.sh | bash
```

**Klart!** Scriptet sätter hostname, IP, installerar HAProxy + Keepalived, och registrerar med Puppet.

---

## Del 4: HAProxy-2

### Steg 1: Skapa VM i GNS3

| Parameter | Värde |
|-----------|-------|
| MAC-adress (ens4) | `0c:10:00:00:00:11` |
| OS | Debian 12 |
| ens4 | SERVICES-SW |
| ens5 | MGT (NAT) |

### Steg 2: Konfigurera internet (ens5)

```bash
cat >> /etc/network/interfaces << 'EOF'

auto ens5
iface ens5 inet dhcp
EOF

ifup ens5
```

### Steg 3: Kör bootstrap

```bash
curl -s http://192.168.122.127:5000/auto-setup.sh | bash
```

---

## Del 5: Web-1

### Steg 1: Skapa VM i GNS3

| Parameter | Värde |
|-----------|-------|
| MAC-adress (ens4) | `0c:10:00:00:00:21` |
| OS | Debian 12 |
| ens4 | SERVICES-SW |
| ens5 | MGT (NAT) |

### Steg 2: Konfigurera internet (ens5)

```bash
cat >> /etc/network/interfaces << 'EOF'

auto ens5
iface ens5 inet dhcp
EOF

ifup ens5
```

### Steg 3: Kör bootstrap

```bash
curl -s http://192.168.122.127:5000/auto-setup.sh | bash
```

---

## Del 6: Web-2

### Steg 1: Skapa VM i GNS3

| Parameter | Värde |
|-----------|-------|
| MAC-adress (ens4) | `0c:10:00:00:00:22` |
| OS | Debian 12 |
| ens4 | SERVICES-SW |
| ens5 | MGT (NAT) |

### Steg 2: Konfigurera internet (ens5)

```bash
cat >> /etc/network/interfaces << 'EOF'

auto ens5
iface ens5 inet dhcp
EOF

ifup ens5
```

### Steg 3: Kör bootstrap

```bash
curl -s http://192.168.122.127:5000/auto-setup.sh | bash
```

---

## Del 7: Web-3

### Steg 1: Skapa VM i GNS3

| Parameter | Värde |
|-----------|-------|
| MAC-adress (ens4) | `0c:10:00:00:00:23` |
| OS | Debian 12 |
| ens4 | SERVICES-SW |
| ens5 | MGT (NAT) |

### Steg 2: Konfigurera internet (ens5)

```bash
cat >> /etc/network/interfaces << 'EOF'

auto ens5
iface ens5 inet dhcp
EOF

ifup ens5
```

### Steg 3: Kör bootstrap

```bash
curl -s http://192.168.122.127:5000/auto-setup.sh | bash
```

---

## Del 8: Terminal-1 (AlmaLinux)

**OBS: AlmaLinux använder `dhclient` istället för ifup!**

### Steg 1: Skapa VM i GNS3

| Parameter | Värde |
|-----------|-------|
| MAC-adress (ens4) | `0c:10:00:00:00:31` |
| OS | **AlmaLinux 9** |
| ens4 | SERVICES-SW |
| ens5 | MGT (NAT) |

### Steg 2: Konfigurera internet (ens5)

```bash
dhclient ens5
```

### Steg 3: Kör bootstrap

```bash
curl -s http://192.168.122.127:5000/auto-setup-alma.sh | bash
```

---

## Del 9: Terminal-2 (AlmaLinux)

**OBS: AlmaLinux använder `dhclient` istället för ifup!**

### Steg 1: Skapa VM i GNS3

| Parameter | Värde |
|-----------|-------|
| MAC-adress (ens4) | `0c:10:00:00:00:32` |
| OS | **AlmaLinux 9** |
| ens4 | SERVICES-SW |
| ens5 | MGT (NAT) |

### Steg 2: Konfigurera internet (ens5)

```bash
dhclient ens5
```

### Steg 3: Kör bootstrap

```bash
curl -s http://192.168.122.127:5000/auto-setup-alma.sh | bash
```

---

## Del 10: NFS-Server

### Steg 1: Skapa VM i GNS3

| Parameter | Värde |
|-----------|-------|
| MAC-adress (ens4) | `0c:10:00:00:00:40` |
| OS | Debian 12 |
| ens4 | SERVICES-SW |
| ens5 | MGT (NAT) |

### Steg 2: Konfigurera internet (ens5)

```bash
cat >> /etc/network/interfaces << 'EOF'

auto ens5
iface ens5 inet dhcp
EOF

ifup ens5
```

### Steg 3: Kör bootstrap

```bash
curl -s http://192.168.122.127:5000/auto-setup.sh | bash
```

---

## Del 11: SSH-Bastion

### Steg 1: Skapa VM i GNS3

| Parameter | Värde |
|-----------|-------|
| MAC-adress (ens4) | `0c:10:00:00:00:50` |
| OS | Debian 12 |
| ens4 | SERVICES-SW |
| ens5 | MGT (NAT) |

### Steg 2: Konfigurera internet (ens5)

```bash
cat >> /etc/network/interfaces << 'EOF'

auto ens5
iface ens5 inet dhcp
EOF

ifup ens5
```

### Steg 3: Kör bootstrap

```bash
curl -s http://192.168.122.127:5000/auto-setup.sh | bash
```

---

## Del 12: Thin-Client-A (Branch A)

### Steg 1: Skapa VM i GNS3

| Parameter | Värde |
|-----------|-------|
| MAC-adress (ens4) | `0c:20:01:00:00:20` |
| OS | Debian 12 |
| ens4 | LAN-SW-A |
| ens5 | MGT (NAT) |

### Steg 2: Konfigurera internet (ens5)

```bash
cat >> /etc/network/interfaces << 'EOF'

auto ens5
iface ens5 inet dhcp
EOF

ifup ens5
```

### Steg 3: Kör bootstrap

```bash
curl -s http://192.168.122.127:5000/auto-setup.sh | bash
```

---

## Del 13: Signera Puppet-certifikat

När alla servrar har kört bootstrap, signera certifikaten på Puppet-Master:

```bash
# På Puppet-Master
sudo /opt/puppetlabs/bin/puppetserver ca sign --all
```

Eller klicka **"Sign All Puppet Certs"** i Dashboard.

---

# ✅ Verifiering

### Testa Load Balancing

```bash
for i in {1..6}; do curl -s http://10.10.0.9 | grep Server; done
```

Ska rotera mellan web-1, web-2, web-3.

### Testa RDP till Terminal Server

```bash
xfreerdp /v:10.10.0.31 /u:user01 /p:password123 /cert:ignore
```

### Testa VRRP Failover

```bash
# På HAProxy-1
ip addr show ens4 | grep 10.10.0.9   # VIP ska synas

# Stoppa keepalived
sudo systemctl stop keepalived

# På HAProxy-2 - VIP ska ha flyttat hit
ip addr show ens4 | grep 10.10.0.9
```

---

# 📝 Sammanfattning per enhet

| Enhet | MAC | Steg 1 | Steg 2 | Steg 3 |
|-------|-----|--------|--------|--------|
| puppet-master | `0c:00:00:00:00:10` | Manuell setup | - | - |
| haproxy-1 | `0c:10:00:00:00:10` | Sätt MAC | `ifup ens5` | `curl ... \| bash` |
| haproxy-2 | `0c:10:00:00:00:11` | Sätt MAC | `ifup ens5` | `curl ... \| bash` |
| web-1 | `0c:10:00:00:00:21` | Sätt MAC | `ifup ens5` | `curl ... \| bash` |
| web-2 | `0c:10:00:00:00:22` | Sätt MAC | `ifup ens5` | `curl ... \| bash` |
| web-3 | `0c:10:00:00:00:23` | Sätt MAC | `ifup ens5` | `curl ... \| bash` |
| terminal-1 | `0c:10:00:00:00:31` | Sätt MAC | `dhclient ens5` | `curl .../auto-setup-alma.sh \| bash` |
| terminal-2 | `0c:10:00:00:00:32` | Sätt MAC | `dhclient ens5` | `curl .../auto-setup-alma.sh \| bash` |
| nfs-server | `0c:10:00:00:00:40` | Sätt MAC | `ifup ens5` | `curl ... \| bash` |
| ssh-bastion | `0c:10:00:00:00:50` | Sätt MAC | `ifup ens5` | `curl ... \| bash` |
| thin-client-a | `0c:20:01:00:00:20` | Sätt MAC | `ifup ens5` | `curl ... \| bash` |

**Debian:** 
```bash
cat >> /etc/network/interfaces << 'EOF'

auto ens5
iface ens5 inet dhcp
EOF
ifup ens5
curl -s http://192.168.122.127:5000/auto-setup.sh | bash
```

**AlmaLinux:**
```bash
dhclient ens5
curl -s http://192.168.122.127:5000/auto-setup-alma.sh | bash
```

---

*Grupp 2 SN24 - Lab 3 Multi-Site Enterprise Network*
