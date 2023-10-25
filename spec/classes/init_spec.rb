require 'spec_helper'
require 'pry'

describe 'svckill' do
  context 'supported operating systems' do
    on_supported_os.each do |os, os_facts|
      context "on #{os}" do
        let(:facts) { os_facts.merge({:virtual => 'kvm' })}

        let(:common_list) { [ "auditd", "crond", "puppet", "puppetmaster", "rngd", "sshd", "^pe-.*", "simp_client_bootstrap"] }
        let(:common_list_without_sshd) { common_list - ['sshd'] }
        let(:kvm_virtual_list) { [ "ovirt-guest-agent", "qemu-guest-agent"] }
        let(:vmware_virtual_list) { [ "vmtoolsd"] }
        let(:redhat_family_list) { [ "dbus.*", "getty.*", "irqbalance","gpm", "messagebus", "libvirt-guests", "blk-availability","lvm2-lvmetad", "lvm2-lvmpolld", "lvm2-monitor", "mdmonitor", "mcstrans", "ntpdate", "netcf-transaction", "netlabel", "portreserve", "restorecond", "sysstat", "prefdm", "krb524", "mdmpd", "readahead_later", "lm_sensors"] }
        let(:redhat_os_list) { [ "^rhsm*"] }
        let(:redhat_6_list) { ["amtu", "haldaemon", "udev-post", "netfs", "sandbox", "killall", "iptables", "ip6tables", "ebtables", "network", "NetworkManager", "rc" ]}
        let(:redhat_7_list) {["goferd",  "iptables", "ip6tables", "ebtables","firewalld", "nftables", "NetworkManager", "NetworkManager-dispatcher", "NetworkManager-wait-online","network","rc", "^systemd-nspawn@.*", "systemd-bootchart", "systemd-readahead-collect", "systemd-readahead-drop", "systemd-readahead-replay", "microcode", "kdump", "rsyslog", "rhel-autorelabel-mark", "rhel-autorelabel", "rhel-configure","rhel-dmesg","rhel-import-state","rhel-loadmodules","rhel-readonly","selinuxfsrelabel", "^autovt@.*", "sandbox"]}
        let(:redhat_8_list) {[ "chronyd", "rndg", "firewalld", "nftables", "ebtables", "NetworkManager", "NetworkManager-dispatcher", "NetworkManager-wait-online", "^systemd-nspawn@.*", "microcode", "loadmodules", "kdump", "rsyslog", "selinux-autorelabel-mark", "timedatex", "^autovt@.*",]}

        before :each do
          # In some test environments (docker containers), systemctl
          # is detected to be present but is not available to this
          # process.  So, to prevent systemctl commands from being
          # called by the svckill provider, mock the method the
          # provider uses to determine if systemctl is available.
          Puppet::Util.stubs(:which).with('systemctl').returns(nil)
        end

        context "with default parameters on major release #{os_facts[:os][:release][:major]}" do
          it { is_expected.to compile.with_all_deps }
          it { is_expected.to create_class('svckill') }

          it { is_expected.to create_concat('/usr/local/etc/svckill.ignore') }
          it {
            case facts[:os][:name]
            when "RedHat"
              extra_list = redhat_os_list
            else
              extra_list = []
            end
            if facts[:os][:release][:major].to_i >= 8
              expected_ignore_list = redhat_8_list + redhat_family_list + extra_list + kvm_virtual_list + common_list
            else
              expected_ignore_list = redhat_7_list + redhat_family_list + extra_list + kvm_virtual_list + common_list
            end
            is_expected.to create_svckill('svckill').with({
              :mode => 'warning',
              :ignore => expected_ignore_list
            })
          }

          context 'if disabling svckill' do
            let(:params) {{ :enable => false }}

            it { is_expected.to compile.with_all_deps }
            it { is_expected.to_not create_svckill('svckill') }
          end
        end

        context 'using knockout to remove default ignored services' do
          let(:hieradata) { 'no_sshd' }
          let(:facts) { os_facts.merge({:virtual => 'virtualbox' })}
          it { is_expected.to compile.with_all_deps }
          it { is_expected.to create_class('svckill') }
          it {
            case facts[:os][:name]
            when "RedHat"
              extra_list = redhat_os_list
            else
              extra_list = []
            end
            if facts[:os][:release][:major].to_i >= 8
              expected_ignore_list = redhat_8_list + redhat_family_list + extra_list +  common_list_without_sshd
            else
              expected_ignore_list = redhat_7_list + redhat_family_list + extra_list +  common_list_without_sshd
            end
            is_expected.to create_svckill('svckill').with({
              :mode => 'warning',
              :ignore => expected_ignore_list
            })
          }
        end

      end
    end
  end
end
