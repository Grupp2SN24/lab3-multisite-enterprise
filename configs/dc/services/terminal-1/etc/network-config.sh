#!/bin/bash
# Terminal-1 Network Configuration (AlmaLinux 9.4)
nmcli con add type ethernet con-name "services" ifname eth0 ipv4.addresses 10.10.0.31/24 ipv4.method manual autoconnect yes
nmcli con up "services"
