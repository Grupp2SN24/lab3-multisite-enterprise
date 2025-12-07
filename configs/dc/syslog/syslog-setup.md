# Centralized Syslog Setup

## Overview
Centralized logging using rsyslog on puppet-master (10.0.0.10).
Network devices send logs via UDP 514.

## Server: puppet-master (10.0.0.10)

### 1. Install rsyslog
sudo apt update && sudo apt install rsyslog -y

### 2. Edit /etc/rsyslog.conf - uncomment:
module(load="imudp")
input(type="imudp" port="514")

### 3. Create /etc/rsyslog.d/remote.conf
template(name="RemoteLogs" type="string" string="/var/log/remote/%HOSTNAME%/%PROGRAMNAME%.log")

if $fromhost-ip != "127.0.0.1" then {
    action(type="omfile" dynaFile="RemoteLogs")
    stop
}

### 4. Restart
sudo mkdir -p /var/log/remote
sudo systemctl restart rsyslog

## Client: CE-DC (Cisco)
logging host 10.0.0.10 vrf MGMT
logging trap informational

## Verification
ls /var/log/remote/
cat /var/log/remote/ce-dc/*.log
tail -f /var/log/remote/ce-dc/*.log
