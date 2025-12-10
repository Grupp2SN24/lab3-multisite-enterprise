# Puppet Master Setup Guide

## VM Setup
- OS: Debian 12
- RAM: 2 GB
- CPU: 2 vCPUs
- Disk: 20 GB
- Hostname: puppet-master
- IP: 192.168.100.10 (static)
- Internet access: connect the second adapter (ens5) of this VM directly to a NAT cloud in GNS3

## Step 1: Install Puppet Server
sudo apt update
sudo apt install puppetserver -y

## Step 2: Configure Puppet
Edit /etc/puppetlabs/puppet/puppet.conf:
[main]
certname = puppet-master
server = puppet-master
environment = production
runinterval = 1h

## Step 3: Start Puppet Server
sudo systemctl start puppetserver
sudo systemctl enable puppetserver

## Step 4: Networking
sudo ufw allow 8140
On clients, add to /etc/hosts:
192.168.100.10 puppet-master

## Step 5: Verify
sudo systemctl status puppetserver
puppet config print certname
