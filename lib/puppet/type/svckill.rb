Puppet::Type.newtype(:svckill) do
  @doc = <<-EOM
    Disables all services (recognized by the 'service' resource)
    that are not defined in your Puppet manifests or listed.

    Any services listed in the $ignorefiles array will be ignored
    for legacy compatibility.

    See the module data to determine what services are ignored by default.
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

  newparam(:verbose, :boolean => true) do
    desc <<-EOM
      If set, output all services that were affected by svckill.
    EOM
    newvalues(:true, :false)

    defaultto :true
  end

  newproperty(:mode) do
    desc <<-EOM
      If set to 'enforcing', will actually shut down and disable all
      services not listed in your manifests or the exclusion file.

      If set to 'warning', will only report on what would happen
      without actually making the changes to the system.

      Default: 'warning'
    EOM

    defaultto 'warning'

    validate do |value|
      unless ['enforcing','warning'].include?("#{value}")
        raise(ArgumentError,"'ensure' must be either 'enforcing' or 'warning'")
      end
    end

    def insync?(is)
      provider.insync?(is)
    end

    def change_to_s(currentvalue, newvalue)
      results = provider.results

      output = []
      err_output = []

      if @resource[:verbose] == :true
        # Ensure that our list of things that svckill is affecting begins on a
        # new line for readability
        output << ""

        unless results[:stopped][:passed].empty?
          output << results[:stopped][:passed].map{|x| x = "Svckill stopped '#{x}'"}.join("\n")
        end
        unless results[:disabled][:passed].empty?
          output << results[:disabled][:passed].map{|x| x = "Svckill disabled '#{x}'"}.join("\n")
        end
      else
        unless results[:stopped][:passed].empty?
          output << "Stopped #{results[:stopped][:passed].count} services"
        end
        unless results[:disabled][:passed].empty?
          output << "Disabled #{results[:disabled][:passed].count} services"
        end
      end

      unless results[:stopped][:failed].empty?
        err_output << results[:stopped][:failed].map{|x| x = "Svckill failed to stop '#{x}'"}.join("\n")
      end

      unless results[:disabled][:failed].empty?
        err_output << 'Failed to disable the following services:'
        err_output << results[:disabled][:failed].map{|x| x = "Svckill failed to disable '#{x}'"}.join("\n")
      end

      unless err_output.empty?
        err_output.each do |kill_err|
          Puppet.warning(kill_err)
        end
      end

      (output + err_output).join("\n")
    end
  end

  autorequire(:file) do
    [self[:ignorefiles]]
  end

  autorequire(:simpcat_build) do
    [self[:ignorefiles]]
  end
end
