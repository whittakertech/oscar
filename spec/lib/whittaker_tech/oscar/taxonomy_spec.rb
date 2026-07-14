# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WhittakerTech::Oscar::Taxonomy do
  let(:wordpress_shaped) do
    {
      initial: :draft,
      states: {
        draft: {}, published: {}, archived: {}, trashed: {},
        purged: { destroyable: true, locked: true }
      },
      transitions: {
        publish: { from: :draft, to: :published, past: :published },
        archive: { from: :published, to: :archived, past: :archived },
        trash: { from: %i[draft published archived], to: :trashed, past: :trashed },
        restore: { from: :trashed, to: :draft, past: :draft },
        purge: { from: :trashed, to: :purged, past: :purged }
      }
    }
  end

  let(:minimal_two_state) do
    {
      initial: :draft,
      states: { draft: {}, published: {} },
      transitions: { publish: { from: :draft, to: :published, past: :published } }
    }
  end

  it 'loads a WordPress-shaped taxonomy' do
    taxonomy = described_class.new(wordpress_shaped)

    expect(taxonomy.initial).to eq(:draft)
    expect(taxonomy.state?(:purged)).to be(true)
    expect(taxonomy.destroyable?(:purged)).to be(true)
    expect(taxonomy.locked?(:purged)).to be(true)
    expect(taxonomy.destroyable?(:draft)).to be(false)
  end

  it 'loads a minimal two-state taxonomy' do
    taxonomy = described_class.new(minimal_two_state)

    expect(taxonomy.states.keys).to contain_exactly(:draft, :published)
    expect(taxonomy.transition(:publish)[:to]).to eq(:published)
  end

  it 'raises on an unknown top-level key' do
    expect { described_class.new(minimal_two_state.merge(audience: :public)) }
      .to raise_error(WhittakerTech::Oscar::InvalidTaxonomyError, /unknown taxonomy keys/)
  end

  it 'raises on an unknown per-state key' do
    bad = minimal_two_state.deep_dup
    bad[:states][:draft] = { visibility_for: :everyone }

    expect { described_class.new(bad) }
      .to raise_error(WhittakerTech::Oscar::InvalidTaxonomyError, /unknown keys/)
  end

  it 'raises on an unknown per-transition key' do
    bad = minimal_two_state.deep_dup
    bad[:transitions][:publish][:superseded] = true

    expect { described_class.new(bad) }
      .to raise_error(WhittakerTech::Oscar::InvalidTaxonomyError, /unknown keys/)
  end

  it 'raises when a transition references an undeclared state' do
    bad = minimal_two_state.deep_dup
    bad[:transitions][:archive] = { from: :published, to: :archived, past: :archived }

    expect { described_class.new(bad) }
      .to raise_error(WhittakerTech::Oscar::InvalidTaxonomyError, /undeclared state/)
  end

  it 'raises when a state is unreachable via :initial or any transition' do
    bad = minimal_two_state.deep_dup
    bad[:states][:orphaned] = {}

    expect { described_class.new(bad) }
      .to raise_error(WhittakerTech::Oscar::InvalidTaxonomyError, /unreachable/)
  end

  it 'raises when a transition is missing its declared :past form' do
    bad = minimal_two_state.deep_dup
    bad[:transitions][:publish].delete(:past)

    expect { described_class.new(bad) }
      .to raise_error(WhittakerTech::Oscar::InvalidTaxonomyError, /missing :past/)
  end

  it 'raises when :initial is missing' do
    bad = minimal_two_state.except(:initial)

    expect { described_class.new(bad) }
      .to raise_error(WhittakerTech::Oscar::InvalidTaxonomyError, /no :initial state/)
  end

  it 'raises when :initial references an undeclared state' do
    bad = minimal_two_state.merge(initial: :nonexistent)

    expect { described_class.new(bad) }
      .to raise_error(WhittakerTech::Oscar::InvalidTaxonomyError, /not a declared state/)
  end

  describe '.deep_merge' do
    it 'merges states and transitions key-by-key over the base' do
      base = { initial: :draft, states: { draft: {}, published: {} },
               transitions: { publish: { from: :draft, to: :published, past: :published } } }
      override = { states: { retired: { destroyable: true } },
                   transitions: { retire: { from: :published, to: :retired, past: :retired } } }

      merged = described_class.deep_merge(base, override)

      expect(merged[:states].keys).to contain_exactly(:draft, :published, :retired)
      expect(merged[:transitions].keys).to contain_exactly(:publish, :retire)
      expect(merged[:initial]).to eq(:draft)
    end

    it 'lets an override redeclare a base state without losing sibling states' do
      base = { states: { draft: { locked: false }, published: {} } }
      override = { states: { draft: { locked: true } } }

      merged = described_class.deep_merge(base, override)

      expect(merged[:states][:draft]).to eq(locked: true)
      expect(merged[:states][:published]).to eq({})
    end
  end
end
