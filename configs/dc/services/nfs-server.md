# NFS Server Configuration

## Network
- IP: 10.10.0.40/24
- OS: Debian 12

## NFS Export
- Path: /srv/nfs/home
- Clients: 10.10.0.0/24
- Options: rw,sync,no_subtree_check,no_root_squash
