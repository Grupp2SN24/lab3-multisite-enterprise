#!/bin/bash
# Terminal-2 Network Configuration (AlmaLinux 9.4)
nmcli con mod "services" ipv4.addresses 10.10.0.32/24 ipv4.method manual
nmcli con mod "services" +ipv4.routes "10.20.1.0/24 10.10.0.1, 10.20.2.0/24 10.10.0.1, 10.0.0.0/24 10.10.0.1"
nmcli con up "services"
