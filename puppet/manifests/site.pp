# Main Puppet manifest for Lab 3

node default {
  # Default config
}

# MGMT VRF servers
node 'puppet-master' {
  include role::management::puppet
}

# SERVICES VRF servers
node /^haproxy-\d+$/ {
  include role::services::loadbalancer
}

node /^web-\d+$/ {
  include role::services::webserver
}

node /^terminal-\d+$/ {
  include role::services::terminal
}

node 'nfs-server' {
  include role::services::nfs
}

node 'ssh-bastion' {
  include role::services::bastion
}

# Branch thin clients
node /^thin-client/ {
  include profile::base
}
