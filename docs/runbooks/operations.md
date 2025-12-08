# Operations Runbook - Lab 3

## Quick Reference

| Service | IP | Port | Check Command |
|---------|-----|------|---------------|
| HAProxy VIP | 10.10.0.9 | 80 | `curl http://10.10.0.9` |
| Web servers | 10.10.0.21-23 | 80 | `curl http://10.10.0.2X` |
| Terminal servers | 10.10.0.31-32 | 3389 | `xfreerdp /v:10.10.0.31` |
| Puppet Master | 10.0.0.10 | 8140 | `puppet agent --test` |
| NFS Server | 10.10.0.40 | 2049 | `showmount -e 10.10.0.40` |

---

## 1. BGP Troubleshooting

### Check BGP Status
```
show ip bgp summary
show ip bgp neighbor 192.168.100.2
show ip bgp
```

### BGP Session Down
1. Check physical link: `show interface GigabitEthernet0/1`
2. Check BFD: `show bfd neighbors`
3. Verify prefix-list: `show ip prefix-list`
4. Check logs: `show logging | include BGP`

### Clear BGP Session
```
clear ip bgp 192.168.100.2 soft
```

---

## 2. HAProxy / Load Balancer

### Check VIP Status
```bash
# On HAProxy-1 or HAProxy-2
ip addr show ens4 | grep 10.10.0.9
systemctl status keepalived
```

### Check Backend Health
```bash
# Test each web server
curl http://10.10.0.21
curl http://10.10.0.22
curl http://10.10.0.23

# Test load balancing (run multiple times)
for i in {1..10}; do curl -s http://10.10.0.9 | grep Server; done
```

### HAProxy Logs
```bash
journalctl -u haproxy -f
tail -f /var/log/haproxy.log
```

### Failover Test
```bash
# On HAProxy-1 (master)
sudo systemctl stop keepalived

# Verify VIP moved to HAProxy-2
ssh haproxy-2 "ip addr show ens4 | grep 10.10.0.9"

# Restore
sudo systemctl start keepalived
```

---

## 3. Puppet

### Run Puppet Agent
```bash
sudo /opt/puppetlabs/bin/puppet agent --test
```

### Check Certificate Status
```bash
# On Puppet Master
sudo /opt/puppetlabs/bin/puppetserver ca list --all
```

### Sign Pending Certificates
```bash
sudo /opt/puppetlabs/bin/puppetserver ca sign --all
```

### View Foreman Dashboard
```
http://10.0.0.10 (or via NAT)
```

---

## 4. Terminal Servers (RDP)

### Test RDP Connection
```bash
# From thin client or any Linux
xfreerdp /v:10.10.0.31 /u:user01 /p:password123

# From Windows
mstsc /v:10.10.0.31
```

### Check XRDP Service
```bash
sudo systemctl status xrdp
sudo journalctl -u xrdp -f
```

### Check NFS Mount
```bash
df -h | grep nfs
mount | grep nfs
ls /mnt/nfs-home
```

---

## 5. Network Connectivity Tests

### End-to-End Test (Branch A → DC)
```bash
# From thin client (10.20.1.10)
ping 10.10.0.9          # HAProxy VIP
curl http://10.10.0.9   # Web service
xfreerdp /v:10.10.0.31  # RDP
```

### Traceroute
```bash
traceroute 10.10.0.9
```

### Check Routes on CE Router
```
show ip route
show ip bgp
show ip route vrf MGMT
```

---

## 6. Observability

### NetFlow - View Flows
```bash
# On HAProxy-1
nfdump -R /var/cache/nfdump/ -o extended
nfdump -R /var/cache/nfdump/ 'src ip 10.20.1.0/24'
```

### SNMPv3 - Query Router
```bash
snmpwalk -v3 -u snmpuser -l authPriv -a SHA -A "Lab3SNMPauth!" -x AES -X "Lab3SNMPpriv!" 10.10.0.1 sysDescr
```

### Syslog - View Logs
```bash
# On Puppet Master
tail -f /var/log/remote/*/syslog
ls /var/log/remote/
```

---

## 7. Common Issues

### Issue: Cannot reach DC from Branch
1. Check BGP: `show ip bgp summary` (sessions Established?)
2. Check routes: `show ip route 10.10.0.0`
3. Check allowas-in: `show run | section bgp`
4. Ping step-by-step: gateway → PE → DC

### Issue: Web page not loading
1. Check HAProxy: `systemctl status haproxy`
2. Check VIP: `ip addr | grep 10.10.0.9`
3. Check backends: `curl http://10.10.0.21`
4. Check Apache: `systemctl status apache2`

### Issue: RDP connection refused
1. Check XRDP: `systemctl status xrdp`
2. Check firewall: `sudo iptables -L`
3. Check user exists: `id user01`
4. Check NFS: `mount | grep nfs`

### Issue: Puppet agent fails
1. Check DNS/hosts: `ping puppet-master.lab3.local`
2. Check certificate: `puppet ssl verify`
3. Check Puppet server: `systemctl status puppetserver`

---

## 8. Emergency Contacts

| Role | Person | Responsibility |
|------|--------|----------------|
| Team Lead | Anton | DC Routing, Coordination |
| Provider Core | Fredrik | PE routers, iBGP |
| Puppet | Taro | Config management |
| Services | Asal | HAProxy, Web, Terminal |
| Branches | Chinenye | CE-A, CE-B, Thin clients |
