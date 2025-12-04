# Terminal Servers Configuration

## Terminal-1
- IP: 10.10.0.31/24
- OS: AlmaLinux 9.4
- Services: XRDP, NFS mount
- User: labuser / labpass123

## Terminal-2
- IP: 10.10.0.32/24
- OS: AlmaLinux 9.4
- Services: XRDP, NFS mount
- User: labuser / labpass123

## NFS Mount
- Source: 10.10.0.40:/srv/nfs/home
- Mount: /mnt/nfs-home
