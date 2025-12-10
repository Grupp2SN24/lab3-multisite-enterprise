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

## Steg 1: Provider Core

Provider core är "internet-leverantören" som kopplar ihop alla sites. Alla PE-routrar kör iBGP sinsemellan.

### 1.1 Skapa routrar och koppla ihop

**Kopplingar:**
```
PE1 Gi0/1 ↔ PE-2 Gi0/1     (10.255.0.0/30)
PE1 Gi0/2 ↔ PE-A Gi0/1     (10.255.0.4/30)
PE-2 Gi0/2 ↔ PE-B Gi0/1    (10.255.0.8/30)
```

### 1.2 Konfigurera PE1

Öppna konsol till PE1 och klistra in:

```
enable
conf t

hostname PE1

bfd slow-timers 2000

interface Loopback0
 ip address 2.2.2.1 255.255.255.255

interface GigabitEthernet0/0
 description Link to CE-DC
 ip address 192.168.100.2 255.255.255.252
 bfd interval 300 min_rx 300 multiplier 3
 no shutdown

interface GigabitEthernet0/1
 description Link to PE-2
 ip address 10.255.0.1 255.255.255.252
 no shutdown

interface GigabitEthernet0/2
 description Link to PE-A
 ip address 10.255.0.5 255.255.255.252
 no shutdown

router ospf 1
 router-id 2.2.2.1
 network 2.2.2.1 0.0.0.0 area 0
 network 10.255.0.0 0.0.0.3 area 0
 network 10.255.0.4 0.0.0.3 area 0

router bgp 65001
 bgp router-id 2.2.2.1
 bgp log-neighbor-changes
 neighbor 2.2.2.2 remote-as 65001
 neighbor 2.2.2.2 update-source Loopback0
 neighbor 2.2.2.10 remote-as 65001
 neighbor 2.2.2.10 update-source Loopback0
 neighbor 2.2.2.11 remote-as 65001
 neighbor 2.2.2.11 update-source Loopback0
 neighbor 192.168.100.1 remote-as 65000
 neighbor 192.168.100.1 description CE-DC
 neighbor 192.168.100.1 fall-over bfd
 address-family ipv4
  neighbor 2.2.2.2 activate
  neighbor 2.2.2.2 next-hop-self
  neighbor 2.2.2.10 activate
  neighbor 2.2.2.10 next-hop-self
  neighbor 2.2.2.11 activate
  neighbor 2.2.2.11 next-hop-self
  neighbor 192.168.100.1 activate
  neighbor 192.168.100.1 prefix-list FROM-DC in
  neighbor 192.168.100.1 maximum-prefix 20 80 warning-only
 exit-address-family

ip prefix-list FROM-DC seq 10 permit 10.0.0.0/24
ip prefix-list FROM-DC seq 20 permit 10.10.0.0/24
ip prefix-list FROM-DC seq 30 permit 10.20.0.0/24
ip prefix-list FROM-DC seq 1000 deny 0.0.0.0/0 le 32

end
write memory
```

### 1.3 Konfigurera PE-2

```
enable
conf t

hostname PE-2

bfd slow-timers 2000

interface Loopback0
 ip address 2.2.2.2 255.255.255.255

interface GigabitEthernet0/0
 description Link to CE-DC
 ip address 192.168.100.6 255.255.255.252
 bfd interval 300 min_rx 300 multiplier 3
 no shutdown

interface GigabitEthernet0/1
 description Link to PE1
 ip address 10.255.0.2 255.255.255.252
 no shutdown

interface GigabitEthernet0/2
 description Link to PE-B
 ip address 10.255.0.9 255.255.255.252
 no shutdown

router ospf 1
 router-id 2.2.2.2
 network 2.2.2.2 0.0.0.0 area 0
 network 10.255.0.0 0.0.0.3 area 0
 network 10.255.0.8 0.0.0.3 area 0

router bgp 65001
 bgp router-id 2.2.2.2
 bgp log-neighbor-changes
 neighbor 2.2.2.1 remote-as 65001
 neighbor 2.2.2.1 update-source Loopback0
 neighbor 2.2.2.10 remote-as 65001
 neighbor 2.2.2.10 update-source Loopback0
 neighbor 2.2.2.11 remote-as 65001
 neighbor 2.2.2.11 update-source Loopback0
 neighbor 192.168.100.5 remote-as 65000
 neighbor 192.168.100.5 description CE-DC
 neighbor 192.168.100.5 fall-over bfd
 address-family ipv4
  neighbor 2.2.2.1 activate
  neighbor 2.2.2.1 next-hop-self
  neighbor 2.2.2.10 activate
  neighbor 2.2.2.10 next-hop-self
  neighbor 2.2.2.11 activate
  neighbor 2.2.2.11 next-hop-self
  neighbor 192.168.100.5 activate
  neighbor 192.168.100.5 prefix-list FROM-DC in
  neighbor 192.168.100.5 maximum-prefix 20 80 warning-only
 exit-address-family

ip prefix-list FROM-DC seq 10 permit 10.0.0.0/24
ip prefix-list FROM-DC seq 20 permit 10.10.0.0/24
ip prefix-list FROM-DC seq 30 permit 10.20.0.0/24
ip prefix-list FROM-DC seq 1000 deny 0.0.0.0/0 le 32

end
write memory
```

