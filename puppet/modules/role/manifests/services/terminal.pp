class role::services::terminal {
  include profile::base
  
  package { 'xrdp':
    ensure => present,
  }
  
  service { 'xrdp':
    ensure  => running,
    enable  => true,
    require => Package['xrdp'],
  }
}
