class role::services::bastion {
  include profile::base

  package { ['openssh-server', 'libpam-google-authenticator']:
    ensure => present,
  }

  service { 'ssh':
    ensure => running,
    enable => true,
  }
}
