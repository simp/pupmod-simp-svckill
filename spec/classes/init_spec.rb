require 'spec_helper'

describe 'svckill' do

  it { is_expected.to compile.with_all_deps }
  it { is_expected.to create_concat_build('svckill_ignore') }
  it { is_expected.to create_svckill('svckill') }

end
