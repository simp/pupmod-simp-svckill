require 'spec_helper'

describe 'svckill::ignore' do

  let(:title) { 'test' }

  it { should compile.with_all_deps }
  it { should create_concat_fragment("svckill_ignore+#{title}.ignore").with_content("#{title}\n") }
end
