# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WhittakerTech::Oscar::VerbGenerator do
  let(:host_class) { Class.new }
  let(:taxonomy) do
    WhittakerTech::Oscar::Taxonomy.new(
      initial: :draft,
      states: { draft: {}, published: {} },
      transitions: { publish: { from: :draft, to: :published, past: :published } }
    )
  end

  it 'defines the bang verb and past predicate' do
    described_class.new(host_class, taxonomy).define!

    expect(host_class.method_defined?(:publish!)).to be(true)
    expect(host_class.method_defined?(:published?)).to be(true)
  end

  it 'raises when a transition name is a protected verb' do
    bad_taxonomy = WhittakerTech::Oscar::Taxonomy.new(
      initial: :draft, states: { draft: {}, x: {} },
      transitions: { destroy: { from: :draft, to: :x, past: :destroyed } }
    )

    expect { described_class.new(host_class, bad_taxonomy).define! }
      .to raise_error(WhittakerTech::Oscar::ProtectedVerbError, /protected verb/)
  end

  it 'raises when a declared past form is a protected verb' do
    bad_taxonomy = WhittakerTech::Oscar::Taxonomy.new(
      initial: :draft, states: { draft: {}, x: {} },
      transitions: { go: { from: :draft, to: :x, past: :update } }
    )

    expect { described_class.new(host_class, bad_taxonomy).define! }
      .to raise_error(WhittakerTech::Oscar::ProtectedVerbError, /protected verb/)
  end

  it 'raises when the generated bang verb already exists on the host class' do
    host_class.define_method(:publish!) { :stub }

    expect { described_class.new(host_class, taxonomy).define! }
      .to raise_error(WhittakerTech::Oscar::ProtectedVerbError, /already exists/)
  end

  it 'raises when the generated past predicate already exists on the host class' do
    host_class.define_method(:published?) { :stub }

    expect { described_class.new(host_class, taxonomy).define! }
      .to raise_error(WhittakerTech::Oscar::ProtectedVerbError, /already exists/)
  end

  it 'honors an irregular declared past form rather than inflecting the transition name' do
    irregular = WhittakerTech::Oscar::Taxonomy.new(
      initial: :active, states: { active: {}, aside: {} },
      transitions: { shelve: { from: :active, to: :aside, past: :set_aside } }
    )

    described_class.new(host_class, irregular).define!

    expect(host_class.method_defined?(:shelve!)).to be(true)
    expect(host_class.method_defined?(:set_aside?)).to be(true)
    expect(host_class.method_defined?(:shelved?)).to be(false)
  end
end
