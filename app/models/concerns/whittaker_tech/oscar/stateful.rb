# frozen_string_literal: true

# Include on a host model to give it a taxonomy-driven lifecycle state
# machine. See docs/design.md for the full identity and boundary rules.
#
# @example
#   class Package < ApplicationRecord
#     include WhittakerTech::Oscar::Stateful
#
#     oscar_taxonomy(
#       base: [], # or a Symbol naming a registered WhittakerTech::Oscar.configuration.bases entry
#       initial: :draft,
#       states: {
#         draft: {}, published: {}, trashed: {},
#         purged: { destroyable: true, locked: true }
#       },
#       transitions: {
#         publish: { from: :draft, to: :published, past: :published },
#         trash:   { from: %i[draft published], to: :trashed, past: :trashed },
#         purge:   { from: :trashed, to: :purged, past: :purged }
#       }
#     )
#   end
#
#   package.oscar_transition!(:publish)
#   package.oscar_state          # => :published
#   package.oscar_state?(:published) # => true
#   package.published?           # => true (generated past-tense predicate)
#   Package.published            # => generated named scope
#   Package.all_states           # => escape hatch, no state filter
module WhittakerTech::Oscar::Stateful
  extend ActiveSupport::Concern

  included do
    # Order matters: before_destroy callbacks run in registration order, and
    # `dependent: :destroy` on the association below registers its own
    # before_destroy cleanup callback. Declaring the guard FIRST ensures it
    # checks the current state while status cards still exist — otherwise
    # the association's cleanup would delete them first, and the guard would
    # see no cards and fall back to the taxonomy's :initial state instead of
    # the record's real (possibly non-destroyable) current state.
    before_destroy :oscar_guard_destroy!

    has_many :oscar_statuses,
             as: :resource,
             class_name: 'WhittakerTech::Oscar::Status',
             dependent: :destroy

    # Stamps a real status card for the taxonomy's :initial state immediately
    # on creation, rather than leaving "current state" as a pure in-memory
    # fallback (see `oscar_state` below). Without this, a freshly-created
    # record has zero oscar_statuses rows and is invisible to every
    # ScopeGenerator-built scope — including its own initial state's scope.
    after_create :oscar_stamp_initial_state!
  end

  class_methods do
    # Declares this model's taxonomy, deep-merged over the resolved `base:`.
    # `base:` is required — no default — and resolves to a plain hash before
    # being passed as `Taxonomy.deep_merge`'s base argument:
    # * a registered Symbol (looked up in
    #   WhittakerTech::Oscar.configuration.bases) → that base's hash, or
    #   raises WhittakerTech::Oscar::UnknownBaseError if unregistered
    # * +nil+, <tt>[]</tt>, or <tt>{}</tt> → blank (+{}+, nothing inherited)
    # * anything else → raises ArgumentError before `deep_merge` is ever
    #   reached
    #
    # Raises WhittakerTech::Oscar::InvalidTaxonomyError immediately on any
    # malformed merged shape, then generates `<transition>!`/`<past>?`
    # methods (raising WhittakerTech::Oscar::ProtectedVerbError on any unsafe
    # collision — see WhittakerTech::Oscar::VerbGenerator) and a named scope
    # per state (see WhittakerTech::Oscar::ScopeGenerator). There is no
    # lazy/deferred validation or generation.
    def oscar_taxonomy(base:, **hash)
      merged = WhittakerTech::Oscar::Taxonomy.deep_merge(oscar_resolve_taxonomy_base(base), hash)
      taxonomy = WhittakerTech::Oscar::Taxonomy.new(merged)
      WhittakerTech::Oscar::VerbGenerator.new(self, taxonomy).define!
      WhittakerTech::Oscar::ScopeGenerator.new(self, taxonomy).define!
      @oscar_taxonomy_config = taxonomy
    end

    def oscar_taxonomy_config
      @oscar_taxonomy_config || raise(WhittakerTech::Oscar::Error, "#{name} has not declared oscar_taxonomy")
    end

    private

    def oscar_resolve_taxonomy_base(base)
      case base
      when Symbol
        WhittakerTech::Oscar.configuration.bases.fetch(base) do
          raise WhittakerTech::Oscar::UnknownBaseError,
                "unknown taxonomy base #{base.inspect} (not registered in WhittakerTech::Oscar.configuration.bases)"
        end
      when nil, [], {}
        {}
      else
        raise ArgumentError,
              "oscar_taxonomy base: must be a registered Symbol, nil, [], or {} (blank) — got #{base.inspect}"
      end
    end
  end

  # The record's current state, resolved from its most recent status card, or
  # the taxonomy's :initial state if no transition has ever been executed.
  # @return [Symbol]
  def oscar_state
    oscar_statuses.prime.first&.state&.to_sym || self.class.oscar_taxonomy_config.initial
  end

  # @return [Boolean] whether the record's current state is +name+
  def oscar_state?(name)
    oscar_state == name.to_sym
  end

  # Executes a declared transition, appending a new status card.
  #
  # Wraps the whole read-validate-append sequence in `with_lock` (row-level
  # `SELECT ... FOR UPDATE`) so two concurrent transitions on the same record
  # can't race Poly::Stack's prime-demotion and produce two primes or an
  # interleaved `superseded_by_id` chain — see docs/design.md's Concurrency
  # section. A losing writer re-reads the winner's already-applied state
  # under the lock and raises the ordinary undeclared-transition error rather
  # than double-applying.
  #
  # @param name [Symbol, String] the declared transition name
  # @raise [WhittakerTech::Oscar::UndeclaredTransitionError] if +name+ isn't
  #   declared, or the record's current state isn't in its +from+ list
  # @raise [WhittakerTech::Oscar::LockedStateError] if the current state is
  #   locked and this transition doesn't declare `escapes_lock: true`
  # @return [WhittakerTech::Oscar::Status] the newly created status card
  #
  # Fires WhittakerTech::Oscar::TRANSITION_EVENT (see
  # WhittakerTech::Oscar.on_transition) from inside the same `with_lock`
  # transaction as the card creation above — a subscriber raising rolls back
  # the card along with every other subscriber's writes from this call.
  def oscar_transition!(name)
    with_lock do
      taxonomy = self.class.oscar_taxonomy_config
      transition = taxonomy.transition(name)
      current = oscar_state

      oscar_assert_transition_from!(transition, name, current)
      oscar_assert_not_locked!(taxonomy, transition, current, name)

      card = oscar_statuses.create!(state: transition[:to].to_s, verb: name.to_s, transitioned_at: Time.current)
      WhittakerTech::Oscar.instrument_transition(self, from: current, to: transition[:to], verb: name)
      card
    end
  end

  private

  def oscar_stamp_initial_state!
    initial = self.class.oscar_taxonomy_config.initial
    oscar_statuses.create!(state: initial.to_s, verb: 'initialize', transitioned_at: Time.current)
  end

  # Inbound protection: `destroy`/`destroy!` (including a parent's
  # `dependent: :destroy`) raises unless the current state is marked
  # `destroyable: true`. `destroy` stays lethal, but only from states the
  # taxonomy explicitly marks destroyable — the taxonomy lock is the safety,
  # not method aliasing (see docs/design.md's Protected verbs section).
  def oscar_guard_destroy!
    return if self.class.oscar_taxonomy_config.destroyable?(oscar_state)

    raise WhittakerTech::Oscar::LockedStateError,
          "#{self.class} cannot be destroyed from state #{oscar_state.inspect} (not destroyable: true)"
  end

  def oscar_assert_transition_from!(transition, name, current)
    return if transition[:from].include?(current)

    raise WhittakerTech::Oscar::UndeclaredTransitionError,
          "#{self.class} cannot #{name} from #{current.inspect} " \
          "(declared from: #{transition[:from].inspect})"
  end

  def oscar_assert_not_locked!(taxonomy, transition, current, name)
    return unless taxonomy.locked?(current) && !transition[:escapes_lock]

    raise WhittakerTech::Oscar::LockedStateError,
          "#{self.class} state #{current.inspect} is locked; " \
          "#{name} does not declare escapes_lock: true"
  end
end
