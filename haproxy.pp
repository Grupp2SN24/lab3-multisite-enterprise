# HAProxy load balancer profile
class profile::haproxy {
  
  # Install HAProxy
  package { 'haproxy':
    ensure => present,
  }
  
  # Install keepalived for VRRP
  package { 'keepalived':
    ensure => present,
  }
  
  # HAProxy config
  file { '/etc/haproxy/haproxy.cfg':
    ensure  => file,
    content => @("END"),
      global
          log /dev/log local0
          chroot /var/lib/haproxy
          stats timeout 30s
          user haproxy
          group haproxy
          daemon
      
      defaults
          log     global
          mode    http
          option  httplog
          timeout connect 5000
          timeout client  50000
          timeout server  50000
      
      frontend web_frontend
          bind *:80
          default_backend web_backend
      
      backend web_backend
          balance roundrobin
          server web1 10.10.0.21:80 check
          server web2 10.10.0.22:80 check
          server web3 10.10.0.23:80 check
      | END
    require => Package['haproxy'],
    notify  => Service['haproxy'],
  }
  
  service { 'haproxy':
    ensure  => running,
    enable  => true,
    require => Package['haproxy'],
  }
}
