class role::services::nfs {
  include profile::base

  package { 'nfs-kernel-server':
    ensure => present,
  }

  service { 'nfs-kernel-server':
    ensure  => running,
    enable  => true,
    require => Package['nfs-kernel-server'],
  }
}
