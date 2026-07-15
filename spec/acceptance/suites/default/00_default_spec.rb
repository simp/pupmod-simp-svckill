require 'spec_helper_acceptance'

test_name 'svckill'

describe 'Kill Unmanaged Services' do
  hosts.each do |host|
    hieradata = <<-EOM
---

svckill::mode: 'enforcing'
EOM
    # On a fresh node the Sicura console previews this module with
    # `puppet apply --noop`, which must not error. Exercise that here before
    # the enforcing applies below. No package-removal step: svckill installs
    # no package (it reaps unmanaged services), so noop-only is the
    # representative check. A bare `include 'svckill'` (default mode 'warning')
    # is what the console previews for the module class.
    context 'in noop mode from a clean state' do
      it 'applies without errors in noop mode' do
        apply_manifest_on(host, 'include "svckill"', catch_failures: true, noop: true)
      end
    end

    context 'with mode=enforcing' do
      set_hieradata_on(host, hieradata, 'default')

      it 'does not kill the network' do
        result = apply_manifest_on(host, 'include "svckill"', catch_failures: true).stdout
        expect(result).not_to match(%r{stopped.*'network})
      end

      it 'kills Dnsmasq unless declared in a manifest' do
        on(host, 'puppet resource package dnsmasq ensure=installed')
        on(host, 'puppet resource service dnsmasq ensure=running')
        result = apply_manifest_on(host, 'include "svckill"', catch_failures: true).stdout
        expect(result).to match(%r{stopped.*'dnsmasq})
      end

      it 'does not kill Dnsmasq if declared in a manifest' do
        manifest = <<-EOS
          include 'svckill'

          package { 'dnsmasq': ensure => 'present' }
          service { 'dnsmasq': ensure => 'running' }
        EOS

        result = apply_manifest_on(host, manifest, catch_failures: true).stdout
        expect(result).not_to match(%r{stopped.*'dnsmasq})
      end

      it 'does not kill static services' do
        on(host, 'puppet resource package polkit ensure=installed')
        on(host, 'puppet resource service polkit ensure=running')
        result = apply_manifest_on(host, 'include "svckill"', catch_failures: true).stdout
        expect(result).not_to match(%r{stopped.*'polkit})
      end
    end

    context 'with an explicit ignore list' do
      it 'does not kill Dnsmasq' do
        manifest = <<-EOS
          class { 'svckill':
            ignore => ['dnsmasq'],
            mode   => 'enforcing'
          }

          package { 'dnsmasq': ensure => 'present' }
        EOS

        on(host, 'puppet resource service dnsmasq ensure=running')
        result = apply_manifest_on(host, manifest, catch_failures: true).stdout
        expect(result).not_to match(%r{stopped.*'dnsmasq})
      end
    end

    context 'with an ignore file' do
      it 'does not kill Dnsmasq' do
        ignore_file = '/tmp/svckill_ignore'

        manifest = <<-EOS
          class { 'svckill':
            ignore_files => ['#{ignore_file}'],
            mode         => 'enforcing'
          }

          package { 'dnsmasq': ensure => 'present' }
        EOS

        create_remote_file(host, ignore_file, "dnsmasq\n")
        on(host, 'puppet resource service dnsmasq ensure=running')
        result = apply_manifest_on(host, manifest, catch_failures: true).stdout
        expect(result).not_to match(%r{stopped.*'dnsmasq})
      end
    end

    context 'with mode = warning' do
      it 'does not kill Dnsmasq' do
        manifest = <<-EOS
          class { 'svckill': mode => 'warning' }
        EOS

        on(host, 'puppet resource service dnsmasq ensure=running')
        result = apply_manifest_on(host, manifest, catch_failures: true).stdout
        expect(result).not_to match(%r{stopped.*'dnsmasq})
      end
    end
  end
end
