# Apache web server profile
class profile::apache {
  
  # Install Apache
  package { 'apache2':
    ensure => present,
  }
  
  # Demo webpage showing hostname
  file { '/var/www/html/index.html':
    ensure  => file,
    content => epp('profile/index.html.epp'),
    require => Package['apache2'],
  }
  
  service { 'apache2':
    ensure  => running,
    enable  => true,
    require => Package['apache2'],
  }
}
