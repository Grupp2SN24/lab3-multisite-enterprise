# Lab 3: Multi-Site Enterprise Network

## Grupp 2 SN24

## ✅ Projektöversikt
Automatiserad multi-site-lösning med DC och två branches (A/B).

**Status:** 12 hosts registrerade i Foreman ✅

---

## Foreman Hosts (12 st)

| Host | OS | Status |
|------|-----|--------|
| desktop-u0643c4 (Windows) | Windows 10 | ✅ |
| thin-client.branch-a.lab3.local | Debian 12.12 | ✅ |
| haproxy-1 | Debian 12.12 | ✅ |
| haproxy-2 | Debian 12.12 | ✅ |
| web-1 | Debian 12.12 | ✅ |
| web-2 | Debian 12.12 | ✅ |
| web-3 | Debian 12.12 | ✅ |
| nfs-server | Debian 12.12 | ✅ |
| ssh-bastion | Debian 12.12 | ✅ |
| puppet-master.lab3.local | Debian 12.12 | ✅ |
| terminal-1 | AlmaLinux 9.4 | ✅ |
| terminal-2 | AlmaLinux 9.4 | ✅ |

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
| SSH-Bastion | 10.10.0.50 | Debian 12 | MFA SSH Gateway |

### Branch A (10.20.1.0/24)
| Enhet | IP | OS | Tjänst |
|-------|-----|-----|--------|
| PXE-Server | 10.20.1.10 | Debian 12 | DHCP/TFTP/PXE |
| Thin-Client | 10.20.1.20 | Debian 12 | PXE-deployed |

### Branch B (10.20.2.0/24)
| Enhet | IP | OS | Tjänst |
|-------|-----|-----|--------|
| Windows-Client | 10.20.2.10 | Windows 10 | Puppet-managed |

---

## Automation

### Puppet Bootstrap
```bash
# Debian
curl -s http://puppet-master.lab3.local/bootstrap-debian.sh | bash

# AlmaLinux
curl -s http://puppet-master.lab3.local/bootstrap-alma.sh | bash
```

### PXE Boot (Branch A)
- Automatisk Debian-installation via preseed
- Puppet-agent installeras automatiskt
- Registreras i Foreman

---

## Demo Testkommandon
```bash
# Test load balancing (kör flera gånger)
curl http://10.10.0.9

# Test RDP till terminal server
xfreerdp /v:10.10.0.31 /u:user01 /p:password123

# Test från Windows
mstsc /v:10.10.0.31
```

---

## Filstruktur
```
├── bootstrap/           # Puppet agent install scripts
├── configs/
│   ├── dc/             # Datacenter configs
│   ├── branch-a/       # Branch A + PXE thin client
│   ├── branch-b/       # Branch B + Windows thin client
│   └── provider/       # PE router configs
├── puppet/
│   ├── manifests/      # site.pp
│   └── modules/        # profile, role modules
├── pxe-server/         # DHCP, TFTP, preseed configs
└── docs/               # Architecture, runbooks
```
