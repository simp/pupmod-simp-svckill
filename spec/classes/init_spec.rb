require 'spec_helper'

describe 'svckill' do

  it { should compile.with_all_deps }
  it { should create_concat_build('svckill_ignore') }
  it { should create_svckill('svckill') }

end
