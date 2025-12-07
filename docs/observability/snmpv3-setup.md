# SNMPv3 Configuration - Lab 3

## Overview
SNMPv3 with authentication (SHA) and privacy (AES128) configured on all CE routers.

## Credentials
| Parameter | Value |
|-----------|-------|
| User | snmpuser |
| Auth Protocol | SHA |
| Auth Password | Lab3SNMPauth! |
| Priv Protocol | AES128 |
| Priv Password | Lab3SNMPpriv! |
| Group | LAB3-RO |
| View | LAB3-VIEW |

## Configured Routers

| Router | Location | Access-list |
|--------|----------|-------------|
| CE-DC | Datacenter DC | 10.0.0.0/24 |
| CE-A | Branch A | 10.0.0.0/24, 10.0.1.0/24 |
| CE-B | Branch B | 10.0.0.0/24, 10.0.2.0/24 |

## Test Commands

### From Puppet-Master (10.0.0.10)
```bash
# Install snmp tools
sudo apt install snmp -y

# Test SNMPv3 query
snmpwalk -v3 -u snmpuser -l authPriv -a SHA -A "Lab3SNMPauth!" -x AES -X "Lab3SNMPpriv!" 10.10.0.1 sysDescr

# Get BGP info
snmpwalk -v3 -u snmpuser -l authPriv -a SHA -A "Lab3SNMPauth!" -x AES -X "Lab3SNMPpriv!" 10.10.0.1 1.3.6.1.2.1.15
```

### Verification on Router
```
show snmp group
show snmp user
show snmp view
```

## Security Notes
- Access restricted via ACL 99 (MGMT subnets only)
- No write access configured (read-only)
- SNMPv1/v2c disabled for security
