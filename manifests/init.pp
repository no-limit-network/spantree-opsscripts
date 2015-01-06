# == Class: opsscripts
#
# Full description of class opsscripts here.
#
# === Parameters
#
# [*sample_parameter*]
#   Explanation of what this parameter affects and what it defaults to.
#
# === Examples
#
#  inclunde opsscripts
#
# === Authors
#
# Author Sebastian Otaegui <feniix@gmail.com>
#
# === Copyright
#
# Copyright 2015 Your name here, unless otherwise noted.
#
class opsscripts (
  $path = $opsscripts::params::path,
) inherits opsscripts::params {

  file { "${path}/backup-mongo.sh":
    ensure => present,
    source => 'puppet:///modules/opsscripts/backup-mongo.sh',
    owner  => 'root',
    mode   => '0755',
  }

  file { "${path}/restore-mongo.sh":
    ensure => present,
    source => 'puppet:///modules/opsscripts/restore-mongo.sh',
    owner  => 'root',
    mode   => '0755',
  }
}
