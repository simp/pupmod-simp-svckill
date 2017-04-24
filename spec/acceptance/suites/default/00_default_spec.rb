require 'spec_helper_acceptance'

test_name 'svckill'

describe 'Kill Unmanaged Services' do
  hosts.each do |host|
    hieradata = <<-EOM
---

svckill::mode: 'enforcing'
EOM
    context 'with mode=enforcing' do
      set_hieradata_on(host, hieradata, 'default')

      it 'should not kill the network' do
        result = apply_manifest_on(host,'include "svckill"', :catch_failures => true).stdout
        expect(result).to_not match(/stopped.*'network/)
      end

      it 'should kill Dnsmasq unless declared in a manifest' do
        on(host, 'puppet resource package dnsmasq ensure=installed')
        on(host, 'puppet resource service dnsmasq ensure=running')
        result = apply_manifest_on(host, 'include "svckill"', :catch_failures => true).stdout
        expect(result).to match(/stopped.*'dnsmasq/)
      end

      it 'should not kill Dnsmasq if declared in a manifest' do
        manifest = <<-EOS
          include 'svckill'

          package { 'dnsmasq': ensure => 'present' }
          service { 'dnsmasq': ensure => 'running' }
        EOS

        result = apply_manifest_on(host, manifest, :catch_failures => true).stdout
        expect(result).to_not match(/stopped.*'dnsmasq/)
      end
    end

    context 'with an explicit ignore list' do
      it 'should not kill Dnsmasq' do
        manifest = <<-EOS
          class { 'svckill':
            ignore => ['dnsmasq'],
            mode   => 'enforcing'
          }

          package { 'dnsmasq': ensure => 'present' }
        EOS

        on(host, 'puppet resource service dnsmasq ensure=running')
        result = apply_manifest_on(host, manifest, :catch_failures => true).stdout
        expect(result).to_not match(/stopped.*'dnsmasq/)
      end
    end

    context 'with an ignore file' do
      it 'should not kill Dnsmasq' do
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
        result = apply_manifest_on(host, manifest, :catch_failures => true).stdout
        expect(result).to_not match(/stopped.*'dnsmasq/)
      end
    end

    context 'with mode = warning' do
      it 'should not kill Dnsmasq' do
        manifest = <<-EOS
          class { 'svckill': mode => 'warning' }
        EOS

        on(host, 'puppet resource service dnsmasq ensure=running')
        result = apply_manifest_on(host, manifest, :catch_failures => true).stdout
        expect(result).to_not match(/stopped.*'dnsmasq/)
      end
    end
  end
end
