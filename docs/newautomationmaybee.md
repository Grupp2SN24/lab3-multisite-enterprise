# Lab 3 Automationsguide

## Grupp 2 SN24

---

# 📋 MAC-adresslista

**Sätt dessa MAC-adresser på första nätverkskortet i GNS3 innan du startar VM:en.**

| Enhet | MAC-adress | IP (sätts automatiskt) | OS | Roll |
|-------|------------|------------------------|-----|------|
| **DATACENTER - SERVICES VRF** |||||
| haproxy-1 | `0c:10:00:00:00:10` | 10.10.0.10 | Debian 12 | Load Balancer (VRRP Master) |
| haproxy-2 | `0c:10:00:00:00:11` | 10.10.0.11 | Debian 12 | Load Balancer (VRRP Backup) |
| web-1 | `0c:10:00:00:00:21` | 10.10.0.21 | Debian 12 | Apache Web Server |
| web-2 | `0c:10:00:00:00:22` | 10.10.0.22 | Debian 12 | Apache Web Server |
| web-3 | `0c:10:00:00:00:23` | 10.10.0.23 | Debian 12 | Apache Web Server |
| terminal-1 | `0c:10:00:00:00:31` | 10.10.0.31 | **AlmaLinux 9** | XRDP Terminal Server |
| terminal-2 | `0c:10:00:00:00:32` | 10.10.0.32 | **AlmaLinux 9** | XRDP Terminal Server |
| nfs-server | `0c:10:00:00:00:40` | 10.10.0.40 | Debian 12 | NFS File Server |
| ssh-bastion | `0c:10:00:00:00:50` | 10.10.0.50 | Debian 12 | SSH Gateway + MFA |
| **DATACENTER - MGMT VRF** |||||
| puppet-master | `0c:00:00:00:00:10` | 10.0.0.10 | Debian 12 | Puppet Server + Dashboard |
| **BRANCH A** |||||
| pxe-server | `0c:20:01:00:00:10` | 10.20.1.10 | Debian 12 | PXE/DHCP/TFTP Server |
| thin-client-a | `0c:20:01:00:00:20` | 10.20.1.20 | Debian 12 | Thin Client (PXE-installerad) |
| **BRANCH B** |||||
| windows-client | `0c:20:02:00:00:10` | 10.20.2.10 | Windows 10 | Thin Client |

---

# 🔌 Nätverkskopplingar

Varje VM har **två nätverkskort**:

| Interface | Koppling | Syfte |
|-----------|----------|-------|
| **Första NIC** | Service-switch (SERVICES-SW, LAN-SW-A, etc.) | Intern trafik |
| **Andra NIC** | **NAT-moln** | Internet via DHCP |

> **OBS!** Interface-namn (ens3, ens4, etc.) beror på ordningen du kopplar i GNS3. Kontrollera alltid vilken interface som har rätt MAC-adress med `ip link show`.

---

# Steg 1: Provider Core

Provider core är "internet-leverantören" som kopplar ihop alla sites. Alla PE-routrar kör iBGP sinsemellan.

## 1.1 Skapa routrar och koppla ihop

**Kopplingar:**

```
PE1 Gi0/1 ↔ PE-2 Gi0/1     (10.255.0.0/30)
PE1 Gi0/2 ↔ PE-A Gi0/1     (10.255.0.4/30)
PE-2 Gi0/2 ↔ PE-B Gi0/1    (10.255.0.8/30)
```

## 1.2 Konfigurera PE1

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

## 1.3 Konfigurera PE-2

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

## 1.4 Konfigurera PE-A

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

## 1.5 Konfigurera PE-B

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

## 1.6 Verifiera Provider Core

Vänta någon minut så OSPF och BGP hinner konvergera, sedan:

```
show ip ospf neighbor
show ip bgp summary
```

Alla iBGP-sessioner ska vara "Established".

---

# Steg 2: Datacenter

CE-DC är hjärtat i nätverket. Den är dual-homed till både PE1 och PE2.

## 2.1 Kopplingar

```
CE-DC Gi0/0 ↔ SERVICES-SW          (10.10.0.1/24)
CE-DC Gi0/1 ↔ PE1 Gi0/0            (192.168.100.0/30)
CE-DC Gi0/2 ↔ PE-2 Gi0/0           (192.168.100.4/30)
CE-DC Gi0/3 ↔ MGMT-SW              (10.0.0.1/24)
```

## 2.2 Konfigurera CE-DC (Arista)