### 1.4 Konfigurera PE-A

```
enable
conf t

hostname PE-A

bfd slow-timers 2000

interface Loopback0
 ip address 2.2.2.10 255.255.255.255

interface GigabitEthernet0/0
 description Link to CE-A
 ip address 192.168.101.2 255.255.255.252
 bfd interval 300 min_rx 300 multiplier 3
 no shutdown

interface GigabitEthernet0/1
 description Link to PE1
 ip address 10.255.0.6 255.255.255.252
 no shutdown

router ospf 1
 router-id 2.2.2.10
 network 2.2.2.10 0.0.0.0 area 0
 network 10.255.0.4 0.0.0.3 area 0

router bgp 65001
 bgp router-id 2.2.2.10
 bgp log-neighbor-changes
 neighbor 2.2.2.1 remote-as 65001
 neighbor 2.2.2.1 update-source Loopback0
 neighbor 2.2.2.2 remote-as 65001
 neighbor 2.2.2.2 update-source Loopback0
 neighbor 2.2.2.11 remote-as 65001
 neighbor 2.2.2.11 update-source Loopback0
 neighbor 192.168.101.1 remote-as 65000
 neighbor 192.168.101.1 description CE-A
 neighbor 192.168.101.1 fall-over bfd
 address-family ipv4
  redistribute connected
  neighbor 2.2.2.1 activate
  neighbor 2.2.2.1 next-hop-self
  neighbor 2.2.2.2 activate
  neighbor 2.2.2.2 next-hop-self
  neighbor 2.2.2.11 activate
  neighbor 2.2.2.11 next-hop-self
  neighbor 192.168.101.1 activate
  neighbor 192.168.101.1 prefix-list FROM-BRANCH-A in
  neighbor 192.168.101.1 maximum-prefix 10 80 warning-only
 exit-address-family

ip prefix-list FROM-BRANCH-A seq 10 permit 10.0.1.0/24
ip prefix-list FROM-BRANCH-A seq 20 permit 10.20.1.0/24
ip prefix-list FROM-BRANCH-A seq 1000 deny 0.0.0.0/0 le 32

end
write memory
```

### 1.5 Konfigurera PE-B

