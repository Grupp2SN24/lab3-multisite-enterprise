# Windows 10 Thin Client - Branch B

## Network Configuration
| Setting | Value |
|---------|-------|
| Adapter | Ethernet 2 |
| IP Address | 10.20.2.10 |
| Subnet Mask | 255.255.255.0 |
| Default Gateway | 10.20.2.1 |
| DNS | 8.8.8.8 |

### Configure Static IP (CMD as Admin)
```cmd
netsh interface ip set address "Ethernet 2" static 10.20.2.10 255.255.255.0 10.20.2.1
netsh interface ip set dns "Ethernet 2" static 8.8.8.8
```

### Add Route to DC Services
```cmd
route add 10.10.0.0 mask 255.255.0.0 10.20.2.1 -p
```

### Allow ICMP (Firewall)
```cmd
netsh advfirewall firewall add rule name="Allow ICMPv4" protocol=icmpv4:any,any dir=in action=allow
```

---

## Puppet Agent Installation

### 1. Edit hosts file (C:\Windows\System32\drivers\etc\hosts)
Add this line:
```
192.168.122.40 puppet-master.lab3.local puppet-master puppet
```

### 2. Download and Install Puppet Agent
```
https://downloads.puppet.com/windows/puppet8/puppet-agent-x64-latest.msi
```
During installation, set Puppet master server to: `puppet-master.lab3.local`

### 3. Run Puppet Agent (CMD as Admin)
```cmd
"C:\Program Files\Puppet Labs\Puppet\bin\puppet" agent --test
```

### 4. Sign certificate on Puppet Master
```bash
sudo /opt/puppetlabs/bin/puppetserver ca sign --all
```

---

## RDP to Terminal Server

| Setting | Value |
|---------|-------|
| Server | 10.10.0.31 |
| Username | user01 |
| Password | password123 |

### Connect
```cmd
mstsc /v:10.10.0.31
```

---

## Verification

- [ ] Can ping 10.20.2.1 (CE-B gateway)
- [ ] Can ping 10.10.0.31 (Terminal-1)
- [ ] Puppet agent registered in Foreman
- [ ] RDP to Terminal-1 works
