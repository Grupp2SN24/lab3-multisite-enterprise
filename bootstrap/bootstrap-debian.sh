#!/bin/bash
set -e
PUPPET_SERVER="10.10.0.40"
PUPPET_FQDN="puppet-master.lab3.local"
echo "=== Installing Puppet Agent ==="
cd /tmp
wget -q https://apt.puppet.com/puppet8-release-bookworm.deb
dpkg -i puppet8-release-bookworm.deb
apt update
apt install -y puppet-agent
cat > /etc/puppetlabs/puppet/puppet.conf << CONF
[main]
server = ${PUPPET_FQDN}
CONF
sed -i '/puppet-master/d' /etc/hosts
sed -i '/puppet/d' /etc/hosts
echo "${PUPPET_SERVER} ${PUPPET_FQDN} puppet-master puppet" >> /etc/hosts
echo "=== Registering with Puppet Master ==="
/opt/puppetlabs/bin/puppet agent --test --waitforcert 10 || true
echo "=== Done! ==="
