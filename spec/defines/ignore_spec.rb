require 'spec_helper'

describe 'svckill::ignore' do

  let(:title) { 'test' }

  it { is_expected.to compile.with_all_deps }
  it { is_expected.to create_concat_fragment("svckill_ignore+#{title}.ignore").with_content("#{title}\n") }
end
