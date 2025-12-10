# 🚀 Lab 3 Quick Start Guide (v3.0)

> **Grupp 2 SN24 - Multi-Site Enterprise Network**
> 
> ⚠️ **VIKTIGT:** Puppet-Master använder nu STATISK IP `10.10.0.5` - ändras ALDRIG!

---

## ✅ Vad som är fixat

| Problem | Lösning |
|---------|---------|
| NAT IP ändras vid omstart | Puppet-master har nu statisk IP 10.10.0.5 |
| Scripts slutar fungera | Alla scripts pekar på 10.10.0.5 (statisk) |
| VRF-routing komplex | Puppet-master på samma nät som alla servrar |

---

## 📋 IP-Adressplan (STATISKA!)

| Enhet | IP | MAC | Roll |
|-------|-----|-----|------|
| **puppet-master** | **10.10.0.5** | `0c:00:00:00:00:10` | Puppet + Dashboard |
| haproxy-1 | 10.10.0.10 | `0c:10:00:00:00:10` | LB (VRRP Master) |
| haproxy-2 | 10.10.0.11 | `0c:10:00:00:00:11` | LB (VRRP Backup) |
| web-1/2/3 | 10.10.0.21-23 | `0c:10:00:00:00:2x` | Apache |
| terminal-1/2 | 10.10.0.31-32 | `0c:10:00:00:00:3x` | XRDP (AlmaLinux) |
| nfs-server | 10.10.0.40 | `0c:10:00:00:00:40` | NFS |
| ssh-bastion | 10.10.0.50 | `0c:10:00:00:00:50` | SSH + MFA |
| pxe-server | 10.20.1.10 | `0c:20:01:00:00:10` | PXE/DHCP |
| thin-client-a | 10.20.1.20 | `0c:20:01:00:00:20` | Debian Client |

---

## 🔧 Snabbstart

### 1. Puppet-Master (FÖRST!)

```bash
# Konfigurera nätverk (ens3 = Service-SW, ens4 = NAT)
cat > /etc/network/interfaces << 'EOF'
auto lo
iface lo inet loopback

auto ens3
iface ens3 inet static
    address 10.10.0.5
    netmask 255.255.255.0
    gateway 10.10.0.1

auto ens4
iface ens4 inet dhcp
EOF

systemctl restart networking
```

### 2. Debian-servrar (haproxy, web, nfs, bastion)

```bash
# Aktivera internet
dhclient ens4  # eller ens5

# Kör auto-setup (STATISK IP!)
curl -s http://10.10.0.5:5000/auto-setup.sh | bash
```

### 3. AlmaLinux-servrar (terminal-1, terminal-2)

```bash
dhclient ens4
curl -s http://10.10.0.5:5000/auto-setup-alma.sh | bash
```

### 4. PXE-server (Branch A)

```bash
dhclient ens4
curl -s http://10.10.0.5:5000/auto-setup-pxe.sh | bash
```

### 5. Signera Puppet-certifikat

```bash
# På puppet-master
sudo /opt/puppetlabs/bin/puppetserver ca sign --all
```

---

## 🎯 Demo-kommandon

```bash
# Testa webb VIP
curl http://10.10.0.9

# Testa load balancing
for i in {1..6}; do curl -s http://10.10.0.9 | grep Server; done

# Testa RDP
xfreerdp /v:10.10.0.31 /u:user01 /p:password123 /cert:ignore

# Dashboard
firefox http://10.10.0.5:5000
```

---

## ❓ Frågor?

| Fråga | Svar |
|-------|------|
| Ändras IP vid omstart? | **NEJ!** 10.10.0.5 är statiskt konfigurerad |
| Fungerar det för andra? | **JA!** Alla IP:er är statiska i nätverket |
| Behöver jag uppdatera scripts? | **NEJ!** Allt pekar redan på 10.10.0.5 |

---

**Grupp 2 SN24**

