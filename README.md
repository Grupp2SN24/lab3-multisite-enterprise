# Lab 3: Multi-Site Enterprise Network

**Grupp 2 - SN24**

## 🎯 Projektmål

Bygga ett komplett multi-site enterprise-nätverk med:
- **3 sites**: 1 Datacenter + 2 Branch offices
- **eBGP routing**: AS65000 ↔ AS65001
- **VRF-segmentering**: MGMT, SERVICES, USER
- **Redundans**: Dual-homed DC, VRRP, BFD
- **Automation**: Full Puppet-orkestrering
- **Services**: Load-balanced web, terminal servers

## 👥 Team

| Namn | Roll | Ansvar |
|------|------|--------|
| **Anton** 🔴 | Team Lead & DC Routing | Datacenter edge, VRFs, BGP policy |
| **Fredrik** 🟠 | Network Architect | Provider core, GNS3 topology |
| **Taro** 🟠 | DevOps Engineer | Puppet infrastructure, automation |
| **Asal** 🟡 | Services Engineer | HAProxy, Apache, Terminal servers |
| **Chinenye** 🟢 | Branch Engineer | Branch sites, thin clients |

**Svårighetsgrad**: 🔴 Svårast | 🟠 Svår | 🟡 Medel | 🟢 Lättast

## 📁 Repository-struktur
```
.
├── docs/
│   ├── architecture/        # IP-plan, topologi, BGP-policy
│   ├── guides/             # Individuella arbetsguider
│   └── team-assignments/   # Rollfördelning
├── configs/
│   ├── dc/                 # CE-DC configs (Anton)
│   ├── branch-a/           # CE-A configs (Chinenye)
│   ├── branch-b/           # CE-B configs (Chinenye)
│   └── provider/           # PE configs (Fredrik)
├── puppet/
│   ├── manifests/          # site.pp (Taro)
│   ├── modules/            # Custom modules (Taro)
│   └── hieradata/          # Configuration data (Taro)
├── scripts/
│   ├── setup/              # Installation scripts
│   ├── validation/         # Test scripts
│   └── monitoring/         # Monitoring configs
└── gns3/
    ├── topology/           # GNS3 project files (Fredrik)
    └── images/             # Router images info
```

## 🚀 Quick Start

### För alla
1. Klona repot: `git clone git@github.com:Grupp2SN24/lab3-multisite-enterprise.git`
2. Läs [IP-adressplan](docs/architecture/ip-addressing.md)
3. Läs [Team Roles](docs/team-assignments/TEAM-ROLES.md)

### För din roll
Se din personliga guide i `docs/guides/`:
- **Fredrik**: [Provider Core Guide](docs/guides/fredrik-provider-core.md)
- **Anton**: [DC Routing Guide](docs/guides/anton-dc-routing.md)
- **Taro**: [Puppet Guide](docs/guides/taro-puppet.md)
- **Asal**: [Services Guide](docs/guides/asal-services.md)
- **Chinenye**: [Branches Guide](docs/guides/chinenye-branches.md)

## 📊 Status

| Component | Status | Owner | Progress |
|-----------|--------|-------|----------|
| Provider Core | ⏳ Not started | Fredrik | 0/5 tasks |
| DC Routing | ⏳ Not started | Anton | 0/6 tasks |
| Puppet Infrastructure | ⏳ Not started | Taro | 0/5 tasks |
| Web Services | ⏳ Not started | Asal | 0/7 tasks |
| Branch Sites | ⏳ Not started | Chinenye | 0/7 tasks |

**Legend**: ⏳ Not started | 🚧 In progress | ✅ Complete

## 🏗️ Arkitektur

### Topologi
```
                Provider Core (AS65001)
                /      |       \
            PE1/      PE-A     PE-B
              /        |         \
          CE-DC      CE-A       CE-B
          (DC)      (Br-A)     (Br-B)
        Anton      Chinenye   Chinenye
            |          |          |
      VRF:MGMT      USER       USER
      VRF:SERV      (thin)     (thin)
      VRF:USER      client     client
         |
      Asal's
     Services
```

