# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WhittakerTech::Oscar::Stateful do
  let(:widget) { Widget.create!(name: 'thing') }

  describe '#oscar_state' do
    it 'resolves to the taxonomy initial state before any transition' do
      expect(widget.oscar_state).to eq(:draft)
      expect(widget.oscar_state?(:draft)).to be(true)
    end

    it 'resolves to the most recent transition after one fires' do
      widget.oscar_transition!(:publish)

      expect(widget.oscar_state).to eq(:published)
    end
  end

  describe '#oscar_transition!' do
    it 'appends a status card recording the transition' do
      expect { widget.oscar_transition!(:publish) }.to change { widget.oscar_statuses.count }.by(1)

      card = widget.oscar_statuses.prime.first
      expect(card.state).to eq('published')
      expect(card.verb).to eq('publish')
      expect(card.transitioned_at).to be_present
    end

    it 'raises for an undeclared transition name' do
      expect { widget.oscar_transition!(:nonexistent) }
        .to raise_error(WhittakerTech::Oscar::UndeclaredTransitionError, /no transition named/)
    end

    it "raises when the current state isn't in the transition's :from list" do
      widget.oscar_transition!(:publish)
      widget.oscar_transition!(:trash)

      expect { widget.oscar_transition!(:publish) }
        .to raise_error(WhittakerTech::Oscar::UndeclaredTransitionError, /cannot publish from :trashed/)
    end

    it 'allows a declared escapes_lock transition out of a locked state' do
      widget.oscar_transition!(:ban)

      expect { widget.oscar_transition!(:reinstate) }.not_to raise_error
      expect(widget.oscar_state).to eq(:draft)
    end

    it 'raises LockedStateError for a transition declared from a locked state without escapes_lock' do
      widget.oscar_transition!(:ban)

      expect { widget.oscar_transition!(:revoke_ban) }
        .to raise_error(WhittakerTech::Oscar::LockedStateError, /is locked/)
    end
  end

  describe 'generated verbs' do
    it 'round-trips a transition through its bang verb and past-tense predicate' do
      expect(widget.published?).to be(false)

      widget.publish!

      expect(widget.published?).to be(true)
      expect(widget.oscar_state).to eq(:published)
    end
  end

  describe 'destroy guard' do
    it 'raises when destroying from a non-destroyable state' do
      expect { widget.destroy! }.to raise_error(WhittakerTech::Oscar::LockedStateError, /not destroyable/)
      expect(Widget.exists?(widget.id)).to be(true)
    end

    it 'allows destroy from a destroyable state' do
      widget.oscar_transition!(:trash)
      widget.oscar_transition!(:purge)

      expect { widget.destroy! }.not_to raise_error
      expect(Widget.exists?(widget.id)).to be(false)
    end

    it "fails a parent's dependent: :destroy against a live (non-destroyable) child" do
      crate = Crate.create!(name: 'box')
      widget.update!(crate: crate)

      expect { crate.destroy! }.to raise_error(WhittakerTech::Oscar::LockedStateError)
      expect(Widget.exists?(widget.id)).to be(true)
    end

    it "succeeds a parent's dependent: :destroy against a purge-eligible child" do
      crate = Crate.create!(name: 'box')
      widget.update!(crate: crate)
      widget.oscar_transition!(:trash)
      widget.oscar_transition!(:purge)

      expect { crate.destroy! }.not_to raise_error
      expect(Widget.exists?(widget.id)).to be(false)
    end
  end

  describe 'concurrency' do
    # Real cross-connection threads need the row actually committed, which
    # RSpec's default per-example transaction rollback prevents other
    # connections from seeing. Disable it for just this group and clean up
    # manually.
    self.use_transactional_tests = false

    after do
      WhittakerTech::Oscar::Status.delete_all
      Widget.delete_all
    end

    it 'serializes concurrent transitions on one record to exactly one prime card' do
      widget.oscar_transition!(:publish)

      errors = []
      threads = Array.new(2) do
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            Widget.find(widget.id).oscar_transition!(:trash)
          rescue StandardError => e
            errors << e
          end
        end
      end
      threads.each(&:join)

      widget.reload
      expect(widget.oscar_statuses.where(is_prime: true).count).to eq(1)
      expect(widget.oscar_state).to eq(:trashed)
      expect(errors).to all(be_a(WhittakerTech::Oscar::UndeclaredTransitionError))
      expect(errors.size).to eq(1)
    end
  end

  describe '.oscar_taxonomy base: keyword' do
    let(:host_class) do
      Class.new(ApplicationRecord) do
        self.table_name = 'widgets'
        include WhittakerTech::Oscar::Stateful
      end
    end

    let(:blog_post_visibility) do
      {
        initial: :draft,
        states: { draft: {}, published: {}, purged: { destroyable: true, locked: true } },
        transitions: {
          publish: { from: :draft, to: :published, past: :published },
          purge: { from: :published, to: :purged, past: :purged }
        }
      }
    end

    after { WhittakerTech::Oscar.reset_configuration! }

    it 'resolves a registered Symbol base identically to declaring that shape inline' do
      WhittakerTech::Oscar.configure { |config| config.bases = { blog_post_visibility: blog_post_visibility } }

      host_class.oscar_taxonomy(base: :blog_post_visibility)
      taxonomy = host_class.oscar_taxonomy_config

      expect(taxonomy.initial).to eq(:draft)
      expect(taxonomy.states.keys).to contain_exactly(:draft, :published, :purged)
      expect(taxonomy.transition(:publish)[:to]).to eq(:published)
    end

    it 'produces only the override states/transitions when base: is blank ([])' do
      host_class.oscar_taxonomy(
        base: [],
        initial: :trialing,
        states: { trialing: {}, active: {} },
        transitions: { activate: { from: :trialing, to: :active, past: :active } }
      )

      taxonomy = host_class.oscar_taxonomy_config
      expect(taxonomy.states.keys).to contain_exactly(:trialing, :active)
    end

    it 'treats nil and {} as blank identically to []' do
      [nil, {}].each do |blank|
        klass = Class.new(ApplicationRecord) do
          self.table_name = 'widgets'
          include WhittakerTech::Oscar::Stateful
        end
        klass.oscar_taxonomy(
          base: blank,
          initial: :a,
          states: { a: {}, b: {} },
          transitions: { go: { from: :a, to: :b, past: :went } }
        )

        expect(klass.oscar_taxonomy_config.states.keys).to contain_exactly(:a, :b)
      end
    end

    it 'raises UnknownBaseError naming the bad symbol, before any Taxonomy.new call' do
      expect { host_class.oscar_taxonomy(base: :typo_name) }
        .to raise_error(WhittakerTech::Oscar::UnknownBaseError, /typo_name/)
    end

    it 'raises ArgumentError for an unsupported base: type' do
      expect { host_class.oscar_taxonomy(base: 'blog_post_visibility') }
        .to raise_error(ArgumentError, /base:/)
    end

    it 'raises ArgumentError when base: is omitted entirely' do
      expect { host_class.oscar_taxonomy(initial: :draft, states: { draft: {} }, transitions: {}) }
        .to raise_error(ArgumentError, /base/)
    end
  end
end
