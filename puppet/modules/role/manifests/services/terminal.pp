class role::services::terminal {
  include profile::base
  include profile::terminal

  package { 'xrdp':
    ensure => present,
  }

  service { 'xrdp':
    ensure  => running,
    enable  => true,
    require => Package['xrdp'],
  }
}
