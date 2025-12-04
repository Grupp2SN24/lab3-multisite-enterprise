# HAPROXY-2 Configuration

## Network
- IP: 10.10.0.11/24
- Gateway: 10.10.0.1
- Interface: ens4 → SERVICES-SW

## Services
- HAProxy: Load balancer
- Keepalived: VRRP BACKUP (priority 90)
- VIP: 10.10.0.9

## Backend Servers
- web1: 10.10.0.21:80
- web2: 10.10.0.22:80
- web3: 10.10.0.23:80