```
enable
conf t

hostname PE-B

bfd slow-timers 2000

interface Loopback0
 ip address 2.2.2.11 255.255.255.255

interface GigabitEthernet0/0
 description Link to CE-B
 ip address 192.168.102.2 255.255.255.252
 bfd interval 300 min_rx 300 multiplier 3
 no shutdown

interface GigabitEthernet0/1
 description Link to PE-2
 ip address 10.255.0.10 255.255.255.252
 no shutdown

router ospf 1
 router-id 2.2.2.11
 network 2.2.2.11 0.0.0.0 area 0
 network 10.255.0.8 0.0.0.3 area 0

router bgp 65001
 bgp router-id 2.2.2.11
 bgp log-neighbor-changes
 neighbor 2.2.2.1 remote-as 65001
 neighbor 2.2.2.1 update-source Loopback0
 neighbor 2.2.2.2 remote-as 65001
 neighbor 2.2.2.2 update-source Loopback0
 neighbor 2.2.2.10 remote-as 65001
 neighbor 2.2.2.10 update-source Loopback0
 neighbor 192.168.102.1 remote-as 65000
 neighbor 192.168.102.1 description CE-B
 neighbor 192.168.102.1 fall-over bfd
 address-family ipv4
  neighbor 2.2.2.1 activate
  neighbor 2.2.2.1 next-hop-self
  neighbor 2.2.2.2 activate
  neighbor 2.2.2.2 next-hop-self
  neighbor 2.2.2.10 activate
  neighbor 2.2.2.10 next-hop-self
  neighbor 192.168.102.1 activate
  neighbor 192.168.102.1 prefix-list FROM-BRANCH-B in
  neighbor 192.168.102.1 maximum-prefix 10 80 warning-only
 exit-address-family

ip prefix-list FROM-BRANCH-B seq 10 permit 10.0.2.0/24
ip prefix-list FROM-BRANCH-B seq 20 permit 10.20.2.0/24
ip prefix-list FROM-BRANCH-B seq 1000 deny 0.0.0.0/0 le 32

end
write memory
```

### 1.6 Verifiera Provider Core

Vänta någon minut så OSPF och BGP hinner konvergera, sedan:

```
show ip ospf neighbor
show ip bgp summary
```

Alla iBGP-sessioner ska vara "Established".

---

## Steg 2: Datacenter

CE-DC är hjärtat i nätverket. Den är dual-homed till både PE1 och PE2.

### 2.1 Kopplingar

```
CE-DC Gi0/0 ↔ SERVICES-SW          (10.10.0.1/24)
CE-DC Gi0/1 ↔ PE1 Gi0/0            (192.168.100.0/30)
CE-DC Gi0/2 ↔ PE-2 Gi0/0           (192.168.100.4/30)
CE-DC Gi0/3 ↔ (MGMT - ej använd)   (10.0.0.1/24)
```

### 2.2 Konfigurera CE-DC

Det här är den längsta konfigurationen. Ta det lugnt och klistra in steg för steg.

