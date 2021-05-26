require 'spec_helper_acceptance'
require 'json'

test_name 'svckill'

describe 'not kill services which are symlinked to other services' do
  hosts.each do |host|
    # This issue only exists on systemd systems
    os_result = fact_on(host, 'os')
    next if os_result['release']['major'] == '6'

    context 'nfs and nfs-server' do
      let(:manifest) {
        <<-EOF
        class { 'svckill':
          verbose => true,
          mode    => 'enforcing'
        }
        service { 'nfs-server': ensure => 'running'}
        EOF
      }

      it 'should set up an essential service' do
        # dnsmasq is sometimes still running and triggers svckill
        on(host, 'puppet resource service dnsmasq ensure=stopped')

        nfs_package = nil

        # The change to nfs-utils appears to happen at different releases for
        # CentOS and Oracle.  Just find which one is available and set
        # package to that.
        result = on(host, "yum list available | grep nfs-utils").stdout
        if result.match?(/.*nfs-utils.*/)
          nfs_package = 'nfs-utils'
        else
          nfs_package = 'nfs'
        end

        on(host, "puppet resource package #{nfs_package} ensure=latest")
        on(host, "puppet resource service nfs-server ensure=running")
      end

      it 'should run puppet and not kill the application' do
        result = apply_manifest_on(host, manifest, :catch_failures => true).stdout
        (require 'pry'; binding.pry) if ENV.fetch('BEAKER_pry','').chomp == 'svckill'

        # In el7, nfs.service is an alias of nfs-server.service and should not be
        # stopped or disabled
        expect(result).to_not match(/stopped.*'nfs-server/)
        expect(result).to_not match(/stopped.*'nfs.service'/)
        expect(result).to_not match(/disabled.*'nfs.service'/)
        # Without kerberos, this should not be running
        expect(result).to match(/stopped.*'gssproxy.service'/)
      end
    end

    context 'gdm and display-manager' do
      let(:manifest) {
        <<-EOF
        class { 'svckill':
          verbose => true,
          mode    => 'enforcing'
        }
        service { 'gdm': }
        EOF
      }

      it 'should set up an essential service' do
        facts = JSON.load(on(host, 'puppet facts').stdout)
        if facts['values']['os']['name'] == 'OracleLinux'
          skip("FIXME: Test can't be run on OracleLinux because it requires physical input at console")
        else
          # dnsmasq is sometimes still running and triggers svckill
          on(host, 'puppet resource service dnsmasq ensure=stopped')

          install_cmd = nil
          if os_result['release']['major'].to_i < 8
            install_cmd = 'yum install -y @x11 gdm gnome-shell gnome-session-xsession'
          else
            install_cmd = 'dnf install -y @base-x gdm gnome-shell gnome-session-xsession'
          end

          on(host, install_cmd)
          host.reboot
          on(host, 'systemctl enable gdm.service --now')
          on(host, 'systemctl set-default graphical.target')
          on(host, 'systemctl isolate graphical.target')
        end
      end

      it 'should run puppet and not kill the application' do
        facts = JSON.load(on(host, 'puppet facts').stdout)
        if facts['values']['os']['name'] == 'OracleLinux'
          skip("FIXME: Test can't be run on OracleLinux because it requires physical input at console")
        else
          result = apply_manifest_on(host, manifest, :catch_failures => true).stdout
          (require 'pry'; binding.pry) if ENV.fetch('BEAKER_pry','').chomp == 'svckill'
          expect(result).to_not match(/stopped.*'gdm/)
          expect(result).to_not match(/stopped.*'display-manager/)
        end
      end

    end
  end
end
