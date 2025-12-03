# Provider Core Configs

**Status**: ✅ Complete
**Owner**: Fredrik
**Date**: 2 December 2024

## Topology
```
PE1 (2.2.2.1) ------- PE2 (2.2.2.2)
 |                      |
PE-A (2.2.2.10) ----- PE-B (2.2.2.11)
```

## Verification
- All loopbacks reachable via OSPF
- iBGP full mesh operational
- All BGP sessions Established

## Files
- `pe1-config.txt` - PE1 running-config
- `pe2-config.txt` - PE2 running-config
- `pe-a-config.txt` - PE-A running-config
- `pe-b-config.txt` - PE-B running-config

## IP Addressing
| Router | Loopback | AS |
|--------|----------|-----|
| PE1 | 2.2.2.1/32 | 65001 |
| PE2 | 2.2.2.2/32 | 65001 |
| PE-A | 2.2.2.10/32 | 65001 |
| PE-B | 2.2.2.11/32 | 65001 |

## Links
- PE1 Gi0/1 ↔ PE2 Gi0/1: 10.255.0.0/30
- PE1 Gi0/2 ↔ PE-A Gi0/1: 10.255.0.4/30
- PE2 Gi0/2 ↔ PE-B Gi0/1: 10.255.0.8/30

## Next Steps
Anton can now connect CE-DC to PE1 and PE2 for eBGP.
