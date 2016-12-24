require 'spec_helper'

describe 'svckill' do
  context 'supported operating systems' do
    on_supported_os.each do |os, os_facts|
      let(:facts) { os_facts }

      context "on #{os}" do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to create_class('svckill') }

        it { is_expected.to create_concat('/usr/local/etc/svckill.ignore') }
        it { is_expected.to create_svckill('svckill') }
      end
    end
  end
end
