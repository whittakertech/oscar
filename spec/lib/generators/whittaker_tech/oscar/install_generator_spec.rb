# frozen_string_literal: true

require 'rails_helper'
require 'rails/generators/testing/behavior'
require 'rails/generators/testing/setup_and_teardown'
require 'generators/whittaker_tech/oscar/install/install_generator'

RSpec.describe WhittakerTech::Oscar::InstallGenerator do
  include Rails::Generators::Testing::Behavior
  include Rails::Generators::Testing::SetupAndTeardown
  include FileUtils

  tests described_class
  destination File.expand_path('../../../../../tmp/install_generator', __dir__)

  before { prepare_destination }

  it 'creates a config/initializers/oscar.rb registering bases via the new API' do
    run_generator

    generated_path = File.join(destination_root, 'config/initializers/oscar.rb')
    expect(File).to exist(generated_path)

    content = File.read(generated_path)
    expect(content).to include('config.bases')
    expect(content).not_to include('config.taxonomy')
  end

  it 'produces a syntactically valid initializer' do
    run_generator

    content = File.read(File.join(destination_root, 'config/initializers/oscar.rb'))
    expect { RubyVM::InstructionSequence.compile(content) }.not_to raise_error
  end
end
