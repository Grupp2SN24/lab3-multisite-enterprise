class profile::terminal {
  # NFS mount för hemkataloger
  package { 'nfs-utils':
    ensure => present,
  }

  file { '/home':
    ensure => directory,
  }

  mount { '/home':
    ensure  => mounted,
    device  => '10.10.0.40:/srv/nfs/home',
    fstype  => 'nfs',
    options => 'defaults',
    require => Package['nfs-utils'],
  }

  # Skapa 20 användare
  $users = ['user01','user02','user03','user04','user05',
            'user06','user07','user08','user09','user10',
            'user11','user12','user13','user14','user15',
            'user16','user17','user18','user19','user20']

  $users.each |$user| {
    user { $user:
      ensure     => present,
      home       => "/home/${user}",
      managehome => true,
      shell      => '/bin/bash',
      password   => '$6$rounds=4096$salt$hashedpassword',
    }
  }
}
