# Team Rollfördelning - Lab 3

## 🎯 Översikt

**Projekt**: Multi-Site Enterprise Network  
**Deadline**: 13 December 2024  
**Team**: Grupp 2 SN24 (5 personer)

---

## 👥 Person 1: Fredrik - Network Architect & Provider Core

**Ansvar**: GNS3-topologi och Provider-nätverk  
**Svårighetsgrad**: ⭐⭐⭐ Medel

### Uppgifter
- [ ] Skapa GNS3-projekt
- [ ] Installera router images (FRR/Linux)
- [ ] Konfigurera PE-routrar (PE1, PE2, PE-A, PE-B)
- [ ] Konfigurera iBGP mellan PE-routrar
- [ ] Testa connectivity i provider core

**Arbetsguide**: `docs/guides/person1-fredrik-provider-core.md`  
**Konfig-filer**: `configs/provider/`  
**Estimerad tid**: 4-6 timmar

**Leverabler**:
- [ ] GNS3-projekt med 4 PE-routrar
- [ ] iBGP mesh mellan alla PE
- [ ] Ping-test mellan alla PE loopbacks

---

## 👥 Person 2: Anton - DC Edge & Routing ⭐ TEAM LEAD

**Ansvar**: Datacenter CE-router och VRF-konfiguration  
**Svårighetsgrad**: ⭐⭐⭐⭐⭐ Svårast

### Uppgifter
- [ ] Konfigurera CE-DC (Arista vEOS eller Cisco)
- [ ] Skapa VRFs (MGMT, SERVICES, USER)
- [ ] Konfigurera eBGP mot PE1 och PE2
- [ ] Implementera BGP policy och communities
- [ ] Konfigurera BFD för snabb failover
- [ ] Route leaking mellan VRFs
- [ ] Koordinera integration med branches

**Arbetsguide**: `docs/guides/person2-anton-dc-routing.md`  
**Konfig-filer**: `configs/dc/`  
**Estimerad tid**: 6-8 timmar

**Leverabler**:
- [ ] CE-DC med 3 VRFs konfigurerade
- [ ] Dual-homed eBGP (PE1 + PE2)
- [ ] BGP communities taggade
- [ ] BFD aktiverat och testat
- [ ] Route leak policy dokumenterad

---

## 👥 Person 3: Taro - Puppet Infrastructure

**Ansvar**: Configuration management och automation  
**Svårighetsgrad**: ⭐⭐⭐⭐ Svår

### Uppgifter
- [ ] Installera Puppet Master (single node ok, HA om tid finns)
- [ ] Konfigurera PuppetDB
- [ ] Installera Foreman (optional men rekommenderat)
- [ ] Skapa Puppet modules för:
  - Base profile (alla servrar)
  - HAProxy profile
  - Apache profile
  - Terminal server profile
  - NFS profile
- [ ] Testa agent enrollment
- [ ] Dokumentera Puppet-arkitektur

**Arbetsguide**: `docs/guides/person3-taro-puppet.md`  
**Puppet-kod**: `puppet/`  
**Estimerad tid**: 6-8 timmar

**Leverabler**:
- [ ] Puppet Master (10.0.0.10) fungerande
- [ ] Minst 3 modules i `puppet/modules/`
- [ ] Test-agent kan ansluta och få katalog
- [ ] Dokumenterad hieradata-struktur

---

## 👥 Person 4: Asal - Web Services & Load Balancing

**Ansvar**: HAProxy, Apache, Terminal Servers  
**Svårighetsgrad**: ⭐⭐⭐ Medel

### Uppgifter
- [ ] Installera 2x HAProxy servrar (10.10.0.10-11)
- [ ] Konfigurera VRRP/keepalived (VIP: 10.10.0.9)
- [ ] Installera 3x Apache Web servrar (10.10.0.21-23)
- [ ] Konfigurera load balancing mot Apache
- [ ] Installera 2x Terminal servers med XRDP (10.10.0.31-32)
- [ ] Skapa demo-webbsida som visar servername
- [ ] Installera NFS-server (10.10.0.40)

**Arbetsguide**: `docs/guides/person4-asal-services.md`  
**Scripts**: `scripts/setup/services/`  
**Estimerad tid**: 5-7 timmar

**Leverabler**:
- [ ] HAProxy med working VIP
- [ ] 3x Apache servrar bakom load balancer
- [ ] 2x Terminal servers med RDP fungerande
- [ ] Demo-webbsida visar vilken backend-server som svarar
- [ ] NFS-share monterad och testad

---

## 👥 Person 5: Chinenye - Branch Sites & Thin Clients

**Ansvar**: Branch routrar och tunna klienter  
**Svårighetsgrad**: ⭐⭐ Lättast (men viktig!)

