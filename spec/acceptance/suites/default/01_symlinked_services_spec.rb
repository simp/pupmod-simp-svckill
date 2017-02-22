require 'spec_helper_acceptance'
require 'json'

test_name 'svckill'

describe 'not kill services which are symlinked to other services' do
  hosts.each do |host|
    # This issue only exists on systemd systems
    next if JSON.load(fact_on(host, 'os', { :json => nil }))['os']['release']['major'] == '6'

    context 'nfs and nfs-server' do
      let(:manifest) {
        <<-EOF
        class { 'svckill':
          verbose => true
        }
        service { 'nfs-server': }
        EOF
      }
      it 'should set up an essential service' do
        # dnsmasq is sometimes still running and triggers svckill
        on host, 'puppet resource service dnsmasq ensure=stopped'
        on host, 'puppet resource package nfs ensure=latest'
        on host, 'puppet resource service nfs ensure=running'
      end
      it 'should run puppet and not kill the application' do
        result = apply_manifest_on(host, manifest, :catch_failures => true).stdout
        (require 'pry'; binding.pry) if ENV['BEAKER_pry'] && ENV['BEAKER_pry'].chomp == 'svckill'

        # svckill/service/systemctl already seems smart enough to treat
        # symlinked services the same as their targets
        expect(result).to_not match(/stopped.*'nfs-server/)
        expect(result).to_not match(/stopped.*'nfs/)
        ### # gssproxy is not symlinked to nfs.service, but will be stopped
        ### # nfs.service -> auth-rpcgss-module.service -> gssproxy.service
        ### expect(result).to_not match(/stopped.*'gssproxy/)
      end
    end

    context 'gdm and display-manager' do
      let(:manifest) {
        <<-EOF
        class { 'svckill':
          verbose => true
        }
        service { 'gdm': }
        EOF
      }
      it 'should set up an essential service' do
        # dnsmasq is sometimes still running and triggers svckill
        on host, 'puppet resource service dnsmasq ensure=stopped'

        on host, 'yum install -y @x11 gdm gnome-shell gnome-session-xsession'
        on host, 'systemctl enable gdm.service --now'

        on host, 'systemctl set-default graphical.target'
        on host, 'systemctl isolate graphical.target'
      end
      it 'should run puppet and not kill the application' do
        result = apply_manifest_on(host, manifest, :catch_failures => true).stdout
        (require 'pry'; binding.pry) if ENV['BEAKER_pry'] && ENV['BEAKER_pry'].chomp == 'svckill'

        expect(result).to_not match(/stopped.*'gdm/)
        expect(result).to_not match(/stopped.*'display-manager/)
      end

    end
  end
end