```
enable
conf t

hostname CE-DC

vrf definition MGMT
 rd 65000:1
 address-family ipv4
 exit-address-family

vrf definition SERVICES
 rd 65000:2
 address-family ipv4
 exit-address-family

vrf definition USER
 rd 65000:3
 address-family ipv4
 exit-address-family

interface Loopback0
 ip address 1.1.1.1 255.255.255.255

interface GigabitEthernet0/0
 description SERVICES VRF Gateway
 ip address 10.10.0.1 255.255.255.0
 ip flow ingress
 ip flow egress
 no shutdown

interface GigabitEthernet0/1
 description Link to PE1
 ip address 192.168.100.1 255.255.255.252
 bfd interval 300 min_rx 300 multiplier 3
 ip flow ingress
 ip flow egress
 no shutdown

interface GigabitEthernet0/2
 description Link to PE2
 ip address 192.168.100.5 255.255.255.252
 bfd interval 300 min_rx 300 multiplier 3
 ip flow ingress
 ip flow egress
 no shutdown

interface GigabitEthernet0/3
 description MGMT VRF
 vrf forwarding MGMT
 ip address 10.0.0.1 255.255.255.0
 no shutdown

! NetFlow
ip flow-export version 9
ip flow-export destination 10.10.0.10 2055
ip flow-export source Loopback0

! BGP Prefix-lists
ip prefix-list DC-OUT seq 10 permit 10.0.0.0/24
ip prefix-list DC-OUT seq 20 permit 10.10.0.0/24
ip prefix-list DC-OUT seq 30 permit 10.20.0.0/24
ip prefix-list DC-OUT seq 1000 deny 0.0.0.0/0 le 32

ip prefix-list DC-IN seq 10 permit 10.0.1.0/24
ip prefix-list DC-IN seq 20 permit 10.0.2.0/24
ip prefix-list DC-IN seq 30 permit 10.20.1.0/24
ip prefix-list DC-IN seq 40 permit 10.20.2.0/24
ip prefix-list DC-IN seq 50 permit 2.2.2.0/24 le 32
ip prefix-list DC-IN seq 60 permit 10.255.0.0/16 le 30
ip prefix-list DC-IN seq 70 permit 192.168.101.0/24 le 30
ip prefix-list DC-IN seq 80 permit 192.168.102.0/24 le 30
ip prefix-list DC-IN seq 1000 deny 0.0.0.0/0 le 32

! Traffic Engineering
route-map SET-COMMUNITY-PE1 permit 10
 set community 65000:110

route-map SET-COMMUNITY-PE2 permit 10
 set community 65000:120

route-map PREFER-PE1 permit 10
 set local-preference 150

route-map PREFER-PE2 permit 10
 set local-preference 100

! BFD
bfd slow-timers 2000

router bgp 65000
 bgp router-id 1.1.1.1
 bgp log-neighbor-changes
 neighbor 192.168.100.2 remote-as 65001
 neighbor 192.168.100.2 description PE1
 neighbor 192.168.100.2 fall-over bfd
 neighbor 192.168.100.6 remote-as 65001
 neighbor 192.168.100.6 description PE2
 neighbor 192.168.100.6 fall-over bfd
 address-family ipv4
  network 10.0.0.0 mask 255.255.255.0
  network 10.10.0.0 mask 255.255.255.0
  network 10.20.0.0 mask 255.255.255.0
  redistribute connected
  neighbor 192.168.100.2 activate
  neighbor 192.168.100.2 send-community
  neighbor 192.168.100.2 allowas-in 2
  neighbor 192.168.100.2 prefix-list DC-IN in
  neighbor 192.168.100.2 prefix-list DC-OUT out
  neighbor 192.168.100.2 route-map PREFER-PE1 in
  neighbor 192.168.100.2 route-map SET-COMMUNITY-PE1 out
  neighbor 192.168.100.2 maximum-prefix 50 80 warning-only
  neighbor 192.168.100.6 activate
  neighbor 192.168.100.6 send-community
  neighbor 192.168.100.6 allowas-in 2
  neighbor 192.168.100.6 prefix-list DC-IN in
  neighbor 192.168.100.6 prefix-list DC-OUT out
  neighbor 192.168.100.6 route-map PREFER-PE2 in
  neighbor 192.168.100.6 route-map SET-COMMUNITY-PE2 out
  neighbor 192.168.100.6 maximum-prefix 50 80 warning-only
 exit-address-family
 address-family ipv4 vrf MGMT
  redistribute connected
 exit-address-family

! Static routes
ip route 2.2.2.0 255.255.255.0 192.168.100.2
ip route 2.2.2.0 255.255.255.0 192.168.100.6 10
ip route 10.0.0.0 255.255.255.0 Null0
ip route 10.20.0.0 255.255.255.0 Null0
ip route 10.255.0.0 255.255.0.0 192.168.100.2
ip route 10.255.0.0 255.255.0.0 192.168.100.6 10
ip route 192.168.101.0 255.255.255.0 192.168.100.2
ip route 192.168.101.0 255.255.255.0 192.168.100.6 10
ip route 192.168.102.0 255.255.255.0 192.168.100.2
ip route 192.168.102.0 255.255.255.0 192.168.100.6 10

! SNMPv3
snmp-server group LAB3-RO v3 priv read LAB3-VIEW access 99
snmp-server view LAB3-VIEW iso included
snmp-server user snmpuser LAB3-RO v3 auth sha Lab3SNMPauth! priv aes 128 Lab3SNMPpriv!
snmp-server location "Datacenter DC - Grupp2 SN24"
snmp-server contact "admin@grupp2.lab3.local"

access-list 99 permit 10.0.0.0 0.0.0.255

! Syslog
logging source-interface Loopback0
logging host 10.0.0.10 vrf MGMT

end
write memory
```

### 2.3 Verifiera CE-DC

```
show ip bgp summary
```

Du ska se två sessioner (PE1 och PE2), båda "Established".

**OBS! Viktigt:** `allowas-in 2` är nödvändigt! Utan detta blockeras routes från branches eftersom de har samma AS-nummer (65000).




# Deployment

## Ordning

```
1. Routrar (Cisco)           ← Konfigurera först
2. Puppet-Master             ← Måste vara igång innan klienter
3. Alla andra servrar        ← Automatiskt via bootstrap
```

---

## Del 1: Routrar (Cisco)


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
