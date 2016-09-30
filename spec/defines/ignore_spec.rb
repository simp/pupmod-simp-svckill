require 'spec_helper'

describe 'svckill::ignore' do

  let(:title) { 'test' }

  it { is_expected.to compile.with_all_deps }
  it { is_expected.to create_simpcat_fragment("svckill_ignore+#{title}.ignore").with_content("#{title}\n") }
  it { is_expected.to create_simpcat_build('svckill_ignore') }
  it { is_expected.to_not create_svckill('svckill') }
end
