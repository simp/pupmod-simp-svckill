require 'spec_helper'

describe 'svckill' do
  context 'supported operating systems' do
    on_supported_os.each do |os, os_facts|
      let(:facts) { os_facts }

      context "on #{os}" do
        before :each do
          # In some test environments (docker containers), systemctl
          # is detected to be present but is not available to this
          # process.  So, to prevent systemctl commands from being
          # called by the svckill provider, mock the method the
          # provider uses to determine if systemctl is available.
          Puppet::Util.stubs(:which).with('systemctl').returns(nil)
        end

        context 'with default parameters' do
          it { is_expected.to compile.with_all_deps }
          it { is_expected.to create_class('svckill') }

          it { is_expected.to create_concat('/usr/local/etc/svckill.ignore') }
          it { is_expected.to create_svckill('svckill').with({
            :mode => 'warning',
            :ignore => ["goferd", "^systemd-nspawn@.*", "systemd-bootchart", "systemd-readahead-collect", "systemd-readahead-drop", "systemd-readahead-replay", "NetworkManager", "NetworkManager-dispatcher", "NetworkManager-wait-online", "microcode", "lvm2-lvmetad", "lvm2-lvmpolld", "lvm2-monitor", "kdump", "tuned", "rsyslog", "rhel-dmesg", "^autovt@.*", "amtu", "blk-availability", "dbus.*", "getty.*", "gpm", "haldaemon", "irqbalance", "killall", "libvirt-guests", "mcstrans", "mdmonitor", "messagebus", "prefdm", "netcf-transaction", "netfs", "netlabel", "network", "ntpdate", "portreserve", "restorecond", "sandbox", "sysstat", "udev-post", "krb524", "mdmpd", "readahead_later", "lm_sensors", "kudzu", "auditd", "puppet", "puppetmaster", "crond", "sshd", "iptables", "ip6tables", "ebtables", "rc", "^pe-.*", "simp_client_bootstrap"],
          })}

          context 'if disabling svckill' do
            let(:params) {{ :enable => false }}

            it { is_expected.to compile.with_all_deps }
            it { is_expected.to_not create_svckill('svckill') }
          end
        end

        context 'using knockout to remove default ignored services' do
          let(:hieradata) { 'no_sshd' }
          it { is_expected.to compile.with_all_deps }
          it { is_expected.to create_class('svckill') }
          it { is_expected.to create_svckill('svckill').with({
            :mode => 'warning',
            :ignore => ["goferd", "^systemd-nspawn@.*", "systemd-bootchart", "systemd-readahead-collect", "systemd-readahead-drop", "systemd-readahead-replay", "NetworkManager", "NetworkManager-dispatcher", "NetworkManager-wait-online", "microcode", "lvm2-lvmetad", "lvm2-lvmpolld", "lvm2-monitor", "kdump", "tuned", "rsyslog", "rhel-dmesg", "^autovt@.*", "amtu", "blk-availability", "dbus.*", "getty.*", "gpm", "haldaemon", "irqbalance", "killall", "libvirt-guests", "mcstrans", "mdmonitor", "messagebus", "prefdm", "netcf-transaction", "netfs", "netlabel", "network", "ntpdate", "portreserve", "restorecond", "sandbox", "sysstat", "udev-post", "krb524", "mdmpd", "readahead_later", "lm_sensors", "kudzu", "auditd", "puppet", "puppetmaster", "crond", "iptables", "ip6tables", "ebtables", "rc", "^pe-.*", "simp_client_bootstrap"],
          })}
        end
      end
    end
  end
end