```
! INNAN DU KLISTRAR IN:
! 1. Logga in: admin (inget lösenord)
! 2. Kör: zerotouch cancel
! 3. Kör: configure terminal
! 4. Klistra in konfigurationen nedan
```

```
! ============================================
! CE-DC - Arista EOS Configuration
! Grupp 2 SN24
! ============================================
! 
! GNS3 KABELDRAGNING:
!   e0 → Management1 → SERVICES-SW
!   e1 → Ethernet1   → PE1
!   e2 → Ethernet2   → PE2  
!   e3 → Ethernet3   → MGMT-SW (Puppet-Master)
!
! ============================================

enable
configure terminal

hostname CE-DC

! Enable IP routing (required on Arista!)
ip routing

! VRF Instances
vrf instance MGMT
vrf instance SERVICES
vrf instance USER

! Loopback
interface Loopback0
   ip address 1.1.1.1/32

! SERVICES Gateway (e0 i GNS3)
interface Management1
   description SERVICES VRF Gateway - to SERVICES-SW
   ip address 10.10.0.1/24

! Link to PE1 (e1 i GNS3)
interface Ethernet1
   description Link to PE1
   no switchport
   ip address 192.168.100.1/30
   bfd interval 300 min-rx 300 multiplier 3

! Link to PE2 (e2 i GNS3)
interface Ethernet2
   description Link to PE2
   no switchport
   ip address 192.168.100.5/30
   bfd interval 300 min-rx 300 multiplier 3

! MGMT VRF (e3 i GNS3)
interface Ethernet3
   description MGMT VRF - to MGMT-SW
   no switchport
   vrf MGMT
   ip address 10.0.0.1/24

! sFlow (Arista equivalent of NetFlow)
sflow sample 1000
sflow destination 10.10.0.10
sflow source-interface Loopback0
sflow run

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

! Route-maps for Traffic Engineering
route-map SET-COMMUNITY-PE1 permit 10
   set community 65000:110

route-map SET-COMMUNITY-PE2 permit 10
   set community 65000:120

route-map PREFER-PE1 permit 10
   set local-preference 150

route-map PREFER-PE2 permit 10
   set local-preference 100

! BGP Configuration
router bgp 65000
   router-id 1.1.1.1
   maximum-paths 2
   
   neighbor 192.168.100.2 remote-as 65001
   neighbor 192.168.100.2 description PE1
   neighbor 192.168.100.2 bfd
   neighbor 192.168.100.2 allowas-in 2
   neighbor 192.168.100.2 send-community
   neighbor 192.168.100.2 prefix-list DC-IN in
   neighbor 192.168.100.2 prefix-list DC-OUT out
   neighbor 192.168.100.2 route-map PREFER-PE1 in
   neighbor 192.168.100.2 route-map SET-COMMUNITY-PE1 out
   neighbor 192.168.100.2 maximum-routes 50 warning-only
   
   neighbor 192.168.100.6 remote-as 65001
   neighbor 192.168.100.6 description PE2
   neighbor 192.168.100.6 bfd
   neighbor 192.168.100.6 allowas-in 2
   neighbor 192.168.100.6 send-community
   neighbor 192.168.100.6 prefix-list DC-IN in
   neighbor 192.168.100.6 prefix-list DC-OUT out
   neighbor 192.168.100.6 route-map PREFER-PE2 in
   neighbor 192.168.100.6 route-map SET-COMMUNITY-PE2 out
   neighbor 192.168.100.6 maximum-routes 50 warning-only
   
   network 10.0.0.0/24
   network 10.10.0.0/24
   network 10.20.0.0/24
   redistribute connected
   
   ! VRF MGMT
   vrf MGMT
      rd 65000:1
      redistribute connected

! Static routes
ip route 2.2.2.0/24 192.168.100.2
ip route 2.2.2.0/24 192.168.100.6 10
ip route 10.0.0.0/24 Null0
ip route 10.20.0.0/24 Null0
ip route 10.255.0.0/16 192.168.100.2
ip route 10.255.0.0/16 192.168.100.6 10
ip route 192.168.101.0/24 192.168.100.2
ip route 192.168.101.0/24 192.168.100.6 10
ip route 192.168.102.0/24 192.168.100.2
ip route 192.168.102.0/24 192.168.100.6 10

! SNMPv3
snmp-server view LAB3-VIEW iso included
snmp-server group LAB3-RO v3 priv read LAB3-VIEW
snmp-server user snmpuser LAB3-RO v3 auth sha Lab3SNMPauth! priv aes Lab3SNMPpriv!
snmp-server location "Datacenter DC - Grupp2 SN24"
snmp-server contact "admin@grupp2.lab3.local"

! Management ACL
ip access-list standard MGMT-ACCESS
   permit 10.0.0.0/24

! Syslog
logging host 10.0.0.10 vrf MGMT
logging source-interface Loopback0

end
write
```

