# NetFlow Configuration - Lab 3

## Overview
NetFlow v9 configured on all CE routers, exporting to HAProxy-1 (10.10.0.10).

## Architecture
```
CE-DC (1.1.1.1)  ──┐
CE-A  (1.1.1.10) ──┼── UDP 2055 ──► HAProxy-1 (10.10.0.10) ──► nfdump
CE-B  (1.1.1.11) ──┘
```

## Router Configuration

All CE routers have:
```
ip flow-export version 9
ip flow-export destination 10.10.0.10 2055
ip flow-export source Loopback0

interface GigabitEthernet0/0
 ip flow ingress
 ip flow egress

interface GigabitEthernet0/1
 ip flow ingress
 ip flow egress

interface GigabitEthernet0/2
 ip flow ingress
 ip flow egress
```

## Collector (HAProxy-1)

### Installation
```bash
sudo apt install -y nfdump
sudo mkdir -p /var/cache/nfdump
sudo nfcapd -D -w /var/cache/nfdump -p 2055
```

### View Flows
```bash
# All flows
nfdump -R /var/cache/nfdump/ -o extended

# Specific file
nfdump -r /var/cache/nfdump/nfcapd.YYYYMMDDHHMM -o extended

# Filter by IP
nfdump -R /var/cache/nfdump/ -o extended 'src ip 10.20.1.0/24'
```

## Verification

### On Router
```
show ip flow export
show ip cache flow
```

### On Collector
```bash
sudo ss -ulnp | grep 2055
sudo tcpdump -i ens4 udp port 2055 -c 5
nfdump -R /var/cache/nfdump/ -o extended
```

## Sample Output
```
Date first seen          Proto   Src IP Addr:Port     Dst IP Addr:Port      Packets  Bytes
2025-12-08 00:58:24      ICMP    10.20.1.1:0      ->  10.10.0.9:0.0            20    2000
2025-12-08 00:57:05      TCP     192.168.100.2:179 -> 192.168.100.1:25942       1      59
```

## Exported Data
- BGP sessions (TCP 179)
- ICMP traffic between sites
- HTTP traffic to web services
- All inter-site communication
