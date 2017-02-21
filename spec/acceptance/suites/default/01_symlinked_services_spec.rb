require 'spec_helper_acceptance'
require 'json'

test_name 'svckill'

describe 'Not kill services which are symlinked to other services' do
  hosts.each do |host|
    let(:manifest) {
      <<-EOF
      include 'svckill'
      service { 'httpd': }
      EOF
    }
    # This issue only exists on systemd systems
    next if JSON.load(fact_on(host, 'os', { :json => nil }))['os']['release']['major'] == '6'
    context 'default parameters' do
      it 'should set up an essential service' do
        on host, ('puppet resource package httpd ensure=latest')
        on host, ('puppet resource service httpd ensure=running')
        on host, ('curl localhost')
      end
      it 'should create a symlink to that service' do
        on host, ('ln -s /usr/lib/systemd/system/httpd.service /usr/lib/systemd/system/apache.service')
      end
      it 'should run puppet and not kill the application' do
        result = apply_manifest_on(host, manifest, :catch_failures => true).stdout
        expect(result).to_not match(/stopped.*'apache/)
        on host, ('curl localhost')
      end

    end
  end
end
