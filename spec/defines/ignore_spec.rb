require 'spec_helper'

describe 'svckill::ignore' do
  context 'supported operating systems' do
    on_supported_os.each do |os, os_facts|
      let(:facts) { os_facts }

      context "on #{os}" do
        let(:title) { 'test' }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to create_concat__fragment("svckill_ignore_#{title}") }
        it { is_expected.to_not create_svckill('svckill') }
      end
    end
  end
end
