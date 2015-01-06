# == Class opsscripts::params
#
# This class is meant to be called from opsscripts
# It sets variables according to platform
#
class opsscripts::params {

  case $::kernel {
    'Linux': {
      $path = '/usr/local/bin'
    }
    default: {
      fail("os type ${::kernel} not supported")
    }
  }
}
