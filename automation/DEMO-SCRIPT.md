# 🎬 Lab 3 Demo Script

## Grupp 2 SN24 | Redovisning

---

## 📋 Före Demo (Förberedelse)

### 1. Starta GNS3-projektet
```bash
# Starta alla routrar först (PE1, PE2, PE-A, PE-B, CE-DC, CE-A, CE-B)
# Vänta tills BGP är etablerat (~2 min)
```

### 2. Verifiera Provider Core
```
# På PE1
show ip bgp summary
# Alla sessioner ska vara "Established"
```

### 3. Starta Dashboard på Puppet-Master
```bash
sudo systemctl start lab3-dashboard
# Öppna http://10.10.0.40:5000 i browser
```

---

## 🎯 Demo Del 1: Visa Topologi (2 min)

**Visa i GNS3:**
- "Här ser ni vår topologi med DC och två branches"
- "DC är dual-homed till PE1 och PE2 för redundans"
- "Branch A och B ansluter via egna PE-routrar"

**Visa BGP:**
```
# På CE-DC
show ip bgp summary
show ip bgp
show ip bgp community 65000:110
```

---

## 🎯 Demo Del 2: Automatiserad Deployment (5 min)

### Öppna Dashboard
"Här ser ni vår automationsdashboard. Just nu är alla hosts pending."

### Skapa ny VM (web-3)
1. I GNS3: Add QEMU VM (Debian 12)
2. Sätt MAC-adress: `0c:10:00:00:00:23`
3. Koppla:
   - ens4 → SERVICES-SW
   - ens5 → NAT

### Starta VM och kör bootstrap
```bash
# I VM:en
curl -s http://10.10.0.40:5000/bootstrap | bash
```

**Medan det körs, förklara:**
- "Scriptet detekterar MAC-adressen"
- "Dashboard svarar med konfiguration"
- "Hostname, nätverk och tjänster konfigureras automatiskt"
- "Puppet-agent installeras och registreras"

### Visa Dashboard
- Status ändras: Pending → Configuring → Ready
- Klicka "Sign All Puppet Certs"

### Verifiera
```bash
# Test load balancing
for i in {1..6}; do curl -s http://10.10.0.9 | grep Server; done
# web-3 ska nu dyka upp i rotationen!
```

---

## 🎯 Demo Del 3: Load Balancer Failover (2 min)

### Visa VIP
```bash
# På HAProxy-1
ip addr show ens4 | grep 10.10.0.9
# VIP: 10.10.0.9
```

### Simulera failover
```bash
# Stoppa keepalived på master
sudo systemctl stop keepalived
```

### Verifiera failover
```bash
# På HAProxy-2
ip addr show ens4 | grep 10.10.0.9
# VIP har flyttat!
```

### Testa att tjänsten fortfarande fungerar
```bash
curl http://10.10.0.9
# Fungerar fortfarande!
```

### Återställ
```bash
# På HAProxy-1
sudo systemctl start keepalived
```

---

## 🎯 Demo Del 4: End-to-End Test (3 min)

### Från Branch A thin-client
```bash
# Ping DC services
ping 10.10.0.9

# Testa webbtjänst
curl http://10.10.0.9

# RDP till terminal server
xfreerdp /v:10.10.0.31 /u:user01 /p:password123 /cert:ignore
```

### Visa traceroute
```bash
traceroute 10.10.0.9
# Branch A → CE-A → PE-A → PE1 → CE-DC → Services
```

---

## 🎯 Demo Del 5: Observability (2 min)

### SNMPv3
```bash
# Från puppet-master
snmpwalk -v3 -u snmpuser -l authPriv -a SHA -A "Lab3SNMPauth!" -x AES -X "Lab3SNMPpriv!" 10.10.0.1 sysDescr
```

### NetFlow
```bash
# På HAProxy-1
nfdump -R /var/cache/nfdump/ -o extended | head -20
```

### Syslog
```bash
# På puppet-master
ls /var/log/remote/
tail -f /var/log/remote/ce-dc/*.log
```

---

## 🎯 Demo Del 6: Puppet (2 min)

### Visa Foreman
- Öppna https://puppet-master.lab3.local
- Login: admin / Labpass123!
- Visa "Hosts > All Hosts"

### Kör Puppet på en host
```bash
# På web-1
sudo /opt/puppetlabs/bin/puppet agent --test
```

---

## ❓ Vanliga Frågor

**Q: Varför eBGP istället för iBGP mellan sites?**
A: Varje site har egen kundrouter (CE), provider hanterar transit via sin AS.

**Q: Varför allowas-in?**
A: Alla CE-routrar har samma AS (65000). Utan allowas-in droppar BGP routes som innehåller egen AS.

**Q: Varför VRF?**
A: Segmentering - MGMT-trafik separeras från USER och SERVICES för säkerhet.

**Q: Hur hanterar ni HA för Puppet?**
A: Just nu single-node, men PuppetDB kan skalas och Foreman ger provisionering-redundans.

---

## 🆘 Om Något Går Fel

### BGP session down
```
clear ip bgp * soft
```

### Dashboard ej tillgänglig
```bash
sudo systemctl restart lab3-dashboard
```

### Puppet-cert problem
```bash
sudo /opt/puppetlabs/bin/puppetserver ca sign --all
```

### VM får ej nätverk
```bash
ifdown ens4; ifup ens4
dhclient ens5
```

---

## ✅ Checklista Innan Demo

- [ ] Alla routrar startade och BGP established
- [ ] Dashboard körs på puppet-master
- [ ] Minst 3 servrar ready (haproxy-1, web-1, web-2)
- [ ] VIP (10.10.0.9) svarar på curl
- [ ] RDP till terminal-1 fungerar
- [ ] Foreman tillgänglig

---

**Lycka till! 🚀**