### Komponenter
- **7 routrar**: 3 CE (enterprise), 4 PE (provider)
- **~17 servrar**: Puppet, HAProxy, Apache, Terminal, NFS, Thin clients
- **3 VRFs**: Segmentering per trafiktyp

### VRF Design
| VRF | Syfte | Sites | Exempel |
|-----|-------|-------|---------|
| MGMT | Management, Puppet | DC, Br-A, Br-B | SSH, Puppet agents |
| SERVICES | DC-tjänster | Endast DC | Web, Terminal, NFS |
| USER | End-user access | DC, Br-A, Br-B | Thin clients |

## 📚 Dokumentation

- ✅ [IP-adressplan](docs/architecture/ip-addressing.md)
- ✅ [Team Rollfördelning](docs/team-assignments/TEAM-ROLES.md)
- ⏳ [BGP Policy](docs/architecture/bgp-policy.md) - *kommer snart*
- ⏳ [Topologi](docs/architecture/topology.md) - *kommer snart*

### Individuella guider
- ⏳ [Fredrik: Provider Core](docs/guides/fredrik-provider-core.md)
- ⏳ [Anton: DC Routing](docs/guides/anton-dc-routing.md)
- ⏳ [Taro: Puppet](docs/guides/taro-puppet.md)
- ⏳ [Asal: Services](docs/guides/asal-services.md)
- ⏳ [Chinenye: Branches](docs/guides/chinenye-branches.md)

## 🤝 Teamarbete

### Communication
- **Team Lead**: Anton (koordinering, tekniska beslut)
- **Daily Standups**: 09:00 varje morgon (10 min)
- **GitHub Issues**: För problem och blockers
- **Pull Requests**: All kod via PR (code review)

### Git Workflow
```bash
# Varje person arbetar i sin egen branch
git checkout -b fredrik/provider-core
git checkout -b anton/dc-routing
git checkout -b taro/puppet-modules
git checkout -b asal/services
git checkout -b chinenye/branches

# Commit-format
[Fredrik] Added PE1 basic config
[Anton] Configured MGMT VRF on CE-DC
[Taro] Created puppet base profile
[Asal] HAProxy VRRP configuration
[Chinenye] CE-A eBGP to PE-A working
```

### Dependencies
```
Fredrik (Provider Core)
    ↓ måste vara klar först
Anton (DC Routing) 
    ↓ VRFs måste finnas
Taro (Puppet) + Chinenye (Branches) ← kan börja parallellt
    ↓
Asal (Services) ← deployar med Puppet
    ↓
End-to-end test (alla tillsammans)
```

## 📞 Kontakt

- **GitHub**: [Grupp2SN24/lab3-multisite-enterprise](https://github.com/Grupp2SN24/lab3-multisite-enterprise)
- **Team Lead**: Anton
- **Questions?**: Skapa en Issue eller fråga i Discord/Slack

## 🎯 Milestones

### Vecka 1 (2-6 dec)
- [ ] **Fredrik**: Provider core komplett, alla PE pratar iBGP
- [ ] **Anton**: DC routing komplett, alla VRFs up
- [ ] **Taro**: Puppet Master installerat och fungerande

### Vecka 2 (9-13 dec)
- [ ] **Taro**: Alla Puppet modules klara
- [ ] **Asal**: Services deployade via Puppet
- [ ] **Chinenye**: Branches konfigurerade, thin clients up

### Vecka 3 (16-18 dec)
- [ ] **Alla**: End-to-end test fungerande
- [ ] **Anton + Taro**: Dokumentation och topologidiagram
- [ ] **Alla**: Presentation och demo färdig

**Deadline**: 18 December 2024

## 📄 Licens

MIT License - se [LICENSE](LICENSE)

---

**Last Updated**: 2 December 2024  
**Version**: 1.0  
**Status**: 🚧 Project kickoff - Ready to start!
