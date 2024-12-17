require 'spec_helper_acceptance'
require 'json'

test_name 'svckill'

describe 'not kill services which are symlinked to other services' do
  hosts.each do |host|
    context 'nfs and nfs-server' do
      let(:manifest) do
        <<-EOF
        class { 'svckill':
          verbose => true,
          mode    => 'enforcing'
        }
        service { 'nfs-server': ensure => 'running'}
        EOF
      end

      it 'sets up an essential service' do
        # dnsmasq is sometimes still running and triggers svckill
        on(host, 'puppet resource service dnsmasq ensure=stopped')

        # The change to nfs-utils appears to happen at different releases for
        # CentOS and Oracle.  Just find which one is available and set
        # package to that.
        result = on(host, 'yum list available | grep nfs-utils').stdout
        nfs_package = if result.match?(%r{.*nfs-utils.*})
                        'nfs-utils'
                      else
                        'nfs'
                      end

        on(host, "puppet resource package #{nfs_package} ensure=latest")
        on(host, 'puppet resource service nfs-server ensure=running')
      end

      it 'runs puppet and not kill the application' do
        result = apply_manifest_on(host, manifest, catch_failures: true).stdout
        if ENV.fetch('BEAKER_pry', '').chomp == 'svckill'
          (require 'pry'
           binding.pry)
        end

        # In el7, nfs.service is an alias of nfs-server.service and should not be
        # stopped or disabled
        expect(result).not_to match(%r{stopped.*'nfs-server})
        expect(result).not_to match(%r{stopped.*'nfs.service'})
        expect(result).not_to match(%r{disabled.*'nfs.service'})
        # Without kerberos, this should not be running
        expect(result).to match(%r{stopped.*'gssproxy.service'})
      end
    end

    context 'gdm and display-manager' do
      let(:manifest) do
        <<-EOF
        class { 'svckill':
          verbose => true,
          mode    => 'enforcing'
        }
        service { 'gdm': }
        EOF
      end

      it 'sets up an essential service' do
        if fact_on(host, 'os.name') == 'OracleLinux'
          skip("FIXME: Test can't be run on OracleLinux because it requires physical input at console")
        else
          # dnsmasq is sometimes still running and triggers svckill
          on(host, 'puppet resource service dnsmasq ensure=stopped')
          install_cmd = if fact_on(host, 'os.release.major').to_i < 8
                          'yum install -y @x11 gdm gnome-shell gnome-session-xsession'
                        else
                          'dnf install -y @base-x gdm gnome-shell gnome-session-xsession'
                        end

          on(host, install_cmd)
          host.reboot
          on(host, 'systemctl enable gdm.service --now')
          on(host, 'systemctl set-default graphical.target')
          on(host, 'systemctl isolate graphical.target')
        end
      end

      it 'runs puppet and not kill the application' do
        if fact_on(host, 'os.name') == 'OracleLinux'
          skip("FIXME: Test can't be run on OracleLinux because it requires physical input at console")
        else
          result = apply_manifest_on(host, manifest, catch_failures: true).stdout
          if ENV.fetch('BEAKER_pry', '').chomp == 'svckill'
            (require 'pry'
             binding.pry)
          end
          expect(result).not_to match(%r{stopped.*'gdm})
          expect(result).not_to match(%r{stopped.*'display-manager})
        end
      end
    end
  end
end
