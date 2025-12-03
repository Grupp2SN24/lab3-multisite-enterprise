# DC Routing Configs

**Status**: ✅ Complete
**Owner**: Anton
**Date**: 3 December 2024

## Architecture
CE-DC is the datacenter edge router with:
- 3 VRFs (MGMT, SERVICES, USER)
- Dual-homed to PE1 and PE2 (eBGP AS65000 ↔ AS65001)
- Announces DC networks: 10.0.0.0/24, 10.10.0.0/24, 10.20.0.0/24

## Verification
All DC networks visible in provider core with redundant paths.

## VRF Design
| VRF | Network | Gateway | Purpose |
|-----|---------|---------|---------|
| MGMT | 10.0.0.0/24 | 10.0.0.1 | Puppet, SSH |
| SERVICES | 10.10.0.0/24 | 10.10.0.1 | Web, Terminal |
| USER | 10.20.0.0/24 | 10.20.0.1 | End users |

## Next Steps
- Taro: Deploy Puppet servers in MGMT VRF
- Asal: Deploy services in SERVICES VRF
- Chinenye: Configure branches to reach DC services
