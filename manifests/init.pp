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
# @param ignore
#   A list of services to never kill
#
# @param ignore_defaults
#   An internal list of embedded services to never kill
#
# @param ignore_files
#   A list of files that contain services to never kill, one per line
#
#   * You can add your own files here if you wish to use an alternate ignore
#     list
#   * The file specified in ``default_ignore_file`` will always be used but is
#     fully managed by puppet
#
# @param verbose
#   Report on exactly what ``svckill`` attempted to kill
#
#   * If ``false``, it will only report on the number of services that it
#     attempted to kill
#
# @param debug
#   Add notify resources to the catalog based on the union of ignore and
#   ignore_defaults. 
#   
#
#
# @author Trevor Vaughan <tvaughan@onyxpoint.com>
#
class svckill (
  Array[String]               $ignore       = [],
  Array[String]               $ignore_defaults = [],
  Array[Stdlib::Absolutepath] $ignore_files = [],
  Boolean                     $verbose      = true,
  Boolean                     $debug        = false
){
  include '::svckill::ignore::collector'
  $combined_ignore_list = $ignore + $ignore_defaults
  if ($debug == true) {
    $combined_ignore_list.each |String $servicename| {
      notify { "svckill::ignore - entry ${servicename}": }
    }
  }
  $flattened_ignore_files = flatten([$ignore_files, $::svckill::ignore::collector::default_ignore_file])
  svckill { 'svckill':
    ignore      => $combined_ignore_list,
    ignorefiles => $flattened_ignore_files,
    verbose     => $verbose,
    require     => Class['svckill::ignore::collector']
  }
}
