Puppet::Type.type(:svckill).provide(:kill) do

  def initialize(*args)
    super(*args)

    # Services to *always* ignore
    @ignore = [
      'puppet',
      'puppetmaster',
      'crond',
      'sshd',
      'iptables',
      'ip6tables',
      'ebtables',
      # This one is relevant to Upstart-based systems with rc.init
      # compatibility
      'rc'
    ]

    case Facter.value(:osfamily)
    when 'RedHat'
      @ignore += [
        # If this dies, every unused mountpoint gets nuked!
        'amtu',
        'blk-availability',
        # All sorts of bad things could happen here
        'dbus.*',
        # Don't kill the TTYs
        'getty.*',
        'gpm',
        'haldaemon',
        'irqbalance',
        'killall',
        # If this dies, all libvirt-based VMs are turned off.
        # Unfortunately, it also has a 0 error code in most cases
        # so is not a 'service' but a startup/shutdown utility.
        'libvirt-guests',
        'lvm2-monitor',
        'mcstrans',
        'mdmonitor',
        'messagebus',
        # Don't kill X, let runlevel do that for us.
        'prefdm',
        # This is just annoying. Doesn't do anything bad (or good)
        # just annoying.
        'netcf-transaction',
        'netfs',
        'netlabel',
        'network',
        'ntpdate',
        'portreserve',
        'restorecond',
        'sandbox',
        'sysstat',
        'udev-post',
        # These have broken statuses so svckill can't take care of them.
        'krb524',
        'mdmpd',
        'readahead_later',
        'lm_sensors',
        'kudzu'
      ]
    end

    @systemctl = Puppet::Util.which('systemctl')

    # Put together a lookup table for all systemd services that have aliases.
    # This is so that we can prevent nuking a service accidentally by targeting
    # its alias.
    if @systemctl then
      @systemd_aliases = {}

      active_services = Set.new

      %x{#{@systemctl} list-unit-files -t service}.split("\n").each do |x|
        if x =~ /\.service/
          service,state = x.split(/\s+/)
          state.strip!

          next if state == 'static'
          next if service.include?('@')

          active_services << service.strip
         end
      end

      %x{#{@systemctl} show -p Names #{active_services.to_a.join(' ')}}.split("\n").each do |svc_entry|
        next if svc_entry.nil? or svc_entry.empty?

        service_names = svc_entry.split('=').last.split(/\s+/)

        if service_names.size > 1 then
          service_names.each do |s_name|
            @systemd_aliases[s_name] ||= Set.new

            service_names.each do |s_name_alias|
              @systemd_aliases[s_name] << s_name_alias unless s_name_alias == s_name
            end
          end
        end
      end
    end
  end

  def mode
    all_services = @resource.catalog.resources.find_all{|r|
      r.is_a?(Puppet::Type.type(:service))
    }.map{ |x| x = x[:name] }

    # Gather all items to ignore together
    ignore = @ignore
    ignore += Array(@resource[:ignore]).collect{|x| x = x.strip} if @resource[:ignore]

    Array(@resource[:ignorefiles]).each do |ignorefile|
      begin
        if ignorefile and File.readable?(ignorefile) then
          ignore += File.readlines(ignorefile).collect{|x| x = x.strip}
        end
      rescue Exception => e
        Puppet.warning("svckill: Could not read svckill ignore file '#{ignorefile}', skipping: #{e}")
        next
      end
    end

    # Try to make this smart enough to only prod those items that are
    # actually running at this time.  No reason to disable things are
    # are currently disabled.
    @running_services = {}
    Puppet::Type.type('service').instances.each do |obj|
      obj_name = obj[:name]
      obj_name = obj[:name].split('.service').first if obj[:provider] == :systemd

      if Facter.value(:osfamily) == 'RedHat'
        # Skip anything that is a leftover from RPM
        if obj_name =~ /\.rpm(save|new)$/ then
          Puppet.debug("svckill: Ignoring '#{obj_name}' due to being an RPM leftover")
          next
        end
      end

      # This command is what actually checks the service on the
      # Skip anything that we're supposed to ignore
      if ignore.index{|x| Regexp.new("^#{x}$").match(obj_name) } then
        Puppet.debug("svckill: Ignoring '#{obj_name}' due to ignore list")
        next
      end

      # Skip anything that's in the catalog
      # This is a double check in case we're a systemd system
      if all_services.include?(obj_name) or all_services.include?(obj[:name]) then
        Puppet.debug("svckill: Ignoring '#{obj_name}' due to being in the catalog")
        next
      end

      # Skip anything that has a systemd alias and the alias is in the catalog.
      # This prevents svckill from nuking services that have been aliased.
      if @systemctl and @systemd_aliases[obj[:name]] then
        found = false
        @systemd_aliases[obj[:name]].each do |aliased_svc|
          # And, of course, we have to check for both forms again....
          if all_services.include?(aliased_svc) or all_services.include?(aliased_svc.split('.service').first) then
            Puppet.debug("svckill: Ignoring '#{obj_name}' due to being in the catalog")
            found = true
            break
          end
        end

        next if found
      end

      # This is a super hack to get around PUP-2744
      if Facter.value(:osfamily) == 'RedHat' and obj[:provider].eql?(:init) then
        obj[:provider] = :redhat
      end

      Puppet.debug("svckill: Resolving '#{obj_name}'")
      res = obj.to_resource

      # We have to account for traditional, upstart, and systemd services
      # differently.
      if res[:provider].eql?(:upstart) then
        if res[:ensure].eql?(:running) then
          @running_services[obj[:name]] = obj.provider
        end
      elsif [:redhat,:systemd].include?(res[:provider]) then
        if res[:enable].to_s.eql?("true") or res[:ensure].eql?(:running) then
          @running_services[obj[:name]] = {
            :provider => obj.provider,
            :resource => res
          }
        end
      else
        Puppet.warning("The svckill provider does not yet support service provider type #{res[:provider]} for service #{obj_name}")
      end
    end

    return @running_services
  end

  def insync?(is)
    if Puppet[:noop] or @resource[:mode] == 'warning' then
      if @running_services.nil? or @running_services.empty? then
        Puppet.debug("svckill: Would not have killed any services.")
      else
        Puppet.warning("svckill: Would have killed:\n  svckill: #{@running_services.keys.join("\n  svckill: ")}")
      end

      return true
    end

    return @running_services.empty?
  end

  def mode=(should)
    @results = {
      :stopped => {
        :passed => [],
        :failed => []
      },
      :disabled => {
        :passed => [],
        :failed => []
      }
    }

    @running_services.each_key do |svc|
      Puppet.debug("svckill: Attempting to stop service '#{svc}'")

      if @running_services[svc][:resource][:ensure].eql?(:running) then
        begin
          @running_services[svc][:provider].send 'stop'
        rescue Puppet::Error => e
          @results[:stopped][:failed] << svc
        else
          @results[:stopped][:passed] << svc
        end
      end

      if @running_services[svc][:resource][:enable].to_s.eql?('true') then
        begin
          @running_services[svc][:provider].send 'disable'
        rescue Puppet::Error => e
          @results[:disabled][:failed] << svc
        else
          @results[:disabled][:passed] << svc
        end
      end
    end
  end

  def results
    return @results
  end
end
