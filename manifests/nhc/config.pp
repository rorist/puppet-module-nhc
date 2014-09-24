# private class
class warewulf::nhc::config {

  file { '/etc/nhc':
    ensure  => $warewulf::directory_ensure,
    path    => $warewulf::nhc_conf_dir,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
  }

  datacat { '/etc/nhc/nhc.conf':
    ensure    => $warewulf::file_ensure,
    path      => $warewulf::nhc_conf_file,
    template  => 'warewulf/nhc/nhc.conf.erb',
    owner     => 'root',
    group     => 'root',
    mode      => '0644',
    require   => File['/etc/nhc'],
  }

  if $warewulf::nhc_checks_hash {
    create_resources('warewulf::nhc::check', $warewulf::nhc_checks_hash)
  }

  if $warewulf::nhc_checks_array {
    warewulf::nhc::check { $warewulf::nhc_checks_array: }
  }

  file { '/etc/nhc/scripts':
    ensure  => $warewulf::directory_ensure,
    path    => $warewulf::nhc_include_dir,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    require => File['/etc/nhc'],
  }

  file { '/etc/sysconfig/nhc':
    ensure  => $warewulf::file_ensure,
    path    => $warewulf::nhc_sysconfig_path,
    content => template('warewulf/nhc/sysconfig.erb'),
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
  }

  if $warewulf::manage_nhc_logrotate {
    logrotate::rule { 'nhc':
      ensure        => $warewulf::ensure,
      path          => $warewulf::nhc_log_file,
      missingok     => true,
      ifempty       => false,
      rotate_every  => $warewulf::nhc_log_rotate_every,
    }
  }
}