## 2.3 Verifiera CE-DC

```
show ip bgp summary
```

Du ska se två sessioner (PE1 och PE2), båda "Established".

> **OBS!** `allowas-in 2` är nödvändigt! Utan detta blockeras routes från branches eftersom de har samma AS-nummer (65000).

---

# Steg 3: Branch A - CE-A Router

## 3.1 Kopplingar

```
CE-A Gi0/0 ↔ PE-A Gi0/0      (192.168.101.0/30)
CE-A Gi0/2 ↔ LAN-SW-A        (10.20.1.1/24)
```

## 3.2 Konfigurera CE-A

```
enable
conf t

hostname CE-A

bfd slow-timers 2000

interface Loopback0
 ip address 1.1.1.10 255.255.255.255

interface GigabitEthernet0/0
 description Link to PE-A
 ip address 192.168.101.1 255.255.255.252
 bfd interval 300 min_rx 300 multiplier 3
 no shutdown

interface GigabitEthernet0/2
 description LAN-SW-A - Branch A LAN
 ip address 10.20.1.1 255.255.255.0
 no shutdown

router bgp 65000
 bgp router-id 1.1.1.10
 bgp log-neighbor-changes
 neighbor 192.168.101.2 remote-as 65001
 neighbor 192.168.101.2 description PE-A
 neighbor 192.168.101.2 fall-over bfd
 address-family ipv4
  network 10.0.1.0 mask 255.255.255.0
  network 10.20.1.0 mask 255.255.255.0
  neighbor 192.168.101.2 activate
  neighbor 192.168.101.2 prefix-list BRANCH-A-OUT out
  neighbor 192.168.101.2 maximum-prefix 50 80 warning-only
 exit-address-family

ip prefix-list BRANCH-A-OUT seq 10 permit 10.0.1.0/24
ip prefix-list BRANCH-A-OUT seq 20 permit 10.20.1.0/24
ip prefix-list BRANCH-A-OUT seq 1000 deny 0.0.0.0/0 le 32

ip route 10.0.1.0 255.255.255.0 Null0

end
write memory
```

---

# Deployment

## Ordning

```
1. Routrar (Cisco/Arista)    ← Konfigurera först
2. Puppet-Master             ← Måste vara igång innan klienter
3. Datacenter-servrar        ← Via bootstrap
4. Branch A: PXE-Server      ← Innan thin-client
5. Branch A: Thin-Client-A   ← Via PXE boot
```

---

# Del 1: Puppet-Master

**Puppet-Master måste vara igång INNAN du deployar andra servrar!**

## Steg 1: Skapa VM i GNS3

| Parameter | Värde |
|-----------|-------|
| MAC-adress | `0c:00:00:00:00:10` |
| OS | Debian 12 |
| RAM | 4096 MB |
| NIC 1 | MGMT-SW |
| NIC 2 | NAT-moln |

## Steg 2: Konfigurera nätverk

Logga in och kör:

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

