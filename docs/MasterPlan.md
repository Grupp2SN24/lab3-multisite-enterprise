# Lab 3: Multi-Site Enterprise Network - Komplett Topologi och Byggplan

---

## Innehållsförteckning

1. [Projektöversikt](#1-projektöversikt)
2. [Komplett Nätverkstopologi](#2-komplett-nätverkstopologi)
3. [Komponentlista](#3-komponentlista)
4. [IP-adressplan](#4-ip-adressplan)
5. [Detaljerat Kopplingsschema](#5-detaljerat-kopplingsschema)
6. [VRF-design](#6-vrf-design)
7. [BGP-design och Säkerhet](#7-bgp-design-och-säkerhet)
8. [Observability](#8-observability)
9. [Byggordning (Faser)](#9-byggordning-faser)
10. [Fas 1: Provider Core - Konfigurationsguide](#10-fas-1-provider-core---konfigurationsguide)

---

## 1. Projektöversikt

### 1.1 Syfte
Bygga ett multi-site enterprise-nätverk med:
- Ett datacenter (DC) med dual-homed anslutning
- Två branch-kontor (A och B)
- eBGP-routing mot en simulerad service provider
- Centraliserad konfigurationshantering med Puppet
- Lastbalanserade webbtjänster, terminalservrar och säker SSH-åtkomst

### 1.2 Huvudkrav
| Område | Krav |
|--------|------|
| Routing | eBGP mellan CE och PE, AS65000 (kund), AS65001 (provider) |
| Redundans | DC dual-homed till PE1+PE2, VRRP för load balancers |
| Segmentering | VRF: MGMT, SERVICES, USER |
| Automation | Puppet för all provisioning |
| Säkerhet | Prefix-filter, max-prefix, BFD, SNMPv3 |
| Tjänster | HAProxy, Apache×3, Terminal×2, NFS, SSH-bastion |

### 1.3 Resursbegränsning
- **Tillgängligt RAM:** 16 GB
- **Strategi:** Bygga i faser, pausa enheter mellan faser

---

## 2. Komplett Nätverkstopologi

```
╔══════════════════════════════════════════════════════════════════════════════════════════════════════════╗
║                                        PROVIDER CORE (AS 65001)                                          ║
╠══════════════════════════════════════════════════════════════════════════════════════════════════════════╣
║                                                                                                          ║
║                                    ┌─────────────────────────────────┐                                   ║
║                                    │      iBGP FULL MESH + OSPF      │                                   ║
║                                    │                                 │                                   ║
║                              PE1 (IOSv)════════════════PE2 (IOSv)    │                                   ║
║                              Lo: 2.2.2.1              Lo: 2.2.2.2    │                                   ║
║                              Gi0/1 ←──10.255.0.0/30──→ Gi0/1         │                                   ║
║                                │                           │         │                                   ║
║                           Gi0/2│                           │Gi0/2    │                                   ║
║                      10.255.0.4/30                    10.255.0.8/30  │                                   ║
║                                │                           │         │                                   ║
║                           Gi0/1│                           │Gi0/1    │                                   ║
║                          PE-A (IOSv)                  PE-B (IOSv)    │                                   ║
║                          Lo: 2.2.2.10                Lo: 2.2.2.11    │                                   ║
║                                │                           │         │                                   ║
║                                └───────────────────────────┘         │                                   ║
║                                                                                                          ║
╠══════════════════════════════════════════════════════════════════════════════════════════════════════════╣
║                                        eBGP PEERING (CE ↔ PE)                                            ║
╠══════════════════════════════════════════════════════════════════════════════════════════════════════════╣
║                                                                                                          ║
║         ┌────────────────────────────────────────────────────────────────────────────────────────┐       ║
║         │                                                                                        │       ║
║    Gi0/0│192.168.101.0/30                   192.168.100.0/30   192.168.100.4/30    192.168.102.0/30│Gi0/0 ║
║         │                                          │                 │                           │       ║
║         │                                     Gi0/0│            Gi0/0│                           │       ║
║         │                                          │                 │                           │       ║
║      PE-A                                        PE1               PE2                        PE-B       ║
║         │                                          │                 │                           │       ║
║         │eBGP                                      │eBGP        eBGP│                       eBGP│       ║
║         │                                          │                 │                           │       ║
║      CE-A                                          └────CE-DC────────┘                        CE-B       ║
║    (IOSv)                                           (Arista vEOS)                            (IOSv)      ║
║  Lo:1.1.1.10                                         Lo:1.1.1.1                            Lo:1.1.1.11   ║
║                                                                                                          ║
╠══════════════════════════════════════════════════════════════════════════════════════════════════════════╣
║                                        CUSTOMER EDGE (AS 65000)                                          ║
╠══════════════════════════════════════════════════════════════════════════════════════════════════════════╣
║                                                                                                          ║
║    ┌──────────────┐                    ┌────────────────────────────────────┐              ┌──────────────┐
║    │   BRANCH A   │                    │           DATACENTER (DC)          │              │   BRANCH B   │
║    │              │                    │                                    │              │              │
║    │    CE-A      │                    │              CE-DC                 │              │     CE-B     │
║    │   (IOSv)     │                    │          (Arista vEOS)             │              │    (IOSv)    │
║    │      │       │                    │      │                  │          │              │       │      │
║    │ Gi0/1│       │                    │ Eth1 │             Eth2 │          │              │  Gi0/1│      │
║    │10.20.1.1     │                    │10.0.0.1           10.10.0.1        │              │10.20.2.1     │
║    │      │       │                    │      │                  │          │              │       │      │
║    │      │       │                    │      │                  │          │              │       │      │
║    │ ┌────┴────┐  │                    │ ┌────┴────┐      ┌──────┴───────┐  │              │  ┌────┴────┐ │
║    │ │LAN-SW-A │  │                    │ │ MGMT-SW │      │ SERVICES-SW  │  │              │  │LAN-SW-B │ │
║    │ │(EthSW)  │  │                    │ │(IOSvL2) │      │   (IOSvL2)   │  │              │  │(EthSW)  │ │
║    │ └────┬────┘  │                    │ └────┬────┘      └──────┬───────┘  │              │  └────┬────┘ │
║    │      │       │                    │      │                  │          │              │       │      │
║    │ ┌────┴────┐  │                    │      │                  │          │              │  ┌────┴────┐ │
║    │ │Thin-A   │  │                    │ ┌────┴──────────┐  ┌────┴────────────────────┐    │  │Thin-B   │ │
║    │ │(Debian) │  │                    │ │ MGMT VRF      │  │ SERVICES VRF            │    │  │(Windows)│ │
║    │ │10.20.1.10  │                    │ │ 10.0.0.0/24   │  │ 10.10.0.0/24            │    │  │10.20.2.10 │
║    │ └─────────┘  │                    │ │               │  │                         │    │  └─────────┘ │
║    │              │                    │ │ puppet-master-1│  │ haproxy-1    10.10.0.10│    │              │
║    └──────────────┘                    │ │ 10.0.0.10     │  │ haproxy-2    10.10.0.11│    └──────────────┘
║                                        │ │ (puppetserver │  │ VIP          10.10.0.9 │                    
║                                        │ │  +puppetdb    │  │ web-1        10.10.0.21│                    
║                                        │ │  +foreman)    │  │ web-2        10.10.0.22│                    
║                                        │ │               │  │ web-3        10.10.0.23│                    
║                                        │ │ puppet-master-2│  │ terminal-1   10.10.0.31│                    
║                                        │ │ 10.0.0.11     │  │ terminal-2   10.10.0.32│                    
║                                        │ │               │  │ nfs-server   10.10.0.40│                    
║                                        │ └───────────────┘  │ ssh-bastion  10.10.0.50│                    
║                                        │                    └─────────────────────────┘                    
║                                        └────────────────────────────────────────────────┘                  
║                                                                                                          ║
╠══════════════════════════════════════════════════════════════════════════════════════════════════════════╣
║                                            NAT CLOUD (Internet)                                          ║
╠══════════════════════════════════════════════════════════════════════════════════════════════════════════╣
║                                                                                                          ║
║                                           ┌─────────────┐                                                ║
║                                           │  NAT Cloud  │                                                ║
║                                           └──────┬──────┘                                                ║
║                                                  │                                                       ║
║                                           ┌──────┴──────┐                                                ║
║                                           │   NAT-SW    │  (Cisco IOSvL2)                                ║
║                                           │             │                                                ║
║                                           └──────┬──────┘                                                ║
║                                                  │                                                       ║
║              ┌─────────────┬─────────────┬───────┴───────┬─────────────┬─────────────┐                   ║
║              │             │             │               │             │             │                   ║
║          VM:ens5       VM:ens5       VM:ens5         VM:ens5       VM:ens5       VM:ens5                 ║
║       (puppet-m1)   (puppet-m2)   (haproxy-1)     (web-1)      (thin-a)     (alla VMs)                   ║
║                                                                                                          ║
║    Alla VMs andra nätverkskort (ens5) ansluts till NAT-SW för internetåtkomst                            ║
║                                                                                                          ║
╚══════════════════════════════════════════════════════════════════════════════════════════════════════════╝
```

---

## 3. Komponentlista

### 3.1 Nätverksutrustning

| # | Enhet | Typ | Image | RAM | Syfte |
|---|-------|-----|-------|-----|-------|
| 1 | PE1 | Router | Cisco IOSv 15.9 | 512 MB | Provider Edge 1 (mot DC) |
| 2 | PE2 | Router | Cisco IOSv 15.9 | 512 MB | Provider Edge 2 (mot DC) |
| 3 | PE-A | Router | Cisco IOSv 15.9 | 512 MB | Provider Edge (mot Branch A) |
| 4 | PE-B | Router | Cisco IOSv 15.9 | 512 MB | Provider Edge (mot Branch B) |
| 5 | CE-DC | Router | Arista vEOS | 2048 MB | Customer Edge DC (dual-homed) |
| 6 | CE-A | Router | Cisco IOSv 15.9 | 512 MB | Customer Edge Branch A |
| 7 | CE-B | Router | Cisco IOSv 15.9 | 512 MB | Customer Edge Branch B |
| 8 | MGMT-SW | Switch | Cisco IOSvL2 15.2 | 512 MB | DC Management switch |
| 9 | SERVICES-SW | Switch | Cisco IOSvL2 15.2 | 512 MB | DC Services switch |
| 10 | LAN-SW-A | Switch | GNS3 Ethernet Switch | 0 MB | Branch A LAN switch |
| 11 | LAN-SW-B | Switch | GNS3 Ethernet Switch | 0 MB | Branch B LAN switch |
| 12 | NAT-SW | Switch | Cisco IOSvL2 15.2 | 512 MB | NAT distribution switch |

**Subtotal nätverksutrustning: ~6.5 GB RAM**

### 3.2 Servrar - MGMT VRF (DC)

| # | Server | IP | OS | Disk | RAM | Tjänster |
|---|--------|-----|-----|------|-----|----------|
| 1 | puppet-master-1 | 10.0.0.10 | Debian 12 | 40 GB | 4096 MB | puppetserver, puppetdb, postgresql, foreman |
| 2 | puppet-master-2 | 10.0.0.11 | Debian 12 | 40 GB | 2048 MB | puppetserver (ansluter till puppetdb på .10) |

**Subtotal MGMT: ~6 GB RAM**

### 3.3 Servrar - SERVICES VRF (DC)

| # | Server | IP | OS | Disk | RAM | Tjänster |
|---|--------|-----|-----|------|-----|----------|
| 1 | haproxy-1 | 10.10.0.10 | Debian 12 | 20 GB | 512 MB | HAProxy, Keepalived (MASTER) |
| 2 | haproxy-2 | 10.10.0.11 | Debian 12 | 20 GB | 512 MB | HAProxy, Keepalived (BACKUP) |
| 3 | web-1 | 10.10.0.21 | Debian 12 | 20 GB | 512 MB | Apache2 |
| 4 | web-2 | 10.10.0.22 | Debian 12 | 20 GB | 512 MB | Apache2 |
| 5 | web-3 | 10.10.0.23 | Debian 12 | 20 GB | 512 MB | Apache2 |
| 6 | terminal-1 | 10.10.0.31 | Debian 12 | 20 GB | 1024 MB | XRDP, NFS-mount |
| 7 | terminal-2 | 10.10.0.32 | Debian 12 | 20 GB | 1024 MB | XRDP, NFS-mount |
| 8 | nfs-server | 10.10.0.40 | Debian 12 | 40 GB | 512 MB | NFS-server |
| 9 | ssh-bastion | 10.10.0.50 | Debian 12 | 20 GB | 512 MB | SSH + MFA (Google Authenticator) |

**VIP: 10.10.0.9** (VRRP mellan haproxy-1 och haproxy-2)

**Subtotal SERVICES: ~5.5 GB RAM**

### 3.4 Branch-klienter

| # | Klient | IP | OS | Disk | RAM | Syfte |
|---|--------|-----|-----|------|-----|-------|
| 1 | thin-client-a | 10.20.1.10 | Debian 12 | 20 GB | 1024 MB | Tunn klient Branch A |
| 2 | thin-client-b | 10.20.2.10 | Windows 10 | 40 GB | 2048 MB | Tunn klient Branch B |

**Subtotal Branch: ~3 GB RAM**

---

## 4. IP-adressplan

### 4.1 Loopback-adresser (Router-ID)

| Router | Loopback | AS | Roll |
|--------|----------|-----|------|
| PE1 | 2.2.2.1/32 | 65001 | Provider Edge 1 |
| PE2 | 2.2.2.2/32 | 65001 | Provider Edge 2 |
| PE-A | 2.2.2.10/32 | 65001 | Provider Edge Branch A |
| PE-B | 2.2.2.11/32 | 65001 | Provider Edge Branch B |
| CE-DC | 1.1.1.1/32 | 65000 | Customer Edge DC |
| CE-A | 1.1.1.10/32 | 65000 | Customer Edge Branch A |
| CE-B | 1.1.1.11/32 | 65000 | Customer Edge Branch B |

### 4.2 WAN-länkar (Provider Core)

| Länk | Subnät | Ände 1 (IP) | Ände 2 (IP) |
|------|--------|-------------|-------------|
| PE1 ↔ PE2 | 10.255.0.0/30 | PE1: .1 | PE2: .2 |
| PE1 ↔ PE-A | 10.255.0.4/30 | PE1: .5 | PE-A: .6 |
| PE2 ↔ PE-B | 10.255.0.8/30 | PE2: .9 | PE-B: .10 |

### 4.3 WAN-länkar (CE ↔ PE)

| Länk | Subnät | CE (IP) | PE (IP) |
|------|--------|---------|---------|
| CE-DC ↔ PE1 | 192.168.100.0/30 | CE-DC: .1 | PE1: .2 |
| CE-DC ↔ PE2 | 192.168.100.4/30 | CE-DC: .5 | PE2: .6 |
| CE-A ↔ PE-A | 192.168.101.0/30 | CE-A: .1 | PE-A: .2 |
| CE-B ↔ PE-B | 192.168.102.0/30 | CE-B: .1 | PE-B: .2 |

### 4.4 VRF-subnät

| Site | VRF | Subnät | Gateway | Syfte |
|------|-----|--------|---------|-------|
| DC | MGMT | 10.0.0.0/24 | 10.0.0.1 | Puppet, management |
| DC | SERVICES | 10.10.0.0/24 | 10.10.0.1 | Webb, terminal, NFS |
| Branch A | USER | 10.20.1.0/24 | 10.20.1.1 | Tunna klienter |
| Branch B | USER | 10.20.2.0/24 | 10.20.2.1 | Tunna klienter |

### 4.5 MGMT VRF - Detaljerade IP-adresser (10.0.0.0/24)

| Enhet | IP-adress | Syfte |
|-------|-----------|-------|
| CE-DC (Gateway) | 10.0.0.1 | Default gateway |
| puppet-master-1 | 10.0.0.10 | Primär Puppet + PuppetDB + Foreman |
| puppet-master-2 | 10.0.0.11 | Sekundär Puppet |
| (Reserverade) | 10.0.0.2-9 | Framtida bruk |
| (Reserverade) | 10.0.0.12-254 | Framtida bruk |

### 4.6 SERVICES VRF - Detaljerade IP-adresser (10.10.0.0/24)

| Enhet | IP-adress | Syfte |
|-------|-----------|-------|
| CE-DC (Gateway) | 10.10.0.1 | Default gateway |
| HAProxy VIP | 10.10.0.9 | VRRP Virtual IP |
| haproxy-1 | 10.10.0.10 | Load Balancer (MASTER) |
| haproxy-2 | 10.10.0.11 | Load Balancer (BACKUP) |
| web-1 | 10.10.0.21 | Apache webserver |
| web-2 | 10.10.0.22 | Apache webserver |
| web-3 | 10.10.0.23 | Apache webserver |
| terminal-1 | 10.10.0.31 | XRDP terminalserver |
| terminal-2 | 10.10.0.32 | XRDP terminalserver |
| nfs-server | 10.10.0.40 | NFS för hemkataloger |
| ssh-bastion | 10.10.0.50 | SSH gateway med MFA |

### 4.7 USER VRF - Branch A (10.20.1.0/24)

| Enhet | IP-adress | Syfte |
|-------|-----------|-------|
| CE-A (Gateway) | 10.20.1.1 | Default gateway |
| thin-client-a | 10.20.1.10 | Debian tunn klient |
| (DHCP-pool) | 10.20.1.100-200 | Dynamiska adresser |

### 4.8 USER VRF - Branch B (10.20.2.0/24)

| Enhet | IP-adress | Syfte |
|-------|-----------|-------|
| CE-B (Gateway) | 10.20.2.1 | Default gateway |
| thin-client-b | 10.20.2.10 | Windows tunn klient |
| (DHCP-pool) | 10.20.2.100-200 | Dynamiska adresser |

---

## 5. Detaljerat Kopplingsschema

### 5.1 Provider Core - Interna länkar

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           PROVIDER CORE KOPPLINGAR                              │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   PE1                              PE2                                          │
│   ├── Gi0/0 ←───────────────────→ (till CE-DC)                                 │
│   ├── Gi0/1 ←──10.255.0.0/30───→ Gi0/1 (PE2)                                   │
│   ├── Gi0/2 ←──10.255.0.4/30───→ Gi0/1 (PE-A)                                  │
│   └── Lo0: 2.2.2.1                                                              │
│                                                                                 │
│   PE2                                                                           │
│   ├── Gi0/0 ←───────────────────→ (till CE-DC)                                 │
│   ├── Gi0/1 ←──10.255.0.0/30───→ Gi0/1 (PE1)                                   │
│   ├── Gi0/2 ←──10.255.0.8/30───→ Gi0/1 (PE-B)                                  │
│   └── Lo0: 2.2.2.2                                                              │
│                                                                                 │
│   PE-A                                                                          │
│   ├── Gi0/0 ←───────────────────→ (till CE-A)                                  │
│   ├── Gi0/1 ←──10.255.0.4/30───→ Gi0/2 (PE1)                                   │
│   └── Lo0: 2.2.2.10                                                             │
│                                                                                 │
│   PE-B                                                                          │
│   ├── Gi0/0 ←───────────────────→ (till CE-B)                                  │
│   ├── Gi0/1 ←──10.255.0.8/30───→ Gi0/2 (PE2)                                   │
│   └── Lo0: 2.2.2.11                                                             │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 5.2 CE till PE - eBGP-länkar

| Från | Interface | IP | Till | Interface | IP | Subnät |
|------|-----------|-----|------|-----------|-----|--------|
| CE-DC | Eth3 | 192.168.100.1 | PE1 | Gi0/0 | 192.168.100.2 | 192.168.100.0/30 |
| CE-DC | Eth4 | 192.168.100.5 | PE2 | Gi0/0 | 192.168.100.6 | 192.168.100.4/30 |
| CE-A | Gi0/0 | 192.168.101.1 | PE-A | Gi0/0 | 192.168.101.2 | 192.168.101.0/30 |
| CE-B | Gi0/0 | 192.168.102.1 | PE-B | Gi0/0 | 192.168.102.2 | 192.168.102.0/30 |

### 5.3 CE till L2-switchar - LAN-länkar

| Från | Interface | IP | Till | Port | VRF |
|------|-----------|-----|------|------|-----|
| CE-DC | Eth1 | 10.0.0.1 | MGMT-SW | Gi0/0 | MGMT |
| CE-DC | Eth2 | 10.10.0.1 | SERVICES-SW | Gi0/0 | SERVICES |
| CE-A | Gi0/1 | 10.20.1.1 | LAN-SW-A | Port 1 | USER |
| CE-B | Gi0/1 | 10.20.2.1 | LAN-SW-B | Port 1 | USER |

### 5.4 CE-DC (Arista vEOS) - Interface-mappning

```
┌─────────────────────────────────────────────────────────────────┐
│                    CE-DC (Arista vEOS)                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   Interface    │  Anslutning          │  IP            │  VRF   │
│   ─────────────┼──────────────────────┼────────────────┼────────│
│   Loopback0    │  -                   │  1.1.1.1/32    │  -     │
│   Ethernet1    │  → MGMT-SW Gi0/0     │  10.0.0.1/24   │  MGMT  │
│   Ethernet2    │  → SERVICES-SW Gi0/0 │  10.10.0.1/24  │ SERVICES│
│   Ethernet3    │  → PE1 Gi0/0         │  192.168.100.1 │  -     │
│   Ethernet4    │  → PE2 Gi0/0         │  192.168.100.5 │  -     │
│   Management1  │  (ej använd)         │  -             │  -     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 5.5 MGMT-SW (Cisco IOSvL2) - Portmappning

| Port | Anslutning | Kommentar |
|------|------------|-----------|
| Gi0/0 | CE-DC Eth1 | Uplink till gateway |
| Gi0/1 | puppet-master-1 (ens4) | Primär Puppet |
| Gi0/2 | puppet-master-2 (ens4) | Sekundär Puppet |
| Gi0/3 | (Reserverad) | - |
| Gi1/0 | (Reserverad) | - |

### 5.6 SERVICES-SW (Cisco IOSvL2) - Portmappning

| Port | Anslutning | IP | Kommentar |
|------|------------|-----|-----------|
| Gi0/0 | CE-DC Eth2 | - | Uplink till gateway |
| Gi0/1 | haproxy-1 (ens4) | 10.10.0.10 | LB Master |
| Gi0/2 | haproxy-2 (ens4) | 10.10.0.11 | LB Backup |
| Gi0/3 | web-1 (ens4) | 10.10.0.21 | Webserver |
| Gi1/0 | web-2 (ens4) | 10.10.0.22 | Webserver |
| Gi1/1 | web-3 (ens4) | 10.10.0.23 | Webserver |
| Gi1/2 | terminal-1 (ens4) | 10.10.0.31 | Terminalserver |
| Gi1/3 | terminal-2 (ens4) | 10.10.0.32 | Terminalserver |
| Gi2/0 | nfs-server (ens4) | 10.10.0.40 | NFS |
| Gi2/1 | ssh-bastion (ens4) | 10.10.0.50 | SSH Gateway |

### 5.7 LAN-SW-A (GNS3 Ethernet Switch) - Portmappning

| Port | Anslutning | IP |
|------|------------|-----|
| Port 1 | CE-A Gi0/1 | - |
| Port 2 | thin-client-a (ens4) | 10.20.1.10 |

### 5.8 LAN-SW-B (GNS3 Ethernet Switch) - Portmappning

| Port | Anslutning | IP |
|------|------------|-----|
| Port 1 | CE-B Gi0/1 | - |
| Port 2 | thin-client-b (ens4) | 10.20.2.10 |

### 5.9 NAT-SW (Cisco IOSvL2) - Portmappning

| Port | Anslutning | Kommentar |
|------|------------|-----------|
| Gi0/0 | NAT Cloud | Uplink till internet |
| Gi0/1 | puppet-master-1 (ens5) | NAT för VM |
| Gi0/2 | puppet-master-2 (ens5) | NAT för VM |
| Gi0/3 | haproxy-1 (ens5) | NAT för VM |
| Gi1/0 | haproxy-2 (ens5) | NAT för VM |
| Gi1/1 | web-1 (ens5) | NAT för VM |
| Gi1/2 | web-2 (ens5) | NAT för VM |
| Gi1/3 | web-3 (ens5) | NAT för VM |
| Gi2/0 | terminal-1 (ens5) | NAT för VM |
| Gi2/1 | terminal-2 (ens5) | NAT för VM |
| Gi2/2 | nfs-server (ens5) | NAT för VM |
| Gi2/3 | ssh-bastion (ens5) | NAT för VM |
| Gi3/0 | thin-client-a (ens5) | NAT för VM |
| Gi3/1 | thin-client-b (ens5) | NAT för VM |

### 5.10 VM Nätverkskort - Översikt

Varje VM har **två nätverkskort**:

| VM | ens4 (Första NIC) | ens5 (Andra NIC) |
|----|-------------------|------------------|
| puppet-master-1 | MGMT-SW Gi0/1 | NAT-SW Gi0/1 |
| puppet-master-2 | MGMT-SW Gi0/2 | NAT-SW Gi0/2 |
| haproxy-1 | SERVICES-SW Gi0/1 | NAT-SW Gi0/3 |
| haproxy-2 | SERVICES-SW Gi0/2 | NAT-SW Gi1/0 |
| web-1 | SERVICES-SW Gi0/3 | NAT-SW Gi1/1 |
| web-2 | SERVICES-SW Gi1/0 | NAT-SW Gi1/2 |
| web-3 | SERVICES-SW Gi1/1 | NAT-SW Gi1/3 |
| terminal-1 | SERVICES-SW Gi1/2 | NAT-SW Gi2/0 |
| terminal-2 | SERVICES-SW Gi1/3 | NAT-SW Gi2/1 |
| nfs-server | SERVICES-SW Gi2/0 | NAT-SW Gi2/2 |
| ssh-bastion | SERVICES-SW Gi2/1 | NAT-SW Gi2/3 |
| thin-client-a | LAN-SW-A Port 2 | NAT-SW Gi3/0 |
| thin-client-b | LAN-SW-B Port 2 | NAT-SW Gi3/1 |

---

## 6. VRF-design

### 6.1 VRF-översikt

```
┌─────────────────────────────────────────────────────────────────┐
│                    CE-DC VRF STRUKTUR                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ┌──────────────┐    ┌──────────────┐    ┌──────────────┐     │
│   │   VRF: MGMT  │    │VRF: SERVICES │    │  Global/     │     │
│   │              │    │              │    │  Default     │     │
│   │ RD: 65000:1  │    │ RD: 65000:2  │    │              │     │
│   │              │    │              │    │  BGP till    │     │
│   │ 10.0.0.0/24  │    │ 10.10.0.0/24 │    │  PE1 & PE2   │     │
│   │              │    │              │    │              │     │
│   │ Interface:   │    │ Interface:   │    │ Interfaces:  │     │
│   │   Eth1       │    │   Eth2       │    │ Eth3, Eth4   │     │
│   └──────────────┘    └──────────────┘    └──────────────┘     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 6.2 Route Distinguisher (RD)

| VRF | RD | Site |
|-----|-----|------|
| MGMT | 65000:1 | DC |
| SERVICES | 65000:2 | DC |
| USER | 65000:10 | Branch A |
| USER | 65000:20 | Branch B |

### 6.3 Route Leaking

För att trafik ska kunna flöda mellan VRF:er och branches behövs route leaking på CE-DC:

```
MGMT VRF (10.0.0.0/24)
    ↓ leak till Global
    ↓ annonseras via BGP
    ↓
SERVICES VRF (10.10.0.0/24)
    ↓ leak till Global
    ↓ annonseras via BGP
    ↓
Global VRF (BGP)
    ↓
    ↓ tar emot från PE:
    ├── 10.20.1.0/24 (Branch A)
    └── 10.20.2.0/24 (Branch B)
```

### 6.4 Åtkomstmatris mellan VRF

| Från ↓ Till → | MGMT | SERVICES | USER (Branch) |
|---------------|------|----------|---------------|
| **MGMT** | ✅ Full | ✅ Full | ✅ Full |
| **SERVICES** | ❌ Blockerad | ✅ Full | ⚠️ Endast svar |
| **USER** | ❌ Blockerad | ⚠️ HAProxy, Terminal | ✅ Full |

---

## 7. BGP-design och Säkerhet

### 7.1 AS-nummer

| Entitet | AS-nummer | Roll |
|---------|-----------|------|
| Enterprise (kund) | AS 65000 | CE-DC, CE-A, CE-B |
| Provider | AS 65001 | PE1, PE2, PE-A, PE-B |

### 7.2 BGP-sessioner

```
┌─────────────────────────────────────────────────────────────────┐
│                      BGP SESSION ÖVERSIKT                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  PROVIDER CORE (iBGP full mesh över OSPF):                      │
│  ─────────────────────────────────────────                      │
│  PE1 (2.2.2.1) ←──iBGP──→ PE2 (2.2.2.2)                        │
│  PE1 (2.2.2.1) ←──iBGP──→ PE-A (2.2.2.10)                      │
│  PE1 (2.2.2.1) ←──iBGP──→ PE-B (2.2.2.11)                      │
│  PE2 (2.2.2.2) ←──iBGP──→ PE-A (2.2.2.10)                      │
│  PE2 (2.2.2.2) ←──iBGP──→ PE-B (2.2.2.11)                      │
│  PE-A (2.2.2.10) ←─iBGP──→ PE-B (2.2.2.11)                     │
│                                                                 │
│  CE ↔ PE (eBGP):                                               │
│  ───────────────                                                │
│  CE-DC ←──eBGP──→ PE1  (192.168.100.0/30)                      │
│  CE-DC ←──eBGP──→ PE2  (192.168.100.4/30)                      │
│  CE-A  ←──eBGP──→ PE-A (192.168.101.0/30)                      │
│  CE-B  ←──eBGP──→ PE-B (192.168.102.0/30)                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 7.3 BGP Communities

| Community | Betydelse | Användning |
|-----------|-----------|------------|
| 65000:110 | Prefer PE1 | Primary path för DC |
| 65000:120 | Prefer PE2 | Backup path för DC |
| 65000:200 | MGMT prefix | Identifiera management-trafik |
| 65000:210 | SERVICES prefix | Identifiera service-trafik |
| 65000:220 | USER prefix | Identifiera användartrafik |

### 7.4 Prefix-lists

**PE-routrar - Vad de accepterar från CE:**

```
! PE1 och PE2 - accepterar från CE-DC:
ip prefix-list FROM-DC seq 10 permit 10.0.0.0/24      ! MGMT
ip prefix-list FROM-DC seq 20 permit 10.10.0.0/24     ! SERVICES
ip prefix-list FROM-DC seq 1000 deny 0.0.0.0/0 le 32  ! Deny all else

! PE-A - accepterar från CE-A:
ip prefix-list FROM-BRANCH-A seq 10 permit 10.20.1.0/24  ! USER Branch A
ip prefix-list FROM-BRANCH-A seq 1000 deny 0.0.0.0/0 le 32

! PE-B - accepterar från CE-B:
ip prefix-list FROM-BRANCH-B seq 10 permit 10.20.2.0/24  ! USER Branch B
ip prefix-list FROM-BRANCH-B seq 1000 deny 0.0.0.0/0 le 32
```

**CE-routrar - Vad de accepterar från PE:**

```
! CE-DC - accepterar:
ip prefix-list FROM-PROVIDER seq 10 permit 10.20.1.0/24  ! Branch A
ip prefix-list FROM-PROVIDER seq 20 permit 10.20.2.0/24  ! Branch B
ip prefix-list FROM-PROVIDER seq 1000 deny 0.0.0.0/0 le 32

! CE-A och CE-B - accepterar:
ip prefix-list FROM-PROVIDER seq 10 permit 10.0.0.0/24   ! DC MGMT
ip prefix-list FROM-PROVIDER seq 20 permit 10.10.0.0/24  ! DC SERVICES
ip prefix-list FROM-PROVIDER seq 30 permit 10.20.1.0/24  ! Branch A
ip prefix-list FROM-PROVIDER seq 40 permit 10.20.2.0/24  ! Branch B
ip prefix-list FROM-PROVIDER seq 1000 deny 0.0.0.0/0 le 32
```

### 7.5 BGP Säkerhetsfunktioner

| Funktion | Konfiguration | Syfte |
|----------|---------------|-------|
| Max-prefix | `neighbor X maximum-prefix 100 80 warning-only` | Skydd mot route leaks |
| BFD | `neighbor X fall-over bfd` | Snabb failover (300ms) |
| Prefix-filter IN | `neighbor X prefix-list IN in` | Filtrera inkommande |
| Prefix-filter OUT | `neighbor X prefix-list OUT out` | Filtrera utgående |

### 7.6 Traffic Engineering med LOCAL_PREF

```
! CE-DC: Prefer PE1 (higher LOCAL_PREF = preferred)
route-map PREFER-PE1 permit 10
  set local-preference 150

route-map PREFER-PE2 permit 10
  set local-preference 100

! Applicera på BGP neighbors:
neighbor 192.168.100.2 route-map PREFER-PE1 in   ! PE1
neighbor 192.168.100.6 route-map PREFER-PE2 in   ! PE2
```

---

## 8. Observability

### 8.1 Syslog

**Centraliserad loggserver:** puppet-master-1 (10.0.0.10)

```
┌─────────────────────────────────────────────────────────────────┐
│                      SYSLOG FLÖDE                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   CE-DC ─────┐                                                  │
│   CE-A  ─────┼──── UDP 514 ────→  puppet-master-1              │
│   CE-B  ─────┤                    (rsyslog)                     │
│              │                    /var/log/remote/              │
│   Alla VMs ──┘                                                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Router-konfiguration (Cisco):**
```
logging host 10.0.0.10
logging trap informational
logging source-interface Loopback0
```

**Router-konfiguration (Arista):**
```
logging host 10.0.0.10
logging source-interface Loopback0
```

### 8.2 SNMPv3

| Parameter | Värde |
|-----------|-------|
| User | snmpuser |
| Auth Protocol | SHA |
| Auth Password | Lab3SNMPauth! |
| Priv Protocol | AES128 |
| Priv Password | Lab3SNMPpriv! |
| Access | Endast från 10.0.0.0/24 |

**Router-konfiguration (Cisco):**
```
snmp-server group LAB3-RO v3 priv read LAB3-VIEW access 99
snmp-server view LAB3-VIEW iso included
snmp-server user snmpuser LAB3-RO v3 auth sha Lab3SNMPauth! priv aes 128 Lab3SNMPpriv!
access-list 99 permit 10.0.0.0 0.0.0.255
```

### 8.3 NetFlow/IPFIX

**Flow collector:** haproxy-1 (10.10.0.10) med nfcapd

```
┌─────────────────────────────────────────────────────────────────┐
│                     NETFLOW FLÖDE                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   CE-DC ─────┐                                                  │
│   CE-A  ─────┼──── NetFlow v9 UDP 2055 ────→  haproxy-1        │
│   CE-B  ─────┘                                 (nfcapd)         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Router-konfiguration (Cisco):**
```
ip flow-export version 9
ip flow-export destination 10.10.0.10 2055
ip flow-export source Loopback0

interface GigabitEthernet0/1
  ip flow ingress
  ip flow egress
```

---

## 9. Byggordning (Faser)

### Fas-översikt

| Fas | Beskrivning | Aktiva enheter | ~RAM |
|-----|-------------|----------------|------|
| 1 | Provider Core | PE1, PE2, PE-A, PE-B | 2 GB |
| 2 | Customer Edge + L2 | +CE-DC, CE-A, CE-B, alla switchar | 6 GB |
| 3 | Puppet Infrastructure | CE-DC, MGMT-SW, puppet-master-1/2, NAT-SW | 8 GB |
| 4 | DC Services | CE-DC, SERVICES-SW, alla DC-servrar | 8 GB |
| 5 | Branch A | +PE1, PE-A, CE-A, LAN-SW-A, thin-client-a | 8 GB |
| 6 | Branch B | +PE2, PE-B, CE-B, LAN-SW-B, thin-client-b | 8 GB |
| 7 | Integration | Allt (ev. pausa puppet-master-2) | 12-14 GB |

### Fas 1: Provider Core

**Mål:** iBGP mesh mellan alla PE-routrar, OSPF för underliggande konnektivitet

**Aktiva enheter:**
- PE1, PE2, PE-A, PE-B

**Test:**
```
! På alla PE-routrar:
show ip ospf neighbor
show ip bgp summary
ping 2.2.2.1    ! PE1 loopback
ping 2.2.2.2    ! PE2 loopback
ping 2.2.2.10   ! PE-A loopback
ping 2.2.2.11   ! PE-B loopback
```

**Förväntat resultat:**
- OSPF FULL adjacency mellan alla PE
- BGP Established mellan alla PE (iBGP full mesh)
- Alla loopbacks pingbara

### Fas 2: Customer Edge + L2

**Mål:** eBGP-sessioner upp mellan CE och PE, VRF på CE-DC

**Aktiva enheter:**
- Fas 1 + CE-DC, CE-A, CE-B
- MGMT-SW, SERVICES-SW, LAN-SW-A, LAN-SW-B, NAT-SW

**Test:**
```
! På CE-DC:
show ip bgp summary
show vrf

! På CE-A:
show ip bgp summary

! På PE1:
show ip bgp
! Ska se: 10.0.0.0/24, 10.10.0.0/24 från CE-DC
!         10.20.1.0/24 från CE-A (via PE-A)
```

**Förväntat resultat:**
- eBGP Established på alla CE↔PE-sessioner
- DC-prefix (10.0.0.0/24, 10.10.0.0/24) synliga i provider core
- Branch-prefix (10.20.1.0/24, 10.20.2.0/24) synliga i provider core

### Fas 3: Puppet Infrastructure

**Mål:** Fungerande Puppet-miljö med puppetserver, puppetdb, foreman

**Aktiva enheter:**
- CE-DC, MGMT-SW, NAT-SW
- puppet-master-1, puppet-master-2

**Pausa:** PE1, PE2, PE-A, PE-B, CE-A, CE-B (inte nödvändiga)

**Test:**
```bash
# På puppet-master-1:
sudo systemctl status puppetserver
sudo systemctl status puppetdb
curl -k https://localhost:8140/status/v1/simple

# På puppet-master-2:
sudo /opt/puppetlabs/bin/puppet agent --test
```

**Förväntat resultat:**
- puppetserver körs på båda masters
- puppetdb körs på puppet-master-1
- Foreman UI tillgänglig på https://10.0.0.10

### Fas 4: DC Services

**Mål:** Alla DC-tjänster körs och är nåbara

**Aktiva enheter:**
- CE-DC, SERVICES-SW, NAT-SW
- Alla servrar i SERVICES VRF
- (Valfritt: MGMT-SW + puppet-masters för config)

**Test:**
```bash
# Test HAProxy VIP:
curl http://10.10.0.9

# Test load balancing (kör flera gånger):
for i in {1..6}; do curl -s http://10.10.0.9 | grep -i server; done

# Test RDP:
xfreerdp /v:10.10.0.31 /u:user01 /p:password

# Test NFS:
showmount -e 10.10.0.40

# Test SSH-bastion (med MFA):
ssh admin@10.10.0.50
```

**Förväntat resultat:**
- HAProxy VIP (10.10.0.9) svarar
- Trafik lastbalanseras mellan web-1, web-2, web-3
- RDP till terminal-1 och terminal-2 fungerar
- NFS-export synlig
- SSH med MFA fungerar

### Fas 5: Branch A

**Mål:** Debian thin client kan nå DC-tjänster

**Aktiva enheter:**
- CE-DC, SERVICES-SW (minst HAProxy + terminal)
- PE1, PE-A, CE-A, LAN-SW-A, NAT-SW
- thin-client-a

**Test från thin-client-a:**
```bash
# Test routing:
ping 10.20.1.1      # Gateway
ping 10.10.0.9      # HAProxy VIP
traceroute 10.10.0.9

# Test webb:
curl http://10.10.0.9

# Test RDP:
xfreerdp /v:10.10.0.31 /u:user01 /p:password
```

**Förväntat resultat:**
- thin-client-a kan pinga DC-tjänster
- Webbtjänst fungerar från Branch A
- RDP till terminalserver fungerar

### Fas 6: Branch B

**Mål:** Windows thin client kan nå DC-tjänster

**Aktiva enheter:**
- CE-DC, SERVICES-SW
- PE2, PE-B, CE-B, LAN-SW-B, NAT-SW
- thin-client-b

**Test från thin-client-b (Windows):**
```cmd
ping 10.10.0.9
curl http://10.10.0.9
mstsc /v:10.10.0.31
```

**Förväntat resultat:**
- Windows-klient kan nå DC
- RDP fungerar

### Fas 7: Full Integration

**Mål:** Alla komponenter fungerar tillsammans

**Aktiva enheter:**
- Alla (pausa puppet-master-2 om RAM-brist)

**Test:**
1. BGP-routes propageras korrekt mellan alla sites
2. Failover: stoppa PE1, verifiera trafik via PE2
3. VRRP: stoppa haproxy-1, verifiera VIP flyttar till haproxy-2
4. End-to-end: Branch A/B → DC services

---

## 10. Fas 1: Provider Core - Konfigurationsguide

### 10.1 Översikt

I denna fas konfigurerar vi provider-nätverket med 4 PE-routrar:
- **PE1** och **PE2** är anslutna till DC
- **PE-A** är ansluten till Branch A
- **PE-B** är ansluten till Branch B

Alla PE-routrar kör:
- **OSPF** för intern routing (IGP)
- **iBGP full mesh** för att utbyta kundprefix

### 10.2 GNS3 Setup för Fas 1

**Skapa följande i GNS3:**

1. Dra in 4 st Cisco IOSv-routrar
2. Namnge dem: PE1, PE2, PE-A, PE-B
3. Koppla enligt schemat nedan:

```
PE1 Gi0/1 ────────────────── PE2 Gi0/1
PE1 Gi0/2 ────────────────── PE-A Gi0/1
PE2 Gi0/2 ────────────────── PE-B Gi0/1
```

### 10.3 PE1 Konfiguration

```
!========================================
! PE1 - Provider Edge Router 1
! Ansluten till: CE-DC, PE2, PE-A
!========================================

enable
configure terminal

hostname PE1

! Loopback för Router-ID och iBGP
interface Loopback0
 ip address 2.2.2.1 255.255.255.255
 no shutdown

! Länk till CE-DC (konfigureras i Fas 2)
interface GigabitEthernet0/0
 description Link to CE-DC (ACTIVE)
 ip address 192.168.100.2 255.255.255.252
 no shutdown

! Länk till PE2
interface GigabitEthernet0/1
 description Link to PE2
 ip address 10.255.0.1 255.255.255.252
 no shutdown

! Länk till PE-A
interface GigabitEthernet0/2
 description Link to PE-A
 ip address 10.255.0.5 255.255.255.252
 no shutdown

! OSPF - IGP för provider core
router ospf 1
 router-id 2.2.2.1
 passive-interface default
 no passive-interface GigabitEthernet0/1
 no passive-interface GigabitEthernet0/2
 network 2.2.2.1 0.0.0.0 area 0
 network 10.255.0.0 0.0.0.3 area 0
 network 10.255.0.4 0.0.0.3 area 0

! BGP - iBGP full mesh
router bgp 65001
 bgp router-id 2.2.2.1
 bgp log-neighbor-changes
 
 ! iBGP till PE2
 neighbor 2.2.2.2 remote-as 65001
 neighbor 2.2.2.2 update-source Loopback0
 neighbor 2.2.2.2 next-hop-self
 
 ! iBGP till PE-A
 neighbor 2.2.2.10 remote-as 65001
 neighbor 2.2.2.10 update-source Loopback0
 neighbor 2.2.2.10 next-hop-self
 
 ! iBGP till PE-B
 neighbor 2.2.2.11 remote-as 65001
 neighbor 2.2.2.11 update-source Loopback0
 neighbor 2.2.2.11 next-hop-self

end
write memory
```

### 10.4 PE2 Konfiguration

```
!========================================
! PE2 - Provider Edge Router 2
! Ansluten till: CE-DC, PE1, PE-B
!========================================

enable
configure terminal

hostname PE2

! Loopback för Router-ID och iBGP
interface Loopback0
 ip address 2.2.2.2 255.255.255.255
 no shutdown

! Länk till CE-DC (konfigureras i Fas 2)
interface GigabitEthernet0/0
 description Link to CE-DC (STANDBY)
 ip address 192.168.100.6 255.255.255.252
 no shutdown

! Länk till PE1
interface GigabitEthernet0/1
 description Link to PE1
 ip address 10.255.0.2 255.255.255.252
 no shutdown

! Länk till PE-B
interface GigabitEthernet0/2
 description Link to PE-B
 ip address 10.255.0.9 255.255.255.252
 no shutdown

! OSPF - IGP för provider core
router ospf 1
 router-id 2.2.2.2
 passive-interface default
 no passive-interface GigabitEthernet0/1
 no passive-interface GigabitEthernet0/2
 network 2.2.2.2 0.0.0.0 area 0
 network 10.255.0.0 0.0.0.3 area 0
 network 10.255.0.8 0.0.0.3 area 0

! BGP - iBGP full mesh
router bgp 65001
 bgp router-id 2.2.2.2
 bgp log-neighbor-changes
 
 ! iBGP till PE1
 neighbor 2.2.2.1 remote-as 65001
 neighbor 2.2.2.1 update-source Loopback0
 neighbor 2.2.2.1 next-hop-self
 
 ! iBGP till PE-A
 neighbor 2.2.2.10 remote-as 65001
 neighbor 2.2.2.10 update-source Loopback0
 neighbor 2.2.2.10 next-hop-self
 
 ! iBGP till PE-B
 neighbor 2.2.2.11 remote-as 65001
 neighbor 2.2.2.11 update-source Loopback0
 neighbor 2.2.2.11 next-hop-self

end
write memory
```

### 10.5 PE-A Konfiguration

```
!========================================
! PE-A - Provider Edge Router for Branch A
! Ansluten till: CE-A, PE1
!========================================

enable
configure terminal

hostname PE-A

! Loopback för Router-ID och iBGP
interface Loopback0
 ip address 2.2.2.10 255.255.255.255
 no shutdown

! Länk till CE-A (konfigureras i Fas 2)
interface GigabitEthernet0/0
 description Link to CE-A
 ip address 192.168.101.2 255.255.255.252
 no shutdown

! Länk till PE1
interface GigabitEthernet0/1
 description Link to PE1
 ip address 10.255.0.6 255.255.255.252
 no shutdown

! OSPF - IGP för provider core
router ospf 1
 router-id 2.2.2.10
 passive-interface default
 no passive-interface GigabitEthernet0/1
 network 2.2.2.10 0.0.0.0 area 0
 network 10.255.0.4 0.0.0.3 area 0

! BGP - iBGP full mesh
router bgp 65001
 bgp router-id 2.2.2.10
 bgp log-neighbor-changes
 
 ! iBGP till PE1
 neighbor 2.2.2.1 remote-as 65001
 neighbor 2.2.2.1 update-source Loopback0
 neighbor 2.2.2.1 next-hop-self
 
 ! iBGP till PE2
 neighbor 2.2.2.2 remote-as 65001
 neighbor 2.2.2.2 update-source Loopback0
 neighbor 2.2.2.2 next-hop-self
 
 ! iBGP till PE-B
 neighbor 2.2.2.11 remote-as 65001
 neighbor 2.2.2.11 update-source Loopback0
 neighbor 2.2.2.11 next-hop-self

end
write memory
```

### 10.6 PE-B Konfiguration

```
!========================================
! PE-B - Provider Edge Router for Branch B
! Ansluten till: CE-B, PE2
!========================================

enable
configure terminal

hostname PE-B

! Loopback för Router-ID och iBGP
interface Loopback0
 ip address 2.2.2.11 255.255.255.255
 no shutdown

! Länk till CE-B (konfigureras i Fas 2)
interface GigabitEthernet0/0
 description Link to CE-B
 ip address 192.168.102.2 255.255.255.252
 no shutdown

! Länk till PE2
interface GigabitEthernet0/1
 description Link to PE2
 ip address 10.255.0.10 255.255.255.252
 no shutdown

! OSPF - IGP för provider core
router ospf 1
 router-id 2.2.2.11
 passive-interface default
 no passive-interface GigabitEthernet0/1
 network 2.2.2.11 0.0.0.0 area 0
 network 10.255.0.8 0.0.0.3 area 0

! BGP - iBGP full mesh
router bgp 65001
 bgp router-id 2.2.2.11
 bgp log-neighbor-changes
 
 ! iBGP till PE1
 neighbor 2.2.2.1 remote-as 65001
 neighbor 2.2.2.1 update-source Loopback0
 neighbor 2.2.2.1 next-hop-self
 
 ! iBGP till PE2
 neighbor 2.2.2.2 remote-as 65001
 neighbor 2.2.2.2 update-source Loopback0
 neighbor 2.2.2.2 next-hop-self
 
 ! iBGP till PE-A
 neighbor 2.2.2.10 remote-as 65001
 neighbor 2.2.2.10 update-source Loopback0
 neighbor 2.2.2.10 next-hop-self

end
write memory
```

### 10.7 Verifieringskommandon för Fas 1

Kör dessa på **alla PE-routrar** efter konfiguration:

```
!--- Verifiera OSPF ---
show ip ospf neighbor
! Förväntat: FULL adjacency med grannar

show ip ospf interface brief
! Förväntat: Interfaces i Area 0

show ip route ospf
! Förväntat: Routes till alla loopbacks via OSPF

!--- Verifiera BGP ---
show ip bgp summary
! Förväntat: Alla iBGP neighbors i "Established" state

show ip bgp
! Förväntat: (tomt än så länge - inga kundprefix ännu)

!--- Verifiera konnektivitet ---
ping 2.2.2.1 source Loopback0    ! PE1
ping 2.2.2.2 source Loopback0    ! PE2
ping 2.2.2.10 source Loopback0   ! PE-A
ping 2.2.2.11 source Loopback0   ! PE-B
! Förväntat: Alla svarar
```

### 10.8 Förväntad Output - OSPF Neighbor (PE1)

```
PE1#show ip ospf neighbor

Neighbor ID     Pri   State           Dead Time   Address         Interface
2.2.2.2          1    FULL/DR         00:00:38    10.255.0.2      GigabitEthernet0/1
2.2.2.10         1    FULL/DR         00:00:33    10.255.0.6      GigabitEthernet0/2
```

### 10.9 Förväntad Output - BGP Summary (PE1)

```
PE1#show ip bgp summary

Neighbor        V    AS MsgRcvd MsgSent   TblVer  InQ OutQ Up/Down  State/PfxRcd
2.2.2.2         4 65001      10      12        1    0    0 00:05:23        0
2.2.2.10        4 65001       8      10        1    0    0 00:04:15        0
2.2.2.11        4 65001       7       9        1    0    0 00:03:45        0
```

### 10.10 Felsökning Fas 1

**Problem: OSPF neighbor kommer inte upp**

```
! Kontrollera interface status
show ip interface brief

! Kontrollera OSPF på interface
show ip ospf interface GigabitEthernet0/1

! Kontrollera att OSPF network statements är korrekta
show run | section ospf
```

**Problem: BGP session stuck in "Active"**

```
! Kontrollera att loopback är pingbar
ping X.X.X.X source Loopback0

! Kontrollera BGP neighbor config
show run | section bgp

! Debug (använd försiktigt!)
debug ip bgp
```

---

## Nästa steg

När Fas 1 är verifierad, fortsätt med:

**Fas 2:** Lägg till CE-routrar (CE-DC, CE-A, CE-B) och L2-switchar. Konfigurera eBGP mellan CE och PE.

---
## 11. Fas 2: Customer Edge + L2 Switchar

### 11.2 Nya enheter i Fas 2

| Enhet | Typ | Image | RAM | Anslutning |
|-------|-----|-------|-----|------------|
| CE-DC | Router | Arista vEOS | 2048 MB | PE1, PE2, MGMT-SW, SERVICES-SW |
| CE-A | Router | Cisco IOSv 15.9 | 512 MB | PE-A, LAN-SW-A |
| CE-B | Router | Cisco IOSv 15.9 | 512 MB | PE-B, LAN-SW-B |
| MGMT-SW | Switch | Cisco IOSvL2 15.2 | 512 MB | CE-DC Eth1 |
| SERVICES-SW | Switch | Cisco IOSvL2 15.2 | 512 MB | CE-DC Eth2 |
| NAT-SW | Switch | Cisco IOSvL2 15.2 | 512 MB | NAT Cloud |
| LAN-SW-A | Switch | GNS3 Ethernet Switch | 0 MB | CE-A Gi0/1 |
| LAN-SW-B | Switch | GNS3 Ethernet Switch | 0 MB | CE-B Gi0/1 |

**Resurskrav:**
- Totalt RAM Fas 2: ~6 GB
- Totalt projekt (inkl. Fas 1): ~8 GB

### 11.3 GNS3 Kopplingar för Fas 2
```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         FAS 2 KOPPLINGAR                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  CE-DC (Arista vEOS):                                                       │
│  ├── Eth1 ─────────────→ MGMT-SW Gi0/0                                      │
│  ├── Eth2 ─────────────→ SERVICES-SW Gi0/0                                  │
│  ├── Eth3 ─────────────→ PE1 Gi0/0                                          │
│  └── Eth4 ─────────────→ PE2 Gi0/0                                          │
│                                                                             │
│  CE-A (Cisco IOSv):                                                         │
│  ├── Gi0/0 ────────────→ PE-A Gi0/0                                         │
│  └── Gi0/1 ────────────→ LAN-SW-A Port 1                                    │
│                                                                             │
│  CE-B (Cisco IOSv):                                                         │
│  ├── Gi0/0 ────────────→ PE-B Gi0/0                                         │
│  └── Gi0/1 ────────────→ LAN-SW-B Port 1                                    │
│                                                                             │
│  NAT-SW (Cisco IOSvL2):                                                     │
│  └── Gi0/0 ────────────→ NAT Cloud                                          │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 12. PE-routrar - Uppdatering för eBGP

Innan vi konfigurerar CE-routrarna behöver vi lägga till eBGP-neighbors på PE-routrarna för att de ska svara på anropen.

### 12.1 PE1 - Lägg till eBGP mot CE-DC
```
! PE1 - Lägg till eBGP neighbor mot CE-DC
!========================================
configure terminal

! Prefix-list för vad vi accepterar från CE-DC
ip prefix-list FROM-DC seq 10 permit 10.0.0.0/24
ip prefix-list FROM-DC seq 20 permit 10.10.0.0/24
ip prefix-list FROM-DC seq 1000 deny 0.0.0.0/0 le 32

router bgp 65001
 ! eBGP till CE-DC
 neighbor 192.168.100.1 remote-as 65000
 neighbor 192.168.100.1 description CE-DC-PRIMARY
 neighbor 192.168.100.1 prefix-list FROM-DC in
 neighbor 192.168.100.1 maximum-prefix 100 80 warning-only

end
write memory
```

### 12.2 PE2 - Lägg till eBGP mot CE-DC
```
! PE2 - Lägg till eBGP neighbor mot CE-DC
!========================================
configure terminal

! Prefix-list för vad vi accepterar från CE-DC
ip prefix-list FROM-DC seq 10 permit 10.0.0.0/24
ip prefix-list FROM-DC seq 20 permit 10.10.0.0/24
ip prefix-list FROM-DC seq 1000 deny 0.0.0.0/0 le 32

router bgp 65001
 ! eBGP till CE-DC
 neighbor 192.168.100.5 remote-as 65000
 neighbor 192.168.100.5 description CE-DC-SECONDARY
 neighbor 192.168.100.5 prefix-list FROM-DC in
 neighbor 192.168.100.5 maximum-prefix 100 80 warning-only

end
write memory
```

### 12.3 PE-A - Lägg till eBGP mot CE-A
```
! PE-A - Lägg till eBGP neighbor mot CE-A
!========================================
configure terminal

! Prefix-list för vad vi accepterar från CE-A
ip prefix-list FROM-BRANCH-A seq 10 permit 10.20.1.0/24
ip prefix-list FROM-BRANCH-A seq 1000 deny 0.0.0.0/0 le 32

router bgp 65001
 ! eBGP till CE-A
 neighbor 192.168.101.1 remote-as 65000
 neighbor 192.168.101.1 description CE-A
 neighbor 192.168.101.1 prefix-list FROM-BRANCH-A in
 neighbor 192.168.101.1 maximum-prefix 50 80 warning-only

end
write memory
```

### 12.4 PE-B - Lägg till eBGP mot CE-B
```
! PE-B - Lägg till eBGP neighbor mot CE-B
!========================================
configure terminal

! Prefix-list för vad vi accepterar från CE-B
ip prefix-list FROM-BRANCH-B seq 10 permit 10.20.2.0/24
ip prefix-list FROM-BRANCH-B seq 1000 deny 0.0.0.0/0 le 32

router bgp 65001
 ! eBGP till CE-B
 neighbor 192.168.102.1 remote-as 65000
 neighbor 192.168.102.1 description CE-B
 neighbor 192.168.102.1 prefix-list FROM-BRANCH-B in
 neighbor 192.168.102.1 maximum-prefix 50 80 warning-only

end
write memory
```

---

## 13. CE-DC (Arista vEOS) Konfiguration

### 13.1 Arista-specifika kommandon

Arista vEOS liknar Cisco IOS men har några viktiga skillnader:

- `ip routing` måste aktiveras globalt
- VRF skapas med `vrf instance` (inte `ip vrf`)
- Interfaces måste ha `no switchport` för att fungera som L3-interface
- **VIKTIGT:** Prefix-lists och route-maps måste konfigureras INUTI `address-family ipv4` blocket (inte på neighbor-nivå utanför)
- VRF-routing måste aktiveras explicit med `ip routing vrf <name>`

**Initial inloggning:**

1. Logga in med användare: `admin`
2. Om ZeroTouch startar, kör: `zerotouch cancel`
3. Vänta på omstart, logga in igen med `admin`

### 13.2 CE-DC Fullständig Konfiguration (VERIFIED WORKING)
```
!========================================
! CE-DC - Arista vEOS Configuration
! Lab 3 - Grupp 2 SN24
! Fas 2 - Verified Working
!========================================

! === GRUNDLÄGGANDE ===
hostname CE-DC
ip routing

! === VRF INSTANCES ===
vrf instance MGMT
vrf instance SERVICES

! === AKTIVERA ROUTING I VRFs ===
ip routing vrf MGMT
ip routing vrf SERVICES

! === LOOPBACK ===
interface Loopback0
   ip address 1.1.1.1/32

! === MGMT INTERFACE (VRF MGMT) ===
interface Ethernet1
   description MGMT-SW
   no switchport
   vrf MGMT
   ip address 10.0.0.1/24
   no shutdown

! === SERVICES INTERFACE (VRF SERVICES) ===
interface Ethernet2
   description SERVICES-SW
   no switchport
   vrf SERVICES
   ip address 10.10.0.1/24
   no shutdown

! === WAN TILL PE1 (PRIMARY) ===
interface Ethernet3
   description PE1-PRIMARY
   no switchport
   ip address 192.168.100.1/30
   no shutdown

! === WAN TILL PE2 (SECONDARY) ===
interface Ethernet4
   description PE2-SECONDARY
   no switchport
   ip address 192.168.100.5/30
   no shutdown

! === PREFIX-LISTS ===
ip prefix-list ANNOUNCE-TO-PROVIDER seq 10 permit 10.0.0.0/24
ip prefix-list ANNOUNCE-TO-PROVIDER seq 20 permit 10.10.0.0/24
ip prefix-list ACCEPT-FROM-PROVIDER seq 10 permit 10.20.1.0/24
ip prefix-list ACCEPT-FROM-PROVIDER seq 20 permit 10.20.2.0/24

! === ROUTE-MAPS FÖR TRAFFIC ENGINEERING ===
route-map PREFER-PE1 permit 10
   set local-preference 150

route-map PREFER-PE2 permit 10
   set local-preference 100

route-map SET-COMMUNITY-PE1 permit 10
   set community 65000:110

route-map SET-COMMUNITY-PE2 permit 10
   set community 65000:120

! === STATISKA ROUTES FÖR BGP ANNOUNCEMENT ===
ip route 10.0.0.0/24 Null0
ip route 10.10.0.0/24 Null0

! === BGP KONFIGURATION ===
! OBS: Prefix-lists och route-maps MÅSTE vara i address-family blocket på Arista!
router bgp 65000
   router-id 1.1.1.1
   maximum-paths 2
   
   neighbor 192.168.100.2 remote-as 65001
   neighbor 192.168.100.2 description PE1-PRIMARY
   neighbor 192.168.100.2 send-community
   neighbor 192.168.100.2 maximum-routes 100 warning-only
   
   neighbor 192.168.100.6 remote-as 65001
   neighbor 192.168.100.6 description PE2-SECONDARY
   neighbor 192.168.100.6 send-community
   neighbor 192.168.100.6 maximum-routes 100 warning-only
   
   address-family ipv4
      neighbor 192.168.100.2 activate
      neighbor 192.168.100.2 prefix-list ACCEPT-FROM-PROVIDER in
      neighbor 192.168.100.2 prefix-list ANNOUNCE-TO-PROVIDER out
      neighbor 192.168.100.2 route-map PREFER-PE1 in
      neighbor 192.168.100.2 route-map SET-COMMUNITY-PE1 out
      
      neighbor 192.168.100.6 activate
      neighbor 192.168.100.6 prefix-list ACCEPT-FROM-PROVIDER in
      neighbor 192.168.100.6 prefix-list ANNOUNCE-TO-PROVIDER out
      neighbor 192.168.100.6 route-map PREFER-PE2 in
      neighbor 192.168.100.6 route-map SET-COMMUNITY-PE2 out
      
      network 10.0.0.0/24
      network 10.10.0.0/24

! === SPARA ===
end
write
```

### 13.3 Verifiering
```
show ip interface brief
show ip bgp summary
show ip route vrf MGMT
show ip route vrf SERVICES
```

**Förväntat resultat:**
- Ethernet1-4: Ska ha korrekta IP-adresser och status `UP`
- BGP Summary: Två neighbors ska synas med status `Estab` (Established)
- VRF MGMT: Visar 10.0.0.0/24 connected
- VRF SERVICES: Visar 10.10.0.0/24 connected

---

## 14. CE-A (Cisco IOSv) Konfiguration

### 14.1 CE-A Fullständig Konfiguration (VERIFIED WORKING)
```
!========================================
! CE-A - Cisco IOSv
! Branch A Customer Edge Router
! Single-homed till PE-A
! INKLUDERAR allowas-in FIX
!========================================

enable
configure terminal

hostname CE-A

!----------------------------------------
! Loopback interface
!----------------------------------------
interface Loopback0
 ip address 1.1.1.10 255.255.255.255

!----------------------------------------
! WAN-interface till PE-A
!----------------------------------------
interface GigabitEthernet0/0
 description Link to PE-A
 ip address 192.168.101.1 255.255.255.252
 no shutdown

!----------------------------------------
! LAN-interface till användare
!----------------------------------------
interface GigabitEthernet0/1
 description LAN Branch A (USER VRF)
 ip address 10.20.1.1 255.255.255.0
 no shutdown

!----------------------------------------
! Prefix-lists
!----------------------------------------
! Vad vi annonserar UT
ip prefix-list ANNOUNCE-OUT seq 10 permit 10.20.1.0/24
ip prefix-list ANNOUNCE-OUT seq 1000 deny 0.0.0.0/0 le 32

! Vad vi accepterar IN
ip prefix-list ACCEPT-IN seq 10 permit 10.0.0.0/24
ip prefix-list ACCEPT-IN seq 20 permit 10.10.0.0/24
ip prefix-list ACCEPT-IN seq 30 permit 10.20.2.0/24
ip prefix-list ACCEPT-IN seq 1000 deny 0.0.0.0/0 le 32

!----------------------------------------
! BGP Konfiguration
!----------------------------------------
router bgp 65000
 bgp router-id 1.1.1.10
 bgp log-neighbor-changes
 
 ! eBGP mot PE-A
 neighbor 192.168.101.2 remote-as 65001
 neighbor 192.168.101.2 description PE-A
 neighbor 192.168.101.2 prefix-list ACCEPT-IN in
 neighbor 192.168.101.2 prefix-list ANNOUNCE-OUT out
 neighbor 192.168.101.2 maximum-prefix 100 80 warning-only
 !
 ! KRITISKT: allowas-in behövs för att ta emot routes från DC
 ! (DC har samma AS 65000, BGP ser det som loop utan detta)
 neighbor 192.168.101.2 allowas-in 2
 neighbor 192.168.101.2 soft-reconfiguration inbound
 
 ! Annonsera vårt LAN
 network 10.20.1.0 mask 255.255.255.0

!----------------------------------------
! Statisk route för aggregat
!----------------------------------------
ip route 10.20.1.0 255.255.255.0 Null0

end
write memory
```

### 14.2 CE-A Verifiering
```
show ip interface brief
show ip bgp summary
show ip bgp
```

**Förväntat resultat:**
- Gi0/0 och Gi0/1: up/up
- BGP neighbor 192.168.101.2: Established, PfxRcd = 3
- BGP table: 10.0.0.0/24, 10.10.0.0/24, 10.20.1.0/24 (lokalt), 10.20.2.0/24

---

## 15. CE-B (Cisco IOSv) Konfiguration

### 15.1 CE-B Fullständig Konfiguration (VERIFIED WORKING)
```
!========================================
! CE-B - Cisco IOSv
! Branch B Customer Edge Router
! Single-homed till PE-B
! INKLUDERAR allowas-in FIX
!========================================

enable
configure terminal

hostname CE-B

!----------------------------------------
! Loopback interface
!----------------------------------------
interface Loopback0
 ip address 1.1.1.11 255.255.255.255

!----------------------------------------
! WAN-interface till PE-B
!----------------------------------------
interface GigabitEthernet0/0
 description Link to PE-B
 ip address 192.168.102.1 255.255.255.252
 no shutdown

!----------------------------------------
! LAN-interface till användare
!----------------------------------------
interface GigabitEthernet0/1
 description LAN Branch B (USER VRF)
 ip address 10.20.2.1 255.255.255.0
 no shutdown

!----------------------------------------
! Prefix-lists
!----------------------------------------
! Vad vi annonserar UT
ip prefix-list ANNOUNCE-OUT seq 10 permit 10.20.2.0/24
ip prefix-list ANNOUNCE-OUT seq 1000 deny 0.0.0.0/0 le 32

! Vad vi accepterar IN
ip prefix-list ACCEPT-IN seq 10 permit 10.0.0.0/24
ip prefix-list ACCEPT-IN seq 20 permit 10.10.0.0/24
ip prefix-list ACCEPT-IN seq 30 permit 10.20.1.0/24
ip prefix-list ACCEPT-IN seq 1000 deny 0.0.0.0/0 le 32

!----------------------------------------
! BGP Konfiguration
!----------------------------------------
router bgp 65000
 bgp router-id 1.1.1.11
 bgp log-neighbor-changes
 
 ! eBGP mot PE-B
 neighbor 192.168.102.2 remote-as 65001
 neighbor 192.168.102.2 description PE-B
 neighbor 192.168.102.2 prefix-list ACCEPT-IN in
 neighbor 192.168.102.2 prefix-list ANNOUNCE-OUT out
 neighbor 192.168.102.2 maximum-prefix 100 80 warning-only
 !
 ! KRITISKT: allowas-in behövs för att ta emot routes från DC
 ! (DC har samma AS 65000, BGP ser det som loop utan detta)
 neighbor 192.168.102.2 allowas-in 2
 neighbor 192.168.102.2 soft-reconfiguration inbound
 
 ! Annonsera vårt LAN
 network 10.20.2.0 mask 255.255.255.0

!----------------------------------------
! Statisk route för aggregat
!----------------------------------------
ip route 10.20.2.0 255.255.255.0 Null0

end
write memory
```

### 15.2 CE-B Verifiering
```
show ip interface brief
show ip bgp summary
show ip bgp
```

**Förväntat resultat:**
- Gi0/0 och Gi0/1: up/up
- BGP neighbor 192.168.102.2: Established, PfxRcd = 3
- BGP table: 10.0.0.0/24, 10.10.0.0/24, 10.20.1.0/24, 10.20.2.0/24 (lokalt)

---

## 16. L2 Switchar Konfiguration

### 16.1 MGMT-SW (Cisco IOSvL2)
```
!========================================
! MGMT-SW - Cisco IOSvL2
! Management Network Switch
!========================================

enable
configure terminal

hostname MGMT-SW

! Alla portar i VLAN 1 som default
! Koppla servrar till lediga portar
interface range GigabitEthernet0/0 - 3
 description Management Network
 switchport mode access
 switchport access vlan 1
 no shutdown

end
write memory
```

### 16.2 SERVICES-SW (Cisco IOSvL2)
```
!========================================
! SERVICES-SW - Cisco IOSvL2
! Services Network Switch
!========================================

enable
configure terminal

hostname SERVICES-SW

! Alla portar i VLAN 1 som default
! Koppla servrar till lediga portar
interface range GigabitEthernet0/0 - 3
 description Services Network
 switchport mode access
 switchport access vlan 1
 no shutdown

end
write memory
```

### 16.3 NAT-SW (Cisco IOSvL2)
```
!========================================
! NAT-SW - Cisco IOSvL2
! NAT Cloud Access Switch
!========================================

enable
configure terminal

hostname NAT-SW

! Gi0/0 till NAT Cloud
! Övriga portar för servrar som behöver internet
interface range GigabitEthernet0/0 - 3
 description NAT Network
 switchport mode access
 switchport access vlan 1
 no shutdown

end
write memory
```

### 16.4 LAN-SW-A och LAN-SW-B

Dessa är **GNS3 Ethernet Switches** (inte Cisco IOSvL2), så de kräver ingen konfiguration. De fungerar som enkla L2-switchar out-of-the-box.

---

## 17. Fas 2 Slutlig Verifiering

### 17.1 Checklista

| Check | Kommando | Förväntat |
|-------|----------|-----------|
| CE-DC ↔ PE1 eBGP | `show ip bgp summary` på CE-DC | Estab, 2 prefixes |
| CE-DC ↔ PE2 eBGP | `show ip bgp summary` på CE-DC | Estab, 2 prefixes |
| CE-A ↔ PE-A eBGP | `show ip bgp summary` på CE-A | Estab, PfxRcd=3 |
| CE-B ↔ PE-B eBGP | `show ip bgp summary` på CE-B | Estab, PfxRcd=3 |
| VRF MGMT routing | `show ip route vrf MGMT` på CE-DC | 10.0.0.0/24 connected |
| VRF SERVICES routing | `show ip route vrf SERVICES` på CE-DC | 10.10.0.0/24 connected |

### 17.2 End-to-End Connectivity Test

Från CE-A:
```
ping 10.10.0.1 source 10.20.1.1
```

Från CE-B:
```
ping 10.10.0.1 source 10.20.2.1
```

### 17.3 Viktiga lärdomar från Fas 2

1. **Arista EOS syntax:** Prefix-lists och route-maps måste vara i `address-family ipv4` blocket
2. **VRF routing:** Måste aktiveras explicit med `ip routing vrf <name>` på Arista
3. **allowas-in:** Krävs när flera sites har samma AS-nummer och kommunicerar via provider (förhindrar false loop detection)


## 18. Fas 3: Puppet Infrastructure (Korrigerad version)

### 18.1 Översikt

Denna fas installerar Puppet-infrastrukturen i MGMT VRF:

| Server | IP | RAM | Roll |
|--------|-----|-----|------|
| puppet-master-1 | 10.0.0.10 | 2048 MB | Puppet Server + Foreman |
| puppet-master-2 | 10.0.0.11 | 2048 MB | Puppet Server (sekundär) |
| puppetdb | 10.0.0.12 | 1024 MB | PuppetDB + PostgreSQL |

### 18.2 GNS3 Kopplingar

Alla tre servrar kopplas till MGMT-SW:

| Server | NIC 1 (ens4) | NIC 2 (ens5) |
|--------|--------------|--------------|
| puppet-master-1 | MGMT-SW Gi0/1 | NAT Cloud |
| puppet-master-2 | MGMT-SW Gi0/2 | NAT Cloud |
| puppetdb | MGMT-SW Gi0/3 | NAT Cloud |

**Viktigt:** Alla Debian 12-servrar använder `ens4` och `ens5` som interface-namn.

---

## 19. Del 1: puppet-master-1 (Puppet Server + Foreman)

### 19.1 Steg 1: Skapa VM i GNS3

- Template: Debian 12.6
- RAM: 2048 MB
- Disk: 20 GB
- NICs: 2 st (ens4 → MGMT-SW, ens5 → NAT)

### 19.2 Steg 2: Grundkonfiguration
```bash
# Logga in som root

# 1. Sätt hostname
hostnamectl set-hostname puppet-master-1

# 2. Sätt timezone
timedatectl set-timezone Europe/Stockholm

# 3. Konfigurera /etc/hosts (VIKTIGT: FQDN först, INGEN 127.0.1.1-rad!)
cat > /etc/hosts << 'EOF'
127.0.0.1 localhost

# Puppet Infrastructure
10.0.0.10 puppet-master-1.lab3.local puppet-master-1 puppet
10.0.0.11 puppet-master-2.lab3.local puppet-master-2
10.0.0.12 puppetdb.lab3.local puppetdb

# CE-DC Gateway
10.0.0.1 ce-dc-mgmt
EOF

# 4. Verifiera hostname
hostname -f
# Måste visa: puppet-master-1.lab3.local
```

### 19.3 Steg 3: Konfigurera nätverk
```bash
cat > /etc/network/interfaces << 'EOF'
auto lo
iface lo inet loopback

# MGMT Network (ingen gateway - intern trafik)
auto ens4
iface ens4 inet static
    address 10.0.0.10
    netmask 255.255.255.0

# NAT Network (DHCP ger default gateway för internet)
auto ens5
iface ens5 inet dhcp
EOF

# Starta om nätverk
systemctl restart networking

# Verifiera
ip addr show ens4
ip addr show ens5
ping -c 2 8.8.8.8
```

**Om du gjorde större disk på Debian (som jag visade på discord):**
```bash
apt install -y cloud-guest-utils
growpart /dev/sda 1
resize2fs /dev/sda1
```

### 19.4 Steg 4: Installera beroenden
```bash
# Uppdatera system
apt update && apt upgrade -y

# Installera nödvändiga paket (inkl. cron!)
apt install -y wget curl gnupg2 apt-transport-https ca-certificates \
    lsb-release cron postgresql postgresql-contrib

# Starta och aktivera tjänster
systemctl enable --now cron
systemctl enable --now postgresql
```

### 19.5 Steg 5: Installera Puppet Server
```bash
# Lägg till Puppet 8 repository
wget https://apt.puppet.com/puppet8-release-bookworm.deb
dpkg -i puppet8-release-bookworm.deb
apt update

# Installera Puppet Server
apt install -y puppetserver puppet-agent

# Konfigurera Puppet Server
cat > /etc/puppetlabs/puppet/puppet.conf << 'EOF'
[main]
server = puppet-master-1.lab3.local
certname = puppet-master-1.lab3.local
dns_alt_names = puppet,puppet-master-1,puppet-master-1.lab3.local,puppet-master-2,puppet-master-2.lab3.local

[server]
vardir = /opt/puppetlabs/server/data/puppetserver
logdir = /var/log/puppetlabs/puppetserver
rundir = /var/run/puppetlabs/puppetserver
pidfile = /var/run/puppetlabs/puppetserver/puppetserver.pid
codedir = /etc/puppetlabs/code
ca = true
ca_server = puppet-master-1.lab3.local
EOF

# Autosign för lab-miljö
echo '*.lab3.local' > /etc/puppetlabs/puppet/autosign.conf
chmod 644 /etc/puppetlabs/puppet/autosign.conf

# Justera minne (2GB RAM server)
sed -i 's/Xms2g/Xms1g/g' /etc/default/puppetserver
sed -i 's/Xmx2g/Xmx1g/g' /etc/default/puppetserver

# Starta Puppet Server och generera CA
systemctl enable puppetserver
systemctl start puppetserver

# Vänta tills CA är redo (kan ta 1-2 min)
sleep 60

# Verifiera att certifikat skapades
ls -la /etc/puppetlabs/puppet/ssl/certs/
```

### 19.6 Steg 6: Skapa PostgreSQL-databas för Foreman
```bash
sudo -u postgres psql << 'EOF'
CREATE USER foreman WITH PASSWORD 'foreman';
CREATE DATABASE foreman OWNER foreman;
GRANT ALL PRIVILEGES ON DATABASE foreman TO foreman;
\q
EOF
```

### 19.7 Steg 7: Installera Foreman
```bash
# Lägg till Foreman repository (version 3.17)
wget -q https://deb.theforeman.org/foreman.asc -O /etc/apt/trusted.gpg.d/foreman.asc

cat > /etc/apt/sources.list.d/foreman.list << 'EOF'
deb http://deb.theforeman.org/ bookworm 3.17
deb http://deb.theforeman.org/ plugins 3.17
EOF

apt update

# Installera Foreman och plugins
apt install -y foreman-installer foreman-postgresql
```

### 19.8 Steg 8: Kör Foreman Installer
```bash
foreman-installer \
    --foreman-initial-admin-username admin \
    --foreman-initial-admin-password 'Labpass123!' \
    --puppet-server-foreman-ssl-ca /etc/puppetlabs/puppet/ssl/certs/ca.pem \
    --puppet-server-foreman-ssl-cert /etc/puppetlabs/puppet/ssl/certs/puppet-master-1.lab3.local.pem \
    --puppet-server-foreman-ssl-key /etc/puppetlabs/puppet/ssl/private_keys/puppet-master-1.lab3.local.pem \
    --enable-foreman-plugin-puppetdb \
    --enable-puppet
```

### 19.9 Steg 9: Verifiera installation
```bash
# Kolla tjänster
systemctl status puppetserver
systemctl status apache2
systemctl status postgresql

# Kolla att portar lyssnar
ss -tlnp | grep -E '443|8140|8443'

# Testa Puppet lokalt
/opt/puppetlabs/bin/puppet agent --test

# Foreman ska vara tillgänglig på:
# https://puppet-master-1.lab3.local
# Credentials: admin / Labpass123!
```

##På MGMT-SW,
```bash
enable
conf t
hostname MGMT-SW

! Sätt alla interface i samma VLAN och aktivera dem
interface range GigabitEthernet0/0 - 3
 switchport mode access
 switchport access vlan 1
 no shutdown
 spanning-tree portfast
 exit

! Kontrollera att VLAN 1 är aktivt
interface Vlan1
 no shutdown
 exit

end
write memory

###Verifiera:
show interfaces status
show vlan brief
```

## 20. Del 2: puppetdb (Separat server)

### 20.1 Steg 1: Skapa VM i GNS3

- Template: Debian 12.6
- RAM: 1024 MB
- Disk: 20 GB
- NICs: 2 st (ens4 → MGMT-SW Gi0/3, ens5 → NAT)

### 20.2 Steg 2: Grundkonfiguration
```bash
# Logga in som root

# 1. Sätt hostname
hostnamectl set-hostname puppetdb

# 2. Sätt timezone
timedatectl set-timezone Europe/Stockholm

# 3. Konfigurera /etc/hosts
cat > /etc/hosts << 'EOF'
127.0.0.1       localhost

# Puppet Infrastructure
10.0.0.10       puppet-master-1.lab3.local puppet-master-1 puppet
10.0.0.11       puppet-master-2.lab3.local puppet-master-2
10.0.0.12       puppetdb.lab3.local puppetdb

# CE-DC Gateway
10.0.0.1        ce-dc-mgmt
EOF

# 4. Verifiera
hostname -f
# Måste visa: puppetdb.lab3.local
```

### 20.3 Steg 3: Konfigurera nätverk
```bash
cat > /etc/network/interfaces << 'EOF'
auto lo
iface lo inet loopback

# MGMT Network
auto ens4
iface ens4 inet static
    address 10.0.0.12
    netmask 255.255.255.0

# NAT Network
auto ens5
iface ens5 inet dhcp
EOF

systemctl restart networking

# Verifiera
ping -c 2 10.0.0.10
ping -c 2 8.8.8.8
```

### 20.4 Steg 4: Installera PostgreSQL
```bash
apt update && apt upgrade -y
apt install -y postgresql postgresql-contrib wget curl gnupg2

systemctl enable --now postgresql

# Skapa PuppetDB-databas
sudo -u postgres psql << 'EOF'
CREATE USER puppetdb WITH PASSWORD 'puppetdb';
CREATE DATABASE puppetdb OWNER puppetdb;
\c puppetdb
CREATE EXTENSION pg_trgm;
GRANT ALL PRIVILEGES ON DATABASE puppetdb TO puppetdb;
\q
EOF

# Tillåt anslutningar från puppet-masters
cat >> /etc/postgresql/15/main/pg_hba.conf << 'EOF'

# PuppetDB connections from Puppet masters
host    puppetdb    puppetdb    10.0.0.10/32    scram-sha-256
host    puppetdb    puppetdb    10.0.0.11/32    scram-sha-256
host    puppetdb    puppetdb    10.0.0.12/32    scram-sha-256
EOF

# Lyssna på alla interfaces
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/15/main/postgresql.conf

systemctl restart postgresql
```

### 20.5 Steg 5: Installera PuppetDB
```bash
# Lägg till Puppet repository
wget https://apt.puppet.com/puppet8-release-bookworm.deb
dpkg -i puppet8-release-bookworm.deb
apt update

# Installera PuppetDB och agent
apt install -y puppetdb puppet-agent

# Konfigurera databasanslutning
cat > /etc/puppetlabs/puppetdb/conf.d/database.ini << 'EOF'
[database]
subname = //localhost:5432/puppetdb
username = puppetdb
password = puppetdb
EOF

# Konfigurera PuppetDB
cat > /etc/puppetlabs/puppetdb/conf.d/jetty.ini << 'EOF'
[jetty]
host = 0.0.0.0
port = 8080
ssl-host = 0.0.0.0
ssl-port = 8081
ssl-key = /etc/puppetlabs/puppetdb/ssl/private.pem
ssl-cert = /etc/puppetlabs/puppetdb/ssl/public.pem
ssl-ca-cert = /etc/puppetlabs/puppetdb/ssl/ca.pem
EOF
```

### 20.6 Steg 6: Registrera med Puppet och hämta certifikat
```bash
# Konfigurera Puppet agent
cat > /etc/puppetlabs/puppet/puppet.conf << 'EOF'
[main]
server = puppet-master-1.lab3.local
certname = puppetdb.lab3.local
EOF

# Kör agent för att få certifikat (autosign)
/opt/puppetlabs/bin/puppet agent --test --waitforcert 60

# Kopiera certifikat till PuppetDB
mkdir -p /etc/puppetlabs/puppetdb/ssl
cp /etc/puppetlabs/puppet/ssl/certs/puppetdb.lab3.local.pem /etc/puppetlabs/puppetdb/ssl/public.pem
cp /etc/puppetlabs/puppet/ssl/private_keys/puppetdb.lab3.local.pem /etc/puppetlabs/puppetdb/ssl/private.pem
cp /etc/puppetlabs/puppet/ssl/certs/ca.pem /etc/puppetlabs/puppetdb/ssl/ca.pem

chown -R puppetdb:puppetdb /etc/puppetlabs/puppetdb/ssl
chmod 400 /etc/puppetlabs/puppetdb/ssl/private.pem

# Starta PuppetDB
systemctl enable puppetdb
systemctl start puppetdb

# Verifiera
systemctl status puppetdb
ss -tlnp | grep -E '8080|8081'
```
## 21. Del 3: Konfigurera puppet-master-1 att använda PuppetDB

Tillbaka på puppet-master-1:
```bash
# Installera puppetdb-termini
apt install -y puppetdb-termini

# Konfigurera PuppetDB-anslutning
cat > /etc/puppetlabs/puppet/puppetdb.conf << 'EOF'
[main]
server_urls = https://puppetdb.lab3.local:8081
EOF

# Lägg till route_file och storeconfigs
cat >> /etc/puppetlabs/puppet/puppet.conf << 'EOF'

[server]
storeconfigs = true
storeconfigs_backend = puppetdb
reports = store,puppetdb

[main]
EOF

# Skapa routes.yaml
cat > /etc/puppetlabs/puppet/routes.yaml << 'EOF'
---
server:
  facts:
    terminus: puppetdb
    cache: yaml
EOF

chown puppet:puppet /etc/puppetlabs/puppet/routes.yaml

# Starta om Puppet Server
systemctl restart puppetserver
```

---

## 22. Del 4: puppet-master-2

### 22.1 Steg 1: Skapa VM och grundkonfig (samma som puppet-master-1)
```bash
hostnamectl set-hostname puppet-master-2
timedatectl set-timezone Europe/Stockholm

cat > /etc/hosts << 'EOF'
127.0.0.1       localhost

10.0.0.10       puppet-master-1.lab3.local puppet-master-1 puppet
10.0.0.11       puppet-master-2.lab3.local puppet-master-2
10.0.0.12       puppetdb.lab3.local puppetdb
10.0.0.1        ce-dc-mgmt
EOF

cat > /etc/network/interfaces << 'EOF'
auto lo
iface lo inet loopback

auto ens4
iface ens4 inet static
    address 10.0.0.11
    netmask 255.255.255.0

auto ens5
iface ens5 inet dhcp
EOF

systemctl restart networking
```

### 22.2 Steg 2: Installera Puppet Server (utan CA)
```bash
apt update && apt upgrade -y
apt install -y wget curl gnupg2

wget https://apt.puppet.com/puppet8-release-bookworm.deb
dpkg -i puppet8-release-bookworm.deb
apt update

apt install -y puppetserver puppet-agent puppetdb-termini

# Konfigurera som icke-CA server
cat > /etc/puppetlabs/puppet/puppet.conf << 'EOF'
[main]
server = puppet-master-1.lab3.local
certname = puppet-master-2.lab3.local
ca_server = puppet-master-1.lab3.local

[server]
ca = false
storeconfigs = true
storeconfigs_backend = puppetdb
reports = store,puppetdb
EOF

# PuppetDB-konfig
cat > /etc/puppetlabs/puppet/puppetdb.conf << 'EOF'
[main]
server_urls = https://puppetdb.lab3.local:8081
EOF

cat > /etc/puppetlabs/puppet/routes.yaml << 'EOF'
---
server:
  facts:
    terminus: puppetdb
    cache: yaml
EOF

# Justera minne
sed -i 's/Xms2g/Xms1g/g' /etc/default/puppetserver
sed -i 's/Xmx2g/Xmx1g/g' /etc/default/puppetserver

# Hämta certifikat från CA (puppet-master-1)
/opt/puppetlabs/bin/puppet agent --test --waitforcert 60

# Starta Puppet Server
systemctl enable puppetserver
systemctl start puppetserver
```

---

## 23. Fas 3 Verifiering

### 23.1 På puppet-master-1
```bash
# Kolla alla tjänster
systemctl status puppetserver apache2 postgresql

# Kolla portar
ss -tlnp | grep -E '443|8140|8443'

# Testa PuppetDB-anslutning
curl -s --cacert /etc/puppetlabs/puppet/ssl/certs/ca.pem \
  --cert /etc/puppetlabs/puppet/ssl/certs/puppet-master-1.lab3.local.pem \
  --key /etc/puppetlabs/puppet/ssl/private_keys/puppet-master-1.lab3.local.pem \
  https://puppetdb.lab3.local:8081/pdb/meta/v1/version

# Lista signerade certifikat
/opt/puppetlabs/bin/puppetserver ca list --all
```

### 23.2 Åtkomst till Foreman Web UI

På din dator, lägg till i `/etc/hosts`:
```
<NAT-IP-från-ens5>  puppet-master-1.lab3.local
```

Hitta NAT-IP:n på puppet-master-1:
```bash
ip addr show ens5 | grep inet
```

Sedan öppna: `https://puppet-master-1.lab3.local`

- **Användare:** `admin`
- **Lösenord:** `Labpass123!`


## 24. Fas 4: DC Services

### 24.1 Översikt

Denna fas installerar alla tjänster i SERVICES VRF (10.10.0.0/24):

| Server | IP | RAM | Roll |
|--------|-----|-----|------|
| haproxy-1 | 10.10.0.10 | 512 MB | Load Balancer (VRRP Master) |
| haproxy-2 | 10.10.0.11 | 512 MB | Load Balancer (VRRP Backup) |
| VIP | 10.10.0.9 | - | Virtual IP |
| web-1 | 10.10.0.21 | 512 MB | Apache |
| web-2 | 10.10.0.22 | 512 MB | Apache |
| web-3 | 10.10.0.23 | 512 MB | Apache |
| terminal-1 | 10.10.0.31 | 1024 MB | XRDP |
| terminal-2 | 10.10.0.32 | 1024 MB | XRDP |
| nfs-server | 10.10.0.40 | 512 MB | Delad lagring |
| ssh-bastion | 10.10.0.50 | 512 MB | MFA SSH |
| Gateway | 10.10.0.1 | - | CE-DC |

---

## 25. Inter-VRF Routing Fix - CE-DC (Arista vEOS-lab 4.29.2F)

### 25.1 Problem

Servrar i SERVICES VRF (10.10.0.0/24) kunde inte kommunicera med servrar i MGMT VRF (10.0.0.0/24) på samma router.

### 25.2 Lösning

#### Steg 1: Aktivera multi-agent routing model
```
configure terminal
service routing protocols model multi-agent
end
write memory
reload
```

**OBS:** Kräver reboot för att aktiveras.

#### Steg 2: Skapa route-map för leak policy
```
configure terminal
route-map RM-LEAK-ALL permit 10
```

#### Steg 3: Konfigurera VRF route leaking med router general
```
router general
   vrf MGMT
      leak routes source-vrf SERVICES subscribe-policy RM-LEAK-ALL
   !
   vrf SERVICES
      leak routes source-vrf MGMT subscribe-policy RM-LEAK-ALL

end
write memory
```

#### Steg 4: Verifiera på CE-DC
```
show ip route vrf SERVICES
show ip route vrf MGMT
```

**Förväntat resultat - "L" (Leaked) routes:**

VRF: SERVICES
```
C L   10.0.0.0/24 is directly connected (source VRF MGMT), Ethernet1 (egress VRF MGMT)
C     10.10.0.0/24 is directly connected, Ethernet2
```

VRF: MGMT
```
C     10.0.0.0/24 is directly connected, Ethernet1
C L   10.10.0.0/24 is directly connected (source VRF SERVICES), Ethernet2 (egress VRF SERVICES)
```

---

## 26. Klientkonfiguration - Returvägar

Servrar i varje VRF behöver statiska routes till det andra subnätet.

### 26.1 puppet-master-1 (10.0.0.10 i MGMT VRF)

Uppdatera `/etc/network/interfaces`:
```bash
cat > /etc/network/interfaces << 'EOF'
# Loopback
auto lo
iface lo inet loopback

# MGMT Network (statisk IP, INGEN default gateway här!)
auto ens4
iface ens4 inet static
    address 10.0.0.10
    netmask 255.255.255.0
    up ip route add 10.10.0.0/24 via 10.0.0.1

# NAT Network (DHCP - denna ger oss internet-access)
auto ens5
iface ens5 inet dhcp
EOF

systemctl restart networking
```

### 26.2 puppet-master-2 (10.0.0.11 i MGMT VRF)
```bash
cat > /etc/network/interfaces << 'EOF'
# Loopback
auto lo
iface lo inet loopback

# MGMT Network
auto ens4
iface ens4 inet static
    address 10.0.0.11
    netmask 255.255.255.0
    up ip route add 10.10.0.0/24 via 10.0.0.1

# NAT Network (DHCP)
auto ens5
iface ens5 inet dhcp
EOF

systemctl restart networking
```

### 26.3 puppetdb (10.0.0.12 i MGMT VRF)
```bash
cat > /etc/network/interfaces << 'EOF'
# Loopback
auto lo
iface lo inet loopback

# MGMT Network
auto ens4
iface ens4 inet static
    address 10.0.0.12
    netmask 255.255.255.0
    up ip route add 10.10.0.0/24 via 10.0.0.1

# NAT Network (DHCP)
auto ens5
iface ens5 inet dhcp
EOF

systemctl restart networking
```

---

## 27. haproxy-1 - Komplett Setup

### 27.1 Skapa VM i GNS3

- Template: Debian 12.6
- RAM: 512 MB
- Disk: 20 GB
- NICs: 2 st (ens4 → SERVICES-SW Gi0/1, ens5 → NAT)

### 27.2 Grundkonfiguration
```bash
# Sätt hostname
hostnamectl set-hostname haproxy-1

# Sätt tidszon
timedatectl set-timezone Europe/Stockholm

# Konfigurera hosts-fil
cat > /etc/hosts << 'EOF'
127.0.0.1       localhost

# Denna server
10.10.0.10      haproxy-1.lab3.local haproxy-1

# MGMT Network
10.0.0.1        ce-dc-mgmt
10.0.0.10       puppet-master-1.lab3.local puppet-master-1 puppet
10.0.0.11       puppet-master-2.lab3.local puppet-master-2
10.0.0.12       puppetdb.lab3.local puppetdb

# SERVICES Network
10.10.0.1       ce-dc-services
10.10.0.9       vip.lab3.local vip
10.10.0.11      haproxy-2.lab3.local haproxy-2
10.10.0.21      web-1.lab3.local web-1
10.10.0.22      web-2.lab3.local web-2
10.10.0.23      web-3.lab3.local web-3
10.10.0.31      terminal-1.lab3.local terminal-1
10.10.0.32      terminal-2.lab3.local terminal-2
10.10.0.40      nfs-server.lab3.local nfs-server
10.10.0.50      ssh-bastion.lab3.local ssh-bastion
EOF
```

### 27.3 Nätverkskonfiguration
```bash
cat > /etc/network/interfaces << 'EOF'
# Loopback
auto lo
iface lo inet loopback

# SERVICES Network
auto ens4
iface ens4 inet static
    address 10.10.0.10
    netmask 255.255.255.0
    # Routes till andra VRFs via CE-DC
    up ip route add 10.0.0.0/24 via 10.10.0.1
    up ip route add 10.20.1.0/24 via 10.10.0.1
    up ip route add 10.20.2.0/24 via 10.10.0.1

# NAT Network (DHCP - internet-access)
auto ens5
iface ens5 inet dhcp
EOF

systemctl restart networking
```

### 27.4 Verifiera nätverkskonfiguration
```bash
# Kolla IP-adresser
ip addr show ens4
ip addr show ens5

# Kolla routes
ip route

# Testa konnektivitet
ping -c 2 10.10.0.1      # Gateway
ping -c 2 10.0.0.10      # puppet-master-1 (via VRF leak)
ping -c 2 8.8.8.8        # Internet
```

### 27.5 Steg 4: Installera paket
```bash
apt update && apt upgrade -y
apt install -y haproxy keepalived wget curl gnupg2
```

### 27.6 Steg 5: Konfigurera HAProxy
```bash
cat > /etc/haproxy/haproxy.cfg << 'EOF'
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    log     global
    mode    http
    option  httplog
    option  dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000

frontend web_frontend
    bind *:80
    default_backend web_backend

backend web_backend
    balance roundrobin
    option httpchk GET /
    server web-1 10.10.0.21:80 check
    server web-2 10.10.0.22:80 check
    server web-3 10.10.0.23:80 check

listen stats
    bind *:8404
    stats enable
    stats uri /stats
    stats refresh 10s
    stats admin if LOCALHOST
EOF

systemctl enable haproxy
systemctl restart haproxy
```

### 27.7 Steg 6: Konfigurera Keepalived (VRRP Master)
```bash
cat > /etc/keepalived/keepalived.conf << 'EOF'
vrrp_instance VI_1 {
    state MASTER
    interface ens4
    virtual_router_id 51
    priority 100
    advert_int 1
    
    authentication {
        auth_type PASS
        auth_pass lab3secret
    }
    
    virtual_ipaddress {
        10.10.0.9/24
    }
}
EOF

systemctl enable keepalived
systemctl start keepalived

# Verifiera att VIP finns
ip addr show ens4 | grep 10.10.0.9
```

### 27.8 Steg 7: Installera och registrera Puppet Agent
```bash
# Lägg till Puppet repository
wget https://apt.puppet.com/puppet8-release-bookworm.deb
dpkg -i puppet8-release-bookworm.deb
apt update
apt install -y puppet-agent

# Konfigurera Puppet
cat > /etc/puppetlabs/puppet/puppet.conf << 'EOF'
[main]
server = puppet-master-1.lab3.local
certname = haproxy-1.lab3.local
EOF

# Registrera med Puppet (väntar på cert-signering)
/opt/puppetlabs/bin/puppet agent --test --waitforcert 60
```

**På puppet-master-1 (signera certifikat):**
```bash
sudo /opt/puppetlabs/bin/puppetserver ca list
sudo /opt/puppetlabs/bin/puppetserver ca sign --certname haproxy-1.lab3.local
```

---

## 28. haproxy-2 - Komplett Setup (VRRP Backup)

### 28.1 Skapa VM i GNS3

- Template: Debian 12.6
- RAM: 512 MB
- Disk: 20 GB
- NICs: 2 st (ens4 → SERVICES-SW Gi0/2, ens5 → NAT)

### 28.2 Steg 1-3: Grundkonfiguration
```bash
hostnamectl set-hostname haproxy-2
timedatectl set-timezone Europe/Stockholm

cat > /etc/hosts << 'EOF'
127.0.0.1       localhost

10.10.0.11      haproxy-2.lab3.local haproxy-2
10.10.0.10      haproxy-1.lab3.local haproxy-1
10.10.0.9       vip.lab3.local vip
10.10.0.21      web-1.lab3.local web-1
10.10.0.22      web-2.lab3.local web-2
10.10.0.23      web-3.lab3.local web-3
10.10.0.31      terminal-1.lab3.local terminal-1
10.10.0.32      terminal-2.lab3.local terminal-2
10.10.0.40      nfs-server.lab3.local nfs-server
10.10.0.50      ssh-bastion.lab3.local ssh-bastion
10.0.0.10       puppet-master-1.lab3.local puppet-master-1 puppet
EOF

cat > /etc/network/interfaces << 'EOF'
auto lo
iface lo inet loopback

auto ens4
iface ens4 inet static
    address 10.10.0.11
    netmask 255.255.255.0
    up ip route add 10.0.0.0/24 via 10.10.0.1
    up ip route add 10.20.1.0/24 via 10.10.0.1
    up ip route add 10.20.2.0/24 via 10.10.0.1

auto ens5
iface ens5 inet dhcp
EOF

systemctl restart networking
```

### 28.3 Steg 4-5: Installera paket och HAProxy
```bash
apt update && apt upgrade -y
apt install -y haproxy keepalived wget curl gnupg2

# Samma HAProxy-config som haproxy-1
cat > /etc/haproxy/haproxy.cfg << 'EOF'
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    log     global
    mode    http
    option  httplog
    option  dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000

frontend web_frontend
    bind *:80
    default_backend web_backend

backend web_backend
    balance roundrobin
    option httpchk GET /
    server web-1 10.10.0.21:80 check
    server web-2 10.10.0.22:80 check
    server web-3 10.10.0.23:80 check

listen stats
    bind *:8404
    stats enable
    stats uri /stats
    stats refresh 10s
    stats admin if LOCALHOST
EOF

systemctl enable haproxy
systemctl restart haproxy
```

### 28.4 Steg 6: Konfigurera Keepalived (VRRP Backup)
```bash
# Keepalived - BACKUP (priority 90, inte 100!)
cat > /etc/keepalived/keepalived.conf << 'EOF'
vrrp_instance VI_1 {
    state BACKUP
    interface ens4
    virtual_router_id 51
    priority 90
    advert_int 1
    
    authentication {
        auth_type PASS
        auth_pass lab3secret
    }
    
    virtual_ipaddress {
        10.10.0.9/24
    }
}
EOF

systemctl enable keepalived
systemctl start keepalived
```

### 28.5 Steg 7: Installera och registrera Puppet Agent
```bash
wget https://apt.puppet.com/puppet8-release-bookworm.deb
dpkg -i puppet8-release-bookworm.deb
apt update
apt install -y puppet-agent

cat > /etc/puppetlabs/puppet/puppet.conf << 'EOF'
[main]
server = puppet-master-1.lab3.local
certname = haproxy-2.lab3.local
EOF

/opt/puppetlabs/bin/puppet agent --test --waitforcert 60
```

**På puppet-master-1 (signera certifikat):**
```bash
sudo /opt/puppetlabs/bin/puppetserver ca sign --certname haproxy-2.lab3.local
```

### 28.6 Verifiera haproxy-2
```bash
# Kolla att VIP INTE finns på haproxy-2 (den ska vara på haproxy-1)
ip addr show ens4 | grep 10.10.0.9

# Kolla tjänster
systemctl status haproxy --no-pager
systemctl status keepalived --no-pager

# Testa connectivity
ping -c 2 10.10.0.10    # haproxy-1
ping -c 2 10.0.0.10     # puppet-master-1
```

### 28.7 VRRP Failover-test
```bash
# På haproxy-1: Stoppa keepalived
systemctl stop keepalived

# På haproxy-2: Verifiera att VIP flyttade hit
ip addr show ens4 | grep 10.10.0.9
# Bör nu visa 10.10.0.9

# På haproxy-1: Starta keepalived igen
systemctl start keepalived

# VIP ska flytta tillbaka till haproxy-1 (högre priority)
```
## 29. web-1 - Komplett Setup

### 29.1 Skapa VM i GNS3

- Template: Debian 12.6
- RAM: 512 MB
- Disk: 20 GB
- NICs: 2 st (ens4 → SERVICES-SW Gi0/3, ens5 → NAT)

### 29.2 Grundkonfiguration
```bash
hostnamectl set-hostname web-1
timedatectl set-timezone Europe/Stockholm

cat > /etc/hosts << 'EOF'
127.0.0.1       localhost

10.10.0.21      web-1.lab3.local web-1
10.10.0.9       vip.lab3.local vip
10.10.0.10      haproxy-1.lab3.local haproxy-1
10.10.0.11      haproxy-2.lab3.local haproxy-2
10.0.0.10       puppet-master-1.lab3.local puppet-master-1 puppet
EOF

cat > /etc/network/interfaces << 'EOF'
auto lo
iface lo inet loopback

auto ens4
iface ens4 inet static
    address 10.10.0.21
    netmask 255.255.255.0
    up ip route add 10.0.0.0/24 via 10.10.0.1
    up ip route add 10.20.1.0/24 via 10.10.0.1
    up ip route add 10.20.2.0/24 via 10.10.0.1

auto ens5
iface ens5 inet dhcp
EOF

systemctl restart networking
```

### 29.3 Installera Apache
```bash
apt update && apt upgrade -y
apt install -y apache2 wget curl

# Skapa testsida som visar servernamn
cat > /var/www/html/index.html << 'EOF'


Lab3 - web-1

Lab 3 Multi-Site Enterprise
Server: web-1
IP: 10.10.0.21


EOF

systemctl enable apache2
systemctl restart apache2
```

### 29.4 Installera och registrera Puppet Agent
```bash
wget https://apt.puppet.com/puppet8-release-bookworm.deb
dpkg -i puppet8-release-bookworm.deb
apt update
apt install -y puppet-agent

cat > /etc/puppetlabs/puppet/puppet.conf << 'EOF'
[main]
server = puppet-master-1.lab3.local
certname = web-1.lab3.local
EOF

/opt/puppetlabs/bin/puppet agent --test --waitforcert 60
```

**På puppet-master-1 (signera certifikat):**
```bash
sudo /opt/puppetlabs/bin/puppetserver ca sign --certname web-1.lab3.local
```

### 29.5 Verifiera web-1
```bash
# Testa lokalt
curl http://localhost

# Kolla tjänst
systemctl status apache2 --no-pager
```

---

## 30. web-2 - Komplett Setup

### 30.1 Skapa VM i GNS3

- Template: Debian 12.6
- RAM: 512 MB
- Disk: 20 GB
- NICs: 2 st (ens4 → SERVICES-SW Gi1/0, ens5 → NAT)

### 30.2 Grundkonfiguration
```bash
hostnamectl set-hostname web-2
timedatectl set-timezone Europe/Stockholm

cat > /etc/hosts << 'EOF'
127.0.0.1       localhost

10.10.0.22      web-2.lab3.local web-2
10.10.0.9       vip.lab3.local vip
10.10.0.10      haproxy-1.lab3.local haproxy-1
10.10.0.11      haproxy-2.lab3.local haproxy-2
10.0.0.10       puppet-master-1.lab3.local puppet-master-1 puppet
EOF

cat > /etc/network/interfaces << 'EOF'
auto lo
iface lo inet loopback

auto ens4
iface ens4 inet static
    address 10.10.0.22
    netmask 255.255.255.0
    up ip route add 10.0.0.0/24 via 10.10.0.1
    up ip route add 10.20.1.0/24 via 10.10.0.1
    up ip route add 10.20.2.0/24 via 10.10.0.1

auto ens5
iface ens5 inet dhcp
EOF

systemctl restart networking
```

### 30.3 Installera Apache
```bash
apt update && apt upgrade -y
apt install -y apache2 wget curl

cat > /var/www/html/index.html << 'EOF'


Lab3 - web-2

Lab 3 Multi-Site Enterprise
Server: web-2
IP: 10.10.0.22


EOF

systemctl enable apache2
systemctl restart apache2
```

### 30.4 Installera och registrera Puppet Agent
```bash
wget https://apt.puppet.com/puppet8-release-bookworm.deb
dpkg -i puppet8-release-bookworm.deb
apt update
apt install -y puppet-agent

cat > /etc/puppetlabs/puppet/puppet.conf << 'EOF'
[main]
server = puppet-master-1.lab3.local
certname = web-2.lab3.local
EOF

/opt/puppetlabs/bin/puppet agent --test --waitforcert 60
```

**På puppet-master-1 (signera certifikat):**
```bash
sudo /opt/puppetlabs/bin/puppetserver ca sign --certname web-2.lab3.local
```

---

## 31. web-3 - Komplett Setup

### 31.1 Skapa VM i GNS3

- Template: Debian 12.6
- RAM: 512 MB
- Disk: 20 GB
- NICs: 2 st (ens4 → SERVICES-SW Gi1/1, ens5 → NAT)

### 31.2 Grundkonfiguration
```bash
hostnamectl set-hostname web-3
timedatectl set-timezone Europe/Stockholm

cat > /etc/hosts << 'EOF'
127.0.0.1       localhost

10.10.0.23      web-3.lab3.local web-3
10.10.0.9       vip.lab3.local vip
10.10.0.10      haproxy-1.lab3.local haproxy-1
10.10.0.11      haproxy-2.lab3.local haproxy-2
10.0.0.10       puppet-master-1.lab3.local puppet-master-1 puppet
EOF

cat > /etc/network/interfaces << 'EOF'
auto lo
iface lo inet loopback

auto ens4
iface ens4 inet static
    address 10.10.0.23
    netmask 255.255.255.0
    up ip route add 10.0.0.0/24 via 10.10.0.1
    up ip route add 10.20.1.0/24 via 10.10.0.1
    up ip route add 10.20.2.0/24 via 10.10.0.1

auto ens5
iface ens5 inet dhcp
EOF

systemctl restart networking
```

### 31.3 Installera Apache
```bash
apt update && apt upgrade -y
apt install -y apache2 wget curl

cat > /var/www/html/index.html << 'EOF'


Lab3 - web-3

Lab 3 Multi-Site Enterprise
Server: web-3
IP: 10.10.0.23


EOF

systemctl enable apache2
systemctl restart apache2
```

### 31.4 Installera och registrera Puppet Agent
```bash
wget https://apt.puppet.com/puppet8-release-bookworm.deb
dpkg -i puppet8-release-bookworm.deb
apt update
apt install -y puppet-agent

cat > /etc/puppetlabs/puppet/puppet.conf << 'EOF'
[main]
server = puppet-master-1.lab3.local
certname = web-3.lab3.local
EOF

/opt/puppetlabs/bin/puppet agent --test --waitforcert 60
```

**På puppet-master-1 (signera certifikat):**
```bash
sudo /opt/puppetlabs/bin/puppetserver ca sign --certname web-3.lab3.local
```

---

## 32. Verifiera Load Balancing

### 32.1 Testa från haproxy-1
```bash
# Testa VIP - kör flera gånger och se att servern varierar
for i in {1..6}; do curl -s http://10.10.0.9 | grep "Server:"; done
```

**Förväntat resultat:**
```
<h2>Server: web-1</h2>
<h2>Server: web-2</h2>
<h2>Server: web-3</h2>
<h2>Server: web-1</h2>
<h2>Server: web-2</h2>
<h2>Server: web-3</h2>
```

### 32.2 HAProxy Stats

Öppna i webbläsare: `http://10.10.0.10:8404/stats`

Alla tre webservrar ska visas som **UP** (gröna).

## 33. terminal-1 - Komplett Setup (XRDP Terminalserver)

### 33.1 Skapa VM i GNS3

- Template: Debian 12.6
- RAM: 1024 MB
- Disk: 20 GB
- NICs: 2 st (ens4 → SERVICES-SW Gi1/2, ens5 → NAT)

### 33.2 Grundkonfiguration
```bash
hostnamectl set-hostname terminal-1
timedatectl set-timezone Europe/Stockholm

cat > /etc/hosts << 'EOF'
127.0.0.1       localhost

10.10.0.31      terminal-1.lab3.local terminal-1
10.10.0.32      terminal-2.lab3.local terminal-2
10.10.0.40      nfs-server.lab3.local nfs-server
10.0.0.10       puppet-master-1.lab3.local puppet-master-1 puppet
EOF

cat > /etc/network/interfaces << 'EOF'
auto lo
iface lo inet loopback

auto ens4
iface ens4 inet static
    address 10.10.0.31
    netmask 255.255.255.0
    up ip route add 10.0.0.0/24 via 10.10.0.1
    up ip route add 10.20.1.0/24 via 10.10.0.1
    up ip route add 10.20.2.0/24 via 10.10.0.1

auto ens5
iface ens5 inet dhcp
EOF

systemctl restart networking
```

### 33.3 Installera XRDP och Xfce
```bash
apt update && apt upgrade -y
apt install -y xrdp xfce4 xfce4-goodies nfs-common wget curl

# Konfigurera XRDP att använda Xfce
echo "xfce4-session" > /root/.xsession
chmod +x /root/.xsession

# Aktivera XRDP
systemctl enable xrdp
systemctl restart xrdp
```

### 33.4 Montera NFS för hemkataloger
```bash
mkdir -p /srv/nfs/home
echo "10.10.0.40:/srv/nfs/home /srv/nfs/home nfs defaults 0 0" >> /etc/fstab
mount -a
```

**OBS:** NFS-servern (10.10.0.40) måste vara konfigurerad först innan mount fungerar.

### 33.5 Skapa användare med hemkataloger på NFS
```bash
# Skapa 20 användare med hemkataloger på NFS
for i in $(seq -w 1 20); do
    useradd -m -d /srv/nfs/home/user$i -s /bin/bash user$i
    echo "user$i:password123" | chpasswd
done
```

### 33.6 Installera och registrera Puppet Agent
```bash
wget https://apt.puppet.com/puppet8-release-bookworm.deb
dpkg -i puppet8-release-bookworm.deb
apt update
apt install -y puppet-agent

cat > /etc/puppetlabs/puppet/puppet.conf << 'EOF'
[main]
server = puppet-master-1.lab3.local
certname = terminal-1.lab3.local
EOF

/opt/puppetlabs/bin/puppet agent --test --waitforcert 60
```

**På puppet-master-1 (signera certifikat):**
```bash
sudo /opt/puppetlabs/bin/puppetserver ca sign --certname terminal-1.lab3.local
```

### 33.7 Verifiera terminal-1
```bash
# Kolla XRDP-tjänst
systemctl status xrdp --no-pager

# Kolla att port 3389 lyssnar
ss -tlnp | grep 3389

# Kolla NFS-mount
df -h | grep nfs
```

---

## 34. terminal-2 - Komplett Setup (XRDP Terminalserver)

### 34.1 Skapa VM i GNS3

- Template: Debian 12.6
- RAM: 1024 MB
- Disk: 20 GB
- NICs: 2 st (ens4 → SERVICES-SW Gi1/3, ens5 → NAT)

### 34.2 Grundkonfiguration
```bash
hostnamectl set-hostname terminal-2
timedatectl set-timezone Europe/Stockholm

cat > /etc/hosts << 'EOF'
127.0.0.1       localhost

10.10.0.32      terminal-2.lab3.local terminal-2
10.10.0.31      terminal-1.lab3.local terminal-1
10.10.0.40      nfs-server.lab3.local nfs-server
10.0.0.10       puppet-master-1.lab3.local puppet-master-1 puppet
EOF

cat > /etc/network/interfaces << 'EOF'
auto lo
iface lo inet loopback

auto ens4
iface ens4 inet static
    address 10.10.0.32
    netmask 255.255.255.0
    up ip route add 10.0.0.0/24 via 10.10.0.1
    up ip route add 10.20.1.0/24 via 10.10.0.1
    up ip route add 10.20.2.0/24 via 10.10.0.1

auto ens5
iface ens5 inet dhcp
EOF

systemctl restart networking
```

### 34.3 Installera XRDP och Xfce
```bash
apt update && apt upgrade -y
apt install -y xrdp xfce4 xfce4-goodies nfs-common wget curl

echo "xfce4-session" > /root/.xsession
chmod +x /root/.xsession

systemctl enable xrdp
systemctl restart xrdp
```

### 34.4 Montera NFS (samma share som terminal-1)
```bash
# Montera samma NFS (användare finns redan)
mkdir -p /srv/nfs/home
echo "10.10.0.40:/srv/nfs/home /srv/nfs/home nfs defaults 0 0" >> /etc/fstab
mount -a
```

**OBS:** Användarna skapades redan på terminal-1 med hemkataloger på NFS-servern. Dessa användare fungerar automatiskt på terminal-2 också.

### 34.5 Installera och registrera Puppet Agent
```bash
wget https://apt.puppet.com/puppet8-release-bookworm.deb
dpkg -i puppet8-release-bookworm.deb
apt update
apt install -y puppet-agent

cat > /etc/puppetlabs/puppet/puppet.conf << 'EOF'
[main]
server = puppet-master-1.lab3.local
certname = terminal-2.lab3.local
EOF

/opt/puppetlabs/bin/puppet agent --test --waitforcert 60
```

**På puppet-master-1 (signera certifikat):**
```bash
sudo /opt/puppetlabs/bin/puppetserver ca sign --certname terminal-2.lab3.local
```

### 34.6 Verifiera terminal-2
```bash
# Kolla XRDP-tjänst
systemctl status xrdp --no-pager

# Kolla att port 3389 lyssnar
ss -tlnp | grep 3389

# Kolla NFS-mount
df -h | grep nfs
```

---
## 33. ssh-bastion - Komplett Setup

### 33.1 Skapa VM i GNS3

- Template: Debian 12.6
- RAM: 512 MB
- Disk: 20 GB
- NICs: 2 st (ens4 → SERVICES-SW Gi2/1, ens5 → NAT)

### 33.2 Grundkonfiguration
```bash
hostnamectl set-hostname ssh-bastion
timedatectl set-timezone Europe/Stockholm

cat > /etc/hosts << 'EOF'
127.0.0.1       localhost

10.10.0.50      ssh-bastion.lab3.local ssh-bastion
10.0.0.10       puppet-master-1.lab3.local puppet-master-1 puppet
EOF

cat > /etc/network/interfaces << 'EOF'
auto lo
iface lo inet loopback

auto ens4
iface ens4 inet static
    address 10.10.0.50
    netmask 255.255.255.0
    up ip route add 10.0.0.0/24 via 10.10.0.1
    up ip route add 10.20.1.0/24 via 10.10.0.1
    up ip route add 10.20.2.0/24 via 10.10.0.1

auto ens5
iface ens5 inet dhcp
EOF

systemctl restart networking
```

### 33.3 Installera SSH med MFA
```bash
apt update && apt upgrade -y
apt install -y openssh-server libpam-google-authenticator wget curl

# Aktivera MFA i PAM
echo "auth required pam_google_authenticator.so" >> /etc/pam.d/sshd

# Konfigurera SSH för MFA
sed -i 's/^#*KbdInteractiveAuthentication.*/KbdInteractiveAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config

# Begränsa SSH-åtkomst till MGMT-subnät
cat >> /etc/ssh/sshd_config << 'EOF'

# Endast tillåt från MGMT-nät
AllowUsers *@10.0.0.*
EOF

systemctl restart sshd
```

### 33.4 Skapa admin-användare
```bash
useradd -m -s /bin/bash admin
echo "admin:SecurePass123!" | chpasswd
```

### 33.5 Installera och registrera Puppet Agent
```bash
wget https://apt.puppet.com/puppet8-release-bookworm.deb
dpkg -i puppet8-release-bookworm.deb
apt update
apt install -y puppet-agent

cat > /etc/puppetlabs/puppet/puppet.conf << 'EOF'
[main]
server = puppet-master-1.lab3.local
certname = ssh-bastion.lab3.local
EOF

/opt/puppetlabs/bin/puppet agent --test --waitforcert 60
```

**På puppet-master-1 (signera certifikat):**
```bash
sudo /opt/puppetlabs/bin/puppetserver ca sign --certname ssh-bastion.lab3.local
```
