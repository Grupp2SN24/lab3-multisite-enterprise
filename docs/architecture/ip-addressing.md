# IP-adressplan - Lab 3 Multi-Site Enterprise Network

## Datacenter (DC)

### Management VRF
- **Subnet**: 10.0.0.0/24
- **Gateway**: 10.0.0.1 (CE-DC)

| Device | IP | Role |
|--------|-----|------|
| CE-DC | 10.0.0.1 | Gateway |
| Puppet-Master-1 | 10.0.0.10 | Config mgmt |
| Puppet-Master-2 | 10.0.0.11 | Config mgmt |
| PuppetDB | 10.0.0.12 | Database |
| Foreman | 10.0.0.13 | Provisioning |
| SSH-Bastion | 10.0.0.20 | Access |

### Services VRF
- **Subnet**: 10.10.0.0/24
- **Gateway**: 10.10.0.1 (CE-DC)

| Device | IP | Role |
|--------|-----|------|
| HAProxy-1 | 10.10.0.10 | Load balancer |
| HAProxy-2 | 10.10.0.11 | Load balancer |
| HAProxy-VIP | 10.10.0.9 | VRRP Virtual IP |
| Web-1 | 10.10.0.21 | Apache server |
| Web-2 | 10.10.0.22 | Apache server |
| Web-3 | 10.10.0.23 | Apache server |
| Terminal-1 | 10.10.0.31 | XRDP server |
| Terminal-2 | 10.10.0.32 | XRDP server |
| NFS-Server | 10.10.0.40 | File storage |

### User VRF
- **Subnet**: 10.20.0.0/24
- **Gateway**: 10.20.0.1 (CE-DC)

## Branch A

### Management VRF
- **Subnet**: 10.0.1.0/24
- **Gateway**: 10.0.1.1 (CE-A)

### User VRF
- **Subnet**: 10.20.1.0/24
- **Gateway**: 10.20.1.1 (CE-A)

| Device | IP | Role |
|--------|-----|------|
| Debian-Thin-Client | 10.20.1.10 | RDP client |

## Branch B

### Management VRF
- **Subnet**: 10.0.2.0/24
- **Gateway**: 10.0.2.1 (CE-B)

### User VRF
- **Subnet**: 10.20.2.0/24
- **Gateway**: 10.20.2.1 (CE-B)

| Device | IP | Role |
|--------|-----|------|
| Windows-Thin-Client | 10.20.2.10 | RDP client (optional) |

## WAN/BGP Links

### DC to Provider (Dual-homed)
**Link 1: CE-DC → PE1**
- Subnet: 192.168.100.0/30
- CE-DC: 192.168.100.1
- PE1: 192.168.100.2

**Link 2: CE-DC → PE2**
- Subnet: 192.168.100.4/30
- CE-DC: 192.168.100.5
- PE2: 192.168.100.6

### Branch A to Provider
- Subnet: 192.168.101.0/30
- CE-A: 192.168.101.1
- PE-A: 192.168.101.2

### Branch B to Provider
- Subnet: 192.168.102.0/30
- CE-B: 192.168.102.1
- PE-B: 192.168.102.2

## BGP Configuration

### AS Numbers
- **Enterprise**: AS65000
- **Provider**: AS65001

### Router IDs (Loopbacks)
| Router | Loopback | AS |
|--------|----------|-----|
| CE-DC | 1.1.1.1/32 | 65000 |
| CE-A | 1.1.1.10/32 | 65000 |
| CE-B | 1.1.1.11/32 | 65000 |
| PE1 | 2.2.2.1/32 | 65001 |
| PE2 | 2.2.2.2/32 | 65001 |
| PE-A | 2.2.2.10/32 | 65001 |
| PE-B | 2.2.2.11/32 | 65001 |

## BGP Communities
```
65000:110 = Prefer PE1 path
65000:120 = Prefer PE2 path
65000:200 = MGMT prefix
65000:210 = SERVICES prefix
65000:220 = USER prefix
```

## Summary Table

| Site | MGMT | SERVICES | USER | WAN |
|------|------|----------|------|-----|
| DC | 10.0.0.0/24 | 10.10.0.0/24 | 10.20.0.0/24 | 192.168.100.0/30 + .4/30 |
| Branch A | 10.0.1.0/24 | - | 10.20.1.0/24 | 192.168.101.0/30 |
| Branch B | 10.0.2.0/24 | - | 10.20.2.0/24 | 192.168.102.0/30 |

**Total Hosts**: ~17 VMs
**Total Routers**: 7 (3 CE + 4 PE)
