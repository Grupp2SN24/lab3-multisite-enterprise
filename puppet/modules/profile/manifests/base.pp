class profile::base {
  # Determine service name based on OS
  $chrony_service = $facts['os']['family'] ? {
    'RedHat' => 'chronyd',
    default  => 'chrony',
  }

  package { 'chrony':
    ensure => present,
  }

  service { $chrony_service:
    ensure  => running,
    enable  => true,
    require => Package['chrony'],
  }

  exec { 'set-timezone':
    command => '/usr/bin/timedatectl set-timezone Europe/Stockholm',
    unless  => '/usr/bin/timedatectl show -p Timezone | grep Europe/Stockholm',
  }
}
