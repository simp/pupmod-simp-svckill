# Svckill is a system that attempts to run with the security best
# practice that "No unnecessary services should be running on the
# system."
#
# The way svckill works is to fetch all services on the running system
# and then shutdown and disable any that are not declared in a Puppet
# manifest (or ignore list/file) somewhere.
#
# The following services will *never* be killed by svckill:
#   * amtu
#   * blk-availability
#   * crond
#   * ebtables
#   * gpm
#   * haldaemon
#   * ip6tables
#   * iptables
#   * irqbalance
#   * killall
#   * libvirt-guests
#   * lvm2-monitor
#   * mcstrans
#   * mdmonitor
#   * messagebus
#   * netcf-transaction
#   * netfs
#   * netlabel
#   * network
#   * ntpdate
#   * portreserve
#   * puppet
#   * restorecond
#   * sandbox
#   * sshd
#   * sysstat
#   * udev-post
#
# @param ignore [Array(String)] A list of services to never kill.
#
# @param ignore_files [Array(Absolute Path)] A list of files that contain
#   services to never kill, one per line.  You can add your own files here if
#   you wish to use an alternate ignore list. The file specified in
#   `::svckill::ignore::collector::default_ignore_file` will always be used but
#   is fully managed by puppet.
#
# @parm verbose [Boolean] If set, svckill should report on exactly what it
#   attempted to kill. If false, it will only report on the number of services
#   that it attempted to kill.
#
# @author Trevor Vaughan <tvaughan@onyxpoint.com>
#
class svckill (
  $ignore = [],
  $ignore_files = [],
  $verbose = true
){
  validate_array($ignore)
  validate_array($ignore_files)
  if !empty($ignore_files) { validate_re_array($ignore_files,'^/') }

  include '::svckill::ignore::collector'

  svckill { 'svckill':
    ignore      => $ignore,
    ignorefiles => flatten([
      $ignore_files,
      $::svckill::ignore::collector::default_ignore_file
    ]),
    verbose     => $verbose,
    require     => Class['svckill::ignore::collector']
  }
}