sed -i 's/10.10.0.40/10.10.0.128/g' /opt/lab3-dashboard/*.sh
sed -i 's/10.10.0.127/10.10.0.128/g' /opt/lab3-dashboard/*.sh

systemctl restart networking
```

**(Valfritt) Om du behöver öka diskstorlek på Debian:**

```bash
apt install -y cloud-guest-utils
growpart /dev/sda 1
resize2fs /dev/sda1
```

## Steg 3: Installera Puppet Server

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

## Steg 4: Installera Flask Dashboard

```bash
mkdir -p /opt/lab3-dashboard
cd /opt/lab3-dashboard

# Kopiera filer från repo
cp -r /tmp/lab3-multisite-enterprise/automation/dashboard/* .
cp /tmp/lab3-multisite-enterprise/automation/auto-setup.sh .
cp /tmp/lab3-multisite-enterprise/automation/auto-setup-pxe.sh .
cp /tmp/lab3-multisite-enterprise/automation/bootstrap.sh .
cp /tmp/lab3-multisite-enterprise/bootstrap/auto-setup-alma.sh .

chmod +x *.sh

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

## Steg 5: Verifiera
```bash
# Kontrollera att Puppet Server körs
systemctl status puppetserver

# Kontrollera att Dashboard körs
systemctl status lab3-dashboard

# Testa Dashboard lokalt
curl http://localhost:5000

# Hitta din NAT-IP för att komma åt från webbläsare
ip -4 addr show ens5 | grep inet
```

> **OBS!** ens5 får IP via DHCP och kan ändras vid omstart.
> Kolla alltid aktuell IP med `ip addr show ens5` om dashboarden inte svarar.

**Dashboard finns på:** `http://<DIN-ENS5-IP>:5000`

**Verifiera att alla filer finns:**
```bash
ls -la /opt/lab3-dashboard/*.sh
```

Du ska se:
- `auto-setup.sh`
- `auto-setup-alma.sh`
- `auto-setup-pxe.sh`
- `bootstrap.sh`

## Steg 6: Fixa IP i scripts (VIKTIGT!)

Scripten har hårdkodade IP-adresser som måste uppdateras till din puppet-masters NAT-IP.
```bash
# Kolla din NAT-IP (exempel: 10.10.0.128)
ip addr show ens5 | grep inet

# Ersätt gamla IP:er med din IP
# (ändra .128 till din faktiska IP om den är annorlunda)
sed -i 's/10.10.0.40/10.10.0.128/g' /opt/lab3-dashboard/*.sh
sed -i 's/10.10.0.127/10.10.0.128/g' /opt/lab3-dashboard/*.sh
```

> ⚠️ **VIKTIGT:** Om puppet-master startas om kan NAT-IP:n ändras! 
> Kör `ip addr show ens5` och uppdatera scripten med sed igen om IP:n är ny.

---

# Del 2-11: Datacenter-servrar

## Snabbguide för alla Datacenter-servrar

**Debian-servrar (HAProxy, Web, NFS, SSH-Bastion):**

```bash
# 1. Konfigurera internet
cat >> /etc/network/interfaces << 'EOF'

auto ens5
iface ens5 inet dhcp
EOF
ifup ens5

# (kör "ip addr show ens5" på puppet-master för att hitta IP:n)
curl -s http://<PUPPET-MASTER-IP>:5000/auto-setup.sh | bash
```

**AlmaLinux-servrar (Terminal-1, Terminal-2):**

```bash
# 1. Konfigurera internet
dhclient ens5

# 2. Kör bootstrap (ersätt IP med din puppet-masters ens5 IP)
curl -s http://:5000/auto-setup-alma.sh | bash
```

| Enhet | MAC | Script |
|-------|-----|--------|
| haproxy-1 | `0c:10:00:00:00:10` | auto-setup.sh |
| haproxy-2 | `0c:10:00:00:00:11` | auto-setup.sh |
| web-1 | `0c:10:00:00:00:21` | auto-setup.sh |
| web-2 | `0c:10:00:00:00:22` | auto-setup.sh |
| web-3 | `0c:10:00:00:00:23` | auto-setup.sh |
| terminal-1 | `0c:10:00:00:00:31` | auto-setup-alma.sh |
| terminal-2 | `0c:10:00:00:00:32` | auto-setup-alma.sh |
| nfs-server | `0c:10:00:00:00:40` | auto-setup.sh |
| ssh-bastion | `0c:10:00:00:00:50` | auto-setup.sh |

**Efter varje server, signera Puppet-certifikat på puppet-master:**

```bash
sudo /opt/puppetlabs/bin/puppetserver ca sign --all
```

---

# Del 12: Branch A - PXE-Server

PXE-servern tillhandahåller automatisk nätverksinstallation för thin-clients i Branch A.

## Steg 1: Skapa VM i GNS3

| Parameter | Värde |
|-----------|-------|
| Template | Debian 12 |
| RAM | 2048 MB |
| Disk | 20 GB |

## Steg 2: Konfigurera nätverkskort i GNS3

Högerklicka på VM → Configure → Network

| Adapter | MAC-adress | Koppling |
|---------|------------|----------|
| **Adapter 0** | `0c:20:01:00:00:10` | **LAN-SW-A** |
| **Adapter 1** | (auto) | **NAT-moln** |

> ⚠️ **VIKTIGT:** Adapter 0 MÅSTE vara kopplad till LAN-SW-A, Adapter 1 till NAT!

## Steg 3: Starta och identifiera interfaces

Starta VM:en, logga in som root och kör:

```bash
ip link show
```

Identifiera vilken interface som har MAC `0c:20:01:00:00:10`:

```bash
ip link show | grep -A1 "0c:20:01:00:00:10"
```

**Notera interface-namnet** (t.ex. `ens3` eller `ens4`) - detta är din LAN-interface.

## Steg 4: Konfigurera internet

Identifiera din NAT-interface (den ANDRA interfacen) och aktivera DHCP:

```bash
# Om ens3 är LAN, då är ens4 NAT:
dhclient ens4

# ELLER om ens4 är LAN, då är ens5 NAT:
dhclient ens5
```

Verifiera internet:

```bash
ping -c 2 8.8.8.8
```

## Steg 5: Kör bootstrap-scriptet

```bash
curl -s http://:5000/auto-setup-pxe.sh | bash
```

Scriptet gör automatiskt:
- Sätter hostname till `pxe-server`
- Konfigurerar IP `10.20.1.10` på LAN-interface
- Installerar DHCP, TFTP, Apache
- Konfigurerar NAT gateway för thin-clients
- Laddar ner Debian netboot-filer
- Skapar preseed för automatisk installation
- Installerar Puppet agent

## Steg 6: Signera Puppet-certifikat

**På puppet-master:**

```bash
sudo /opt/puppetlabs/bin/puppetserver ca sign --certname pxe-server
```

## Steg 7: Verifiera

**På pxe-server:**

```bash
systemctl status isc-dhcp-server
systemctl status tftpd-hpa
systemctl status apache2
```

Alla tre ska visa "active (running)".

---

# Del 13: Branch A - Thin-Client-A (PXE-installation)

Thin-client-a installeras automatiskt via PXE från pxe-server.

## Steg 1: Skapa VM i GNS3

| Parameter | Värde |
|-----------|-------|
| Template | Debian 12 (eller tom QEMU VM) |
| RAM | 2048 MB |
| Disk | 20 GB |
| **Boot order** | **Network FÖRST** |

## Steg 2: Konfigurera nätverkskort i GNS3

Högerklicka på VM → Configure → Network

| Adapter | MAC-adress | Koppling |
|---------|------------|----------|
| **Adapter 0** | `0c:20:01:00:00:20` | **LAN-SW-A** |
| **Adapter 1** | (auto) | **NAT-moln** |

> ⚠️ **VIKTIGT:** Samma ordning som PXE-server - Adapter 0 till LAN-SW-A!

## Steg 3: Konfigurera boot-ordning

Högerklicka på VM → Configure → Advanced/Boot:
- Sätt **Network boot** som första alternativ
- Eller ställ in BIOS boot order via konsolen

## Steg 4: Starta och PXE-boota

1. Starta VM:en
2. Den ska automatiskt få IP via DHCP från pxe-server
3. PXE-menyn visas: **"Install Debian Thin Client (Automated)"**
4. Vänta 10 sekunder eller tryck Enter

## Steg 5: Manuellt val av nätverksinterface

> ⚠️ **VIKTIGT - MANUELLT STEG!**

När installern frågar **"Configure the network"** och visar flera interfaces:

```
Primary network interface:
  ens3: Intel Corporation 82540EM Gigabit Ethernet Controller
  ens4: Intel Corporation 82540EM Gigabit Ethernet Controller
```

**Välj den interface som är kopplad till LAN-SW-A** (samma interface som fick DHCP-adress från PXE-servern).

Tips: Det är oftast den FÖRSTA interfacen (ens3) om du följde kopplings-ordningen ovan.

## Steg 6: Vänta på installation

Installationen tar ca 5-10 minuter:
1. Hämtar paket från internet (via PXE-serverns NAT)
2. Installerar Debian base system
3. Kör late_command (installerar Puppet agent)
4. Startar om automatiskt

## Steg 7: Logga in och verifiera

Efter reboot, logga in:
- **Användare:** `debian`
- **Lösenord:** `debian`

Verifiera nätverket:

```bash
ip addr show
ping 10.20.1.10      # PXE-server
ping 10.10.0.1       # CE-DC (datacenter)
```

## Steg 8: Signera Puppet-certifikat

**På puppet-master:**

```bash
sudo /opt/puppetlabs/bin/puppetserver ca sign --certname thin-client-a.branch-a.lab3.local
```

**På thin-client-a:**

```bash
sudo /opt/puppetlabs/bin/puppet agent --test
```

---

# 🔧 Felsökning

## Dashboard inte tillgänglig

```bash
# Kolla att den körs
systemctl status lab3-dashboard

# Kolla att Flask lyssnar på alla interfaces
ss -tlnp | grep 5000
# Ska visa: 0.0.0.0:5000 (inte 127.0.0.1:5000)

# Hitta aktuell IP
ip -4 addr show ens5 | grep inet
```

## Firewall blockerar port 5000

```bash
iptables -I INPUT -p tcp --dport 5000 -j ACCEPT
```

## Problem: PXE-boot hittar ingen server

**Symptom:** "No DHCP offers received" eller timeout

**Lösning:**
1. Verifiera att pxe-server körs: `systemctl status isc-dhcp-server`
2. Kontrollera att thin-client är kopplad till LAN-SW-A
3. Kontrollera MAC-adressen: `0c:20:01:00:00:20`

## Problem: TFTP-fel "File not found"

**Symptom:** PXE laddar men hittar inte boot-filer

**Lösning på pxe-server:**

```bash
# Kontrollera TFTP-katalog
cat /etc/default/tftpd-hpa
# Ska visa: TFTP_DIRECTORY="/var/lib/tftpboot"

# Kontrollera att filer finns
ls -la /var/lib/tftpboot/
ls -la /var/lib/tftpboot/debian/
```

## Problem: Installation fastnar vid "mirror"

**Symptom:** Kan inte nå deb.debian.org

**Orsak:** NAT-gateway på pxe-server fungerar inte

**Lösning på pxe-server:**

```bash
# Aktivera IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Konfigurera NAT
iptables -t nat -A POSTROUTING -o ens5 -j MASQUERADE

# Starta om DHCP
systemctl restart isc-dhcp-server
```

## Problem: Puppet certificate mismatch

**Symptom:** "Certificate does not match private key"

**Orsak:** Gamla certifikat finns kvar från tidigare försök

**Lösning:**

På puppet-master:
```bash
sudo /opt/puppetlabs/bin/puppetserver ca clean --certname 
```

På klienten:
```bash
rm -rf /etc/puppetlabs/puppet/ssl
/opt/puppetlabs/bin/puppet agent --test
```

Sedan signera igen på puppet-master.

---

# ✅ Verifiering

## Testa Load Balancing

```bash
for i in {1..6}; do curl -s http://10.10.0.9 | grep Server; done
```

Ska rotera mellan web-1, web-2, web-3.

## Testa RDP till Terminal Server

```bash
xfreerdp /v:10.10.0.31 /u:user01 /p:password123 /cert:ignore
```

## Testa VRRP Failover

```bash
# På HAProxy-1
ip addr show ens4 | grep 10.10.0.9   # VIP ska synas

# Stoppa keepalived
sudo systemctl stop keepalived

# På HAProxy-2 - VIP ska ha flyttat hit
ip addr show ens4 | grep 10.10.0.9
```

## Testa Branch A → Datacenter

**Från thin-client-a:**

```bash
ping 10.10.0.21        # Web-server
curl http://10.10.0.9  # HAProxy VIP
```

---

# 📝 Komplett checklista

| # | Komponent | MAC | Status |
|---|-----------|-----|--------|
| 1 | PE1, PE-2, PE-A, PE-B | - | ☐ Konfigurerad |
| 2 | CE-DC (Arista) | - | ☐ Konfigurerad |
| 3 | CE-A | - | ☐ Konfigurerad |
| 4 | puppet-master | `0c:00:00:00:00:10` | ☐ Konfigurerad |
| 5 | haproxy-1 | `0c:10:00:00:00:10` | ☐ Bootstrap + Cert |
| 6 | haproxy-2 | `0c:10:00:00:00:11` | ☐ Bootstrap + Cert |
| 7 | web-1 | `0c:10:00:00:00:21` | ☐ Bootstrap + Cert |
| 8 | web-2 | `0c:10:00:00:00:22` | ☐ Bootstrap + Cert |
| 9 | web-3 | `0c:10:00:00:00:23` | ☐ Bootstrap + Cert |
| 10 | terminal-1 | `0c:10:00:00:00:31` | ☐ Bootstrap + Cert |
| 11 | terminal-2 | `0c:10:00:00:00:32` | ☐ Bootstrap + Cert |
| 12 | nfs-server | `0c:10:00:00:00:40` | ☐ Bootstrap + Cert |
| 13 | ssh-bastion | `0c:10:00:00:00:50` | ☐ Bootstrap + Cert |
| 14 | pxe-server | `0c:20:01:00:00:10` | ☐ Bootstrap + Cert |
| 15 | thin-client-a | `0c:20:01:00:00:20` | ☐ PXE-install + Cert |

---

*Grupp 2 SN24 - Lab 3 Multi-Site Enterprise Network*