### Uppgifter
- [ ] Konfigurera CE-A (Branch A) - baserat på Antons DC-config
- [ ] Konfigurera CE-B (Branch B) - samma som CE-A
- [ ] eBGP mot PE-A och PE-B
- [ ] Installera Debian thin client i Branch A (10.20.1.10)
- [ ] Installera Windows thin client i Branch B (10.20.2.10) - optional
- [ ] Testa RDP från thin client till terminal servers
- [ ] Testa HTTP till webbservices via HAProxy VIP
- [ ] Dokumentera end-to-end test

**Arbetsguide**: `docs/guides/person5-chinenye-branches.md`  
**Konfig-filer**: `configs/branch-a/`, `configs/branch-b/`  
**Estimerad tid**: 4-6 timmar

**Leverabler**:
- [ ] CE-A och CE-B med eBGP fungerande
- [ ] Debian thin client kan nå DC services
- [ ] RDP-session till terminal server fungerande
- [ ] HTTP-request till HAProxy VIP fungerande
- [ ] End-to-end test dokumenterat med screenshots

---

## 📋 Gemensamma milestones

### Vecka 1 (mån-fre)
- [ ] **Fredrik**: Provider core färdig → Anton kan börja eBGP
- [ ] **Anton**: DC routing och VRFs färdiga → Chinenye kan börja branches
- [ ] **Taro**: Puppet Master uppsatt → Asal kan börja installera med Puppet

### Vecka 2 (mån-fre)
- [ ] **Taro**: Puppet modules klara → Asal deployer services
- [ ] **Asal**: Services deployade och testade
- [ ] **Chinenye**: Branches konfigurerade → End-to-end test

### Vecka 3 (mån-ons)
- [ ] **Alla**: End-to-end test (branch → web services)
- [ ] **Anton + Taro**: Dokumentation och diagram
- [ ] **Alla**: Presentation och demo

---

## 🚀 Quick Start för varje person

### Dag 1 - Setup (ALLA)
1. Klona repot: `git clone git@github.com:Grupp2SN24/lab3-multisite-enterprise.git`
2. Läs [IP-adressplan](../architecture/ip-addressing.md)
3. Läs din personliga guide i `docs/guides/`

### Dag 2-5 - Implementation
4. Följ steg-för-steg i din guide
5. Committa configs/kod dagligen
6. Uppdatera checkboxes i denna fil
7. Testa din del ordentligt

### Dag 6-7 - Integration
8. Integrera med andra delar
9. Hjälp teammedlemmar som kör fast
10. Dokumentera problem och lösningar

---

## 📞 Kommunikation

### Dagliga standups (10 min)
- **När**: Varje morgon 09:00
- **Vad**: 
  - Vad gjorde jag igår?
  - Vad gör jag idag?
  - Blockers?

### Kontaktinfo
- **Team Lead**: Anton (DC Routing + koordinering)
- **GitHub**: Issues för problem, PR för kod
- **Discord/Slack**: [Lägg till länk]

### Git workflow
```bash
# Skapa din egen branch
git checkout -b fredrik/provider-core

# Jobba och committa
git add configs/provider/
git commit -m "[Fredrik] PE1 iBGP config"

# Pusha din branch
git push origin fredrik/provider-core

# Skapa PR på GitHub när klar
```

---

## ⚠️ VIKTIGT - Läs detta!

### Dependencies (vem beror på vem)
```
Fredrik (Provider) 
    ↓ (måste vara klar först)
Anton (DC Routing)
    ↓ (behöver DC VRFs)
Taro (Puppet)     Chinenye (Branches)
    ↓                  ↓
Asal (Services) ← kan börja parallellt
```

### Om du kör fast
1. **Dubbelkolla IP-planen** - 90% av problem är fel IP/subnet
2. **Testa i delar** - ping först, sedan BGP, sedan services
3. **Läs loggarna** - `journalctl -xe` eller `show ip bgp`
4. **Fråga teamet** - skapa GitHub Issue
5. **Fråga Anton** - han har översikt över hela arkitekturen

### Commit best practices
```bash
# Bra commits:
[Fredrik] Added PE1 basic config with loopback
[Anton] Configured VRF SERVICES on CE-DC
[Taro] Created puppet base profile module

# Dåliga commits:
"fixed stuff"
"asdf"
"testing"
```

### Testing checklist (innan du säger "klar")
- [ ] Konfiguration sparad och backupad
- [ ] Testat med ping/curl/traceroute
- [ ] Config committad till GitHub
- [ ] Dokumenterat i din guide vad som funkar
- [ ] Testat med minst en annan persons setup

---

## 🎓 Learning Resources

- **BGP**: https://www.cloudflare.com/learning/security/glossary/what-is-bgp/
- **VRF**: https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/mp_l3_vpns/configuration/xe-16/mp-l3-vpns-xe-16-book/mp-bgp-mpls-vpns.html
- **Puppet**: https://www.puppet.com/docs/puppet/7/puppet_index.html
- **HAProxy**: http://www.haproxy.org/\#docs
- **VRRP/Keepalived**: https://www.keepalived.org/manpage.html

---

**Lycka till team! Let's build something awesome! 🚀**
