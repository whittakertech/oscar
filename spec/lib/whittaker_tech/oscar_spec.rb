# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WhittakerTech::Oscar do
  it 'has a version number' do
    expect(WhittakerTech::Oscar::VERSION).not_to be_nil
  end

  it 'sets the oscar_ table name prefix' do
    expect(described_class.table_name_prefix).to eq('oscar_')
  end
end
