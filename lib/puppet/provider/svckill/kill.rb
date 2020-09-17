Puppet::Type.type(:svckill).provide(:kill) do

  def initialize(*args)
    super(*args)

    @systemctl = Puppet::Util.which('systemctl')
    # Put together a lookup table for all systemd services that have aliases.
    # This is so that we can prevent nuking a service accidentally by targeting
    # its alias.
    if @systemctl
      @systemd_aliases = []

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

      active_services.each do |svc|
        begin
          # Collect all active service names and aliases
          svc_entries = (%x{#{@systemctl} show -p Names #{svc}}).split('=').last.split(/\s+/)
          # If name returns more than one service entry, the service has an alias
          if svc_entries.count > 1
            @systemd_aliases << svc_entries
          end

        # Service units cannot always be found. Skip them if they can't.
        rescue Exception => e
          Puppet.debug("svckill: #{e.message}")
          next
        end
      end
      @systemd_aliases.flatten!
      @systemd_aliases.uniq!
    end
  end

  def mode
    all_services = @resource.catalog.resources.find_all{|r|
      r.is_a?(Puppet::Type.type(:service))
    }.map{ |x| x = x[:name] }

    # Gather all items to ignore together
    if @resource[:ignore]
      ignore = Array(@resource[:ignore]).collect{|x| x = x.strip}
      Puppet.debug(
        'svckill: ignore list from `:ignore` ' +
        "(#{@resource[:ignore].size} entries):\n" +
        %Q[#{@resource[:ignore].map{|x| "  - '#{x}'"}.join("\n")}]
      )
    end

    Array(@resource[:ignorefiles]).each do |ignorefile|
      begin
        if ignorefile && File.readable?(ignorefile)
          _ignorefile_list = File.readlines(ignorefile).collect{|x| x = x.strip}
          _ignorefile_list.reject!{|x| x =~ /^#/}
          ignore += _ignorefile_list
          Puppet.debug(
            "svckill: ignore list from `:ignorefile` '#{ignorefile}' " +
            "(#{_ignorefile_list.size} entries):\n" +
            %Q[#{_ignorefile_list.map{|x| "  - '#{x}'"}.join("\n")}]
          )

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

      if Facter.value(:os)['family'] == 'RedHat'
        # Skip anything that is a leftover from RPM
        if obj_name =~ /\.rpm(save|new)$/
          Puppet.debug("svckill: Ignoring '#{obj_name}' due to being an RPM leftover")
          next
        end
      end

      # This command is what actually checks the service on the
      # Skip anything that we're supposed to ignore
      if ignore.index{|x| Regexp.new("^#{x}$").match(obj_name) }
        Puppet.debug("svckill: Ignoring '#{obj_name}' due to ignore list")
        next
      end

      # Skip anything that's in the catalog
      # This is a double check in case we're a systemd system
      if all_services.include?(obj_name) || all_services.include?(obj[:name])
        Puppet.debug("svckill: Ignoring '#{obj_name}' due to being in the catalog")
        next
      end

      # Skip anything that has a systemd alias and the alias is in the catalog.
      # This prevents svckill from nuking services that have been aliased.
      if @systemctl && @systemd_aliases.include?(obj[:name])
        found = false
        @systemd_aliases.each do |aliased_svc|
          # And, of course, we have to check for both forms again....
          if all_services.include?(aliased_svc) || all_services.include?(aliased_svc.split('.service').first)
            Puppet.debug("svckill: Ignoring #{aliased_svc} due to being in the catalog")
            found = true
            break
          end
        end

        next if found
      end

      # This is a super hack to get around PUP-2744
      if Facter.value(:os)['family'] == 'RedHat' && obj[:provider].eql?(:init)
        obj[:provider] = :redhat
      end

      Puppet.debug("svckill: Resolving '#{obj_name}'")
      res = obj.to_resource

      # We have to account for traditional, upstart, and systemd services
      # differently.
      if res[:provider].eql?(:upstart)
        if res[:ensure].eql?(:running)
          @running_services[obj[:name]] = obj.provider
        end
      elsif [:redhat,:systemd].include?(res[:provider])
        if res[:enable].to_s.eql?("true") || res[:ensure].eql?(:running)
          add_service = false
          if  !obj.provider.respond_to?(:cached_enabled?)
            #  If the service is not systemd it will not respond to cached_enabled and it is ok to
            #  add it.
            add_service = true
          else
            # If it is a systemd service check the enabled state.  Kill only enabled or diabled
            # services.  Killing others can cause system errors.
            # One version of puppet agent returns a Hash (v5.5.20) all
            # others return a string
            cached_enabled_value = obj.provider.cached_enabled?
            obj_enabled = cached_enabled_value
            obj_enabled = cached_enabled_value[:output] if cached_enabled_value.is_a?(Hash)
            add_service = true if ['enabled', 'disabled'].include?(obj_enabled)
          end
          if add_service
            @running_services[obj[:name]] = {
              :provider => obj.provider,
              :resource => res
            }
          else
            Puppet.debug("svckill: Ignoring  #{obj[:name]} because it is not enabled|disabled")
          end
        end
      else
        Puppet.warning("The svckill provider does not yet support service provider type #{res[:provider]} for service #{obj_name}")
      end
    end
    return @running_services
  end

  def insync?(is)
    if Puppet[:noop] || @resource[:mode] == 'warning'
      if @running_services.nil? || @running_services.empty?
        Puppet.debug("svckill: Would not have killed any services.")
      else
        Puppet.warning("svckill: Would have killed:\n  svckill: #{@running_services.keys.join("\n  svckill: ")}")
      end

      return true
    end

    return @running_services.nil? || @running_services.empty?
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

      if @running_services[svc][:resource][:ensure].eql?(:running)
        begin
          @running_services[svc][:provider].send 'stop'
        rescue Puppet::Error => e
          @results[:stopped][:failed] << svc
        else
          @results[:stopped][:passed] << svc
        end
      end

      if @running_services[svc][:resource][:enable].to_s.eql?('true')
        begin
          @running_services[svc][:provider].send 'disable'
        rescue Puppet::Error => e
          @results[:disabled][:failed] << svc
        else
          @results[:disabled][:passed] << svc
        end
      end

      # Need to clean this up since the report rendering call to `to_yaml`
      # can't handle values that are symbols
      #
      # Additionally, this just becomes garbage that gets carried along by the
      # catalog for no real reason.
      @running_services[svc][:provider] = nil
      @running_services[svc][:resource] = nil
      @running_services[svc] = nil
    end

    @running_services = nil
  end

  def results
    return @results
  end
end
