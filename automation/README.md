# 🚀 Lab 3 Automation System

## Grupp 2 SN24

Detta automationssystem gör det möjligt att deploya hela labbmiljön med **minimal manuell insats**. Istället för att kopiera kommandon för varje server, kör du ett enda kommando.

---

## 📋 Översikt

### Före: Manuellt (ca 4 timmar)
```
1. Skapa VM
2. Konfigurera nätverk manuellt
3. Sätt hostname
4. Installera paket
5. Konfigurera tjänster
6. Installera Puppet
7. Upprepa 12+ gånger...
```

### Efter: Automatiserat (ca 30 minuter)
```
1. Starta Dashboard på puppet-master
2. Skapa VMs i GNS3 (med rätt MAC-adresser)
3. Kör bootstrap på varje VM
4. Klart! ✓
```

---

## 🔧 Installation

### Steg 1: Installera Dashboard på Puppet-Master

```bash
# På puppet-master (192.168.122.40 / 10.0.0.10)
cd /tmp
git clone https://github.com/Grupp2SN24/lab3-multisite-enterprise.git
cd lab3-multisite-enterprise/automation
sudo bash install-dashboard.sh
```

Dashboard är nu tillgänglig på: **http://192.168.122.40:5000**

### Steg 2: Konfigurera MAC-adresser i GNS3

För att automationen ska fungera måste varje VM ha en **specifik MAC-adress** som matchar registret i dashboarden.

| Server | MAC-adress | IP |
|--------|------------|-----|
| haproxy-1 | `0c:10:00:00:00:10` | 10.10.0.10 |
| haproxy-2 | `0c:10:00:00:00:11` | 10.10.0.11 |
| web-1 | `0c:10:00:00:00:21` | 10.10.0.21 |
| web-2 | `0c:10:00:00:00:22` | 10.10.0.22 |
| web-3 | `0c:10:00:00:00:23` | 10.10.0.23 |
| terminal-1 | `0c:10:00:00:00:31` | 10.10.0.31 |
| terminal-2 | `0c:10:00:00:00:32` | 10.10.0.32 |
| nfs-server | `0c:10:00:00:00:40` | 10.10.0.40 |
| ssh-bastion | `0c:10:00:00:00:50` | 10.10.0.50 |
| thin-client-a | `0c:20:01:00:00:20` | 10.20.1.20 |

**I GNS3:**
1. Högerklicka på VM → Configure
2. Gå till Network
3. Ändra MAC-adress för adapter 0 (ens4)

### Steg 3: Koppla VMs korrekt

Varje VM behöver två nätverkskort:
- **ens4** → Koppla till rätt switch (SERVICES-SW, LAN-SW-A, etc.)
- **ens5** → Koppla till NAT-moln (för internet/paketinstallation)

---

## 🎯 Användning

### Metod 1: One-liner Bootstrap (Rekommenderat)

Starta VM:en och kör:

```bash
curl -s http://192.168.122.40:5000/bootstrap | bash
```

Det är allt! Scriptet:
1. ✅ Detekterar MAC-adress
2. ✅ Hämtar konfiguration från dashboard
3. ✅ Sätter hostname
4. ✅ Konfigurerar nätverk
5. ✅ Installerar rätt tjänster baserat på roll
6. ✅ Installerar och registrerar Puppet-agent

### Metod 2: Manuell med rollval

Om dashboard inte är tillgänglig:

```bash
# Debian
curl -s https://raw.githubusercontent.com/Grupp2SN24/lab3-multisite-enterprise/main/automation/auto-setup.sh | \
    DASHBOARD_URL=http://192.168.122.40:5000 bash
```

---

## 🖥️ Dashboard

Öppna **http://192.168.122.40:5000** i din webbläsare för att se:

- **Status för alla hosts** - Pending/Configuring/Ready
- **Real-time uppdateringar** - Auto-refresh var 5:e sekund
- **Sign Puppet Certs** - En knapp för att signera alla väntande certifikat
- **Activity Log** - Se vad som händer i realtid

