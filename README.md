# Lab 3: Multi-Site Enterprise Network

## Grupp 2 SN24

## Projektöversikt
Automatiserad multi-site-lösning med DC och två branches (A/B).

---

## Topologi

### Datacenter (DC) - SERVICES VRF (10.10.0.0/24)
| Enhet | IP | OS | Tjänst |
|-------|-----|-----|--------|
| HAPROXY-1 | 10.10.0.10 | Debian 12 | HAProxy + VRRP Master |
| HAPROXY-2 | 10.10.0.11 | Debian 12 | HAProxy + VRRP Backup |
| **VIP** | 10.10.0.9 | - | Virtual IP (Load Balancer) |
| Web-1 | 10.10.0.21 | Debian 12 | Apache2 |
| Web-2 | 10.10.0.22 | Debian 12 | Apache2 |
| Web-3 | 10.10.0.23 | Debian 12 | Apache2 |
| Terminal-1 | 10.10.0.31 | AlmaLinux 9.4 | XRDP + NFS |
| Terminal-2 | 10.10.0.32 | AlmaLinux 9.4 | XRDP + NFS |
| NFS-Server | 10.10.0.40 | Debian 12 | NFS Server |

### Datacenter (DC) - MGMT VRF (10.0.0.0/24)
| Enhet | IP | OS | Tjänst |
|-------|-----|-----|--------|
| Puppet-Master | 10.0.0.10 | Debian 12 | Puppet Server |
| CE-DC (Gi0/3) | 10.0.0.1 | Cisco IOSv | Gateway |

### Routing - Enterprise AS65000
| Router | Loopback | Kopplingar |
|--------|----------|------------|
| CE-DC | 1.1.1.1 | PE1, PE2 (dual-homed eBGP) |
| CE-A | 1.1.1.10 | PE-A |
| CE-B | 1.1.1.11 | PE-B |

### Provider Core AS65001
| Router | Loopback | Roll |
|--------|----------|------|
| PE1 | 2.2.2.1 | DC Provider Edge 1 |
| PE2 | 2.2.2.2 | DC Provider Edge 2 |
| PE-A | 2.2.2.10 | Branch A Provider Edge |
| PE-B | 2.2.2.11 | Branch B Provider Edge |

---

## Tjänster

### Load Balancing (HAProxy + VRRP)
- **VIP:** 10.10.0.9
- **Algoritm:** Round-robin
- **Backends:** Web-1, Web-2, Web-3
- **Failover:** Automatisk mellan HAPROXY-1 (Master) och HAPROXY-2 (Backup)

### Terminal Servers (XRDP)
- **Kapacitet:** 20 samtidiga användare (2 noder)
- **Gemensam lagring:** NFS mount från 10.10.0.40
- **Användare:** labuser / labpass123

### NFS Server
- **Export:** /srv/nfs/home
- **Klienter:** 10.10.0.0/24

---

## Testkommandon
```bash
# Test load balancing (kör flera gånger)
curl http://10.10.0.9

# Test VRRP failover
# På HAPROXY-1: sudo systemctl stop keepalived
# VIP flyttar till HAPROXY-2

# Test RDP till terminal server
xfreerdp /v:10.10.0.31 /u:labuser /p:labpass123
```

---

## Filstruktur
```
configs/
├── dc/
│   ├── routers/
│   │   └── ce-dc-config.txt
│   ├── services/
│   │   ├── haproxy-1/etc/
│   │   ├── haproxy-2/etc/
│   │   ├── web-1/etc/
│   │   ├── web-2/etc/
│   │   ├── web-3/etc/
│   │   ├── terminal-1/etc/
│   │   ├── terminal-2/etc/
│   │   └── nfs-server/etc/
│   └── mgmt/
│       └── puppet-master/etc/
├── branch-a/
└── branch-b/
```
