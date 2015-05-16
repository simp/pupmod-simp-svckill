module Puppet
  newtype(:svckill) do
    @doc = <<-EOM
      Disables all services (recognized by the 'service' resource)
      that are not defined in your Puppet manifests or listed.

      Any services listed in the $ignorefiles array will be ignored
      for legacy compatibility.

      The following services are hard coded to never be killed by svckill:
        * amtu
        * blk-availability
        * crond
        * ebtables
        * gpm
        * haldaemon
        * ip6tables
        * iptables
        * irqbalance
        * killall
        * libvirt-guests
        * lvm2-monitor
        * mcstrans
        * mdmonitor
        * messagebus
        * netcf-transaction
        * netfs
        * netlabel
        * network
        * ntpdate
        * portreserve
        * puppet
        * restorecond
        * sandbox
        * sshd
        * sysstat
        * udev-post
        * getty*
        * dbus*

     These are here because their status function is broken
        * krb524
        * mdmpd
        * readahead_later
        * rawdevices
        * lm_sensors
        * kudzu
    EOM

    newparam(:name) do
      desc <<-EOM
        A static name assigned to this type. You can only declare
        this type of resource once in your node scope.
      EOM

      isnamevar

      defaultto 'svckill'

      validate do |value|
        raise(ArgumentError,"Error: $name must be 'svckill'.") unless value == 'svckill'
      end
    end

    newparam(:ignore) do
      desc <<-EOM
        An array of services to never kill. Can also accept a regex.
      EOM
    end

    newparam(:ignorefiles) do
      desc <<-EOM
        An array of files containing a list of services to ignore, one per line.
        Can also accept regexes in the file.
      EOM

      defaultto '/usr/local/etc/svckill.ignore'
    end

    newproperty(:mode) do
      desc <<-EOM
        If set to 'enforcing', will actually shut down and disable all
        services not listed in your manifests or the exclusion file.

        If set to 'warning', will only report on what would happen
        without actually making the changes to the system.

        Default: 'enforcing'
      EOM

      defaultto 'enforcing'

      validate do |value|
        if not ['enforcing','warning'].include?("#{value}") then
          raise(ArgumentError,"'ensure' must be either 'enforcing' or 'warning'")
        end
      end

      def insync?(is)
        provider.insync?(is)
      end 

      def change_to_s(currentvalue, newvalue)
        "Attempted to kill #{currentvalue.keys.count} services"
      end
    end

    autorequire(:file) do
      [self[:ignorefiles]]
    end

    autorequire(:concat_build) do
      [self[:ignorefiles]]
    end
  end
end 