### API Endpoints

| Endpoint | Metod | Beskrivning |
|----------|-------|-------------|
| `/` | GET | Dashboard |
| `/api/discover` | POST | Ny host registrerar sig |
| `/api/status` | POST | Uppdatera host-status |
| `/api/hosts` | GET | Lista alla hosts |
| `/api/sign-certs` | POST | Signera Puppet-certifikat |
| `/bootstrap` | GET | Bootstrap-script |
| `/auto-setup.sh` | GET | Full setup-script |

---

## 📦 Vad installeras per roll?

| Roll | Paket | Tjänster |
|------|-------|----------|
| **loadbalancer** | haproxy, keepalived | HAProxy, Keepalived (VRRP) |
| **webserver** | apache2 | Apache med demo-sida |
| **terminal** | xrdp, nfs-utils | XRDP, 20 användare |
| **nfs** | nfs-kernel-server | NFS-export för /home |
| **bastion** | openssh, google-authenticator | SSH med MFA |
| **thinclient** | freerdp2-x11 | RDP-klient |

---

## 🔄 Demo-flöde

### För Live Demo (Redovisning)

1. **Visa Dashboard** - Alla hosts pending
2. **Starta en ny VM** i GNS3 (t.ex. web-3)
3. **Kör bootstrap:**
   ```bash
   curl -s http://192.168.122.40:5000/bootstrap | bash
   ```
4. **Visa Dashboard** - Status ändras: Pending → Configuring → Ready
5. **Signera Puppet-cert** via Dashboard
6. **Testa tjänsten:**
   ```bash
   curl http://10.10.0.9  # Ska visa web-3 i load balancing
   ```

### Full Deploy (Alla servrar)

```bash
# Terminal 1: Öppna Dashboard i browser
http://192.168.122.40:5000

# Terminal 2-4: Parallellt på flera VMs
curl -s http://192.168.122.40:5000/bootstrap | bash
```

---

## 🛠️ Felsökning

### "Unknown MAC address"
- Kontrollera att MAC-adressen är registrerad i dashboarden
- Verifiera att VM:en har rätt MAC-adress i GNS3

### "Dashboard not available"
- Kontrollera att dashboard-tjänsten körs:
  ```bash
  sudo systemctl status lab3-dashboard
  ```
- Kontrollera brandvägg:
  ```bash
  sudo ufw allow 5000/tcp
  ```

### Puppet-cert signeras inte
- Signera manuellt:
  ```bash
  sudo /opt/puppetlabs/bin/puppetserver ca sign --all
  ```

### VM får inte IP på ens5
- Kontrollera NAT-moln i GNS3
- Kör manuellt:
  ```bash
  dhclient ens5
  ```

---

## 📁 Filstruktur

```
automation/
├── dashboard/
│   ├── app.py              # Flask-applikation
│   ├── requirements.txt    # Python-dependencies
│   └── routes.py           # Extra routes för scripts
├── auto-setup.sh           # Fullständigt setup-script
├── bootstrap.sh            # Enkel bootstrap one-liner
├── install-dashboard.sh    # Installationsscript för dashboard
└── README.md               # Denna fil
```

---

## 🔒 Säkerhet

**OBS:** Detta är ett lab-system. För produktion:
- Lägg till autentisering på API:t
- Använd HTTPS
- Begränsa nätverksåtkomst till dashboard
- Använd starkare lösenord

---

## 👥 Team

**Grupp 2 SN24**
- Anton (Team Lead, DC Routing, Automation)
- Fredrik (Provider Core)
- Taro (Puppet Infrastructure)
- Asal (Web Services)
- Chinenye (Branch Sites)

---

## 📚 Relaterade Dokument

- [Deployment Guide](../docs/DEPLOYMENT-GUIDE.md) - Manuell deployment
- [IP Addressing](../docs/architecture/ip-addressing.md) - IP-plan
- [Operations Runbook](../docs/runbooks/operations.md) - Driftsguide

---

**Lycka till med demon! 🚀**
