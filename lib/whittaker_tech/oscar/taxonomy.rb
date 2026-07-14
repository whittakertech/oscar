# frozen_string_literal: true

# A validated, immutable taxonomy: the set of declared states and transitions
# for one host model (or the root defaults). See docs/design.md for the full
# schema. All shape errors raise WhittakerTech::Oscar::InvalidTaxonomyError at
# construction time — there is no such thing as a partially-valid Taxonomy.
class WhittakerTech::Oscar::Taxonomy
  ALLOWED_TOP_KEYS = %i[initial states transitions].freeze
  ALLOWED_STATE_KEYS = %i[destroyable locked].freeze
  ALLOWED_TRANSITION_KEYS = %i[from to past escapes_lock].freeze

  attr_reader :initial, :states, :transitions

  # Deep-merges a per-model override over root defaults: states and
  # transitions are merged key-by-key (an override redeclaring a state or
  # transition wins for that entry, but leaves sibling entries from the base
  # untouched), rather than the override wholesale-replacing the base hash.
  def self.deep_merge(base, override)
    base = (base || {}).transform_keys(&:to_sym)
    override = (override || {}).transform_keys(&:to_sym)

    {
      initial: override[:initial] || base[:initial],
      states: merge_hash(base[:states], override[:states]),
      transitions: merge_hash(base[:transitions], override[:transitions])
    }
  end

  def self.merge_hash(base, override)
    base = symbolize(base)
    override = symbolize(override)

    base.merge(override) { |_key, old_val, new_val| symbolize(old_val).merge(symbolize(new_val)) }
  end
  private_class_method :merge_hash

  def self.symbolize(hash)
    (hash || {}).transform_keys(&:to_sym)
  end
  private_class_method :symbolize

  def initialize(hash)
    hash = (hash || {}).transform_keys(&:to_sym)
    validate_top_level_keys!(hash)

    @initial = hash[:initial]&.to_sym
    @states = normalize_states(hash[:states] || {})
    @transitions = normalize_transitions(hash[:transitions] || {})

    validate!
  end

  def state?(name)
    states.key?(name.to_sym)
  end

  def destroyable?(state_name)
    states.fetch(state_name.to_sym).fetch(:destroyable)
  end

  def locked?(state_name)
    states.fetch(state_name.to_sym).fetch(:locked)
  end

  def transition?(name)
    transitions.key?(name.to_sym)
  end

  def transition(name)
    transitions.fetch(name.to_sym) do
      raise WhittakerTech::Oscar::UndeclaredTransitionError, "no transition named #{name.inspect} is declared"
    end
  end

  private

  def validate_top_level_keys!(hash)
    unknown = hash.keys - ALLOWED_TOP_KEYS
    raise WhittakerTech::Oscar::InvalidTaxonomyError, "unknown taxonomy keys: #{unknown.inspect}" if unknown.any?
  end

  def normalize_states(states)
    states.transform_keys(&:to_sym).each_with_object({}) do |(name, opts), acc|
      opts = (opts || {}).transform_keys(&:to_sym)
      unknown = opts.keys - ALLOWED_STATE_KEYS
      if unknown.any?
        raise WhittakerTech::Oscar::InvalidTaxonomyError, "state #{name.inspect} has unknown keys: #{unknown.inspect}"
      end

      acc[name.to_sym] = { destroyable: opts.fetch(:destroyable, false), locked: opts.fetch(:locked, false) }
    end
  end

  def normalize_transitions(transitions)
    transitions.transform_keys(&:to_sym).each_with_object({}) do |(name, opts), acc|
      acc[name] = normalize_transition(name, opts)
    end
  end

  def normalize_transition(name, opts)
    opts = self.class.send(:symbolize, opts)
    validate_transition_keys!(name, opts)

    {
      from: extract_transition_from!(name, opts),
      to: extract_transition_field!(name, opts, :to),
      past: extract_transition_field!(name, opts, :past),
      escapes_lock: opts.fetch(:escapes_lock, false)
    }
  end

  def validate_transition_keys!(name, opts)
    unknown = opts.keys - ALLOWED_TRANSITION_KEYS
    return if unknown.empty?

    raise WhittakerTech::Oscar::InvalidTaxonomyError,
          "transition #{name.inspect} has unknown keys: #{unknown.inspect}"
  end

  def extract_transition_from!(name, opts)
    from = Array(opts[:from]).map(&:to_sym)
    raise WhittakerTech::Oscar::InvalidTaxonomyError, "transition #{name.inspect} is missing :from" if from.empty?

    from
  end

  def extract_transition_field!(name, opts, field)
    value = opts[field]&.to_sym
    raise WhittakerTech::Oscar::InvalidTaxonomyError, "transition #{name.inspect} is missing :#{field}" unless value

    value
  end

  def validate!
    raise WhittakerTech::Oscar::InvalidTaxonomyError, 'taxonomy declares no states' if states.empty?
    raise WhittakerTech::Oscar::InvalidTaxonomyError, 'taxonomy declares no transitions' if transitions.empty?
    raise WhittakerTech::Oscar::InvalidTaxonomyError, 'taxonomy declares no :initial state' unless initial

    unless state?(initial)
      raise WhittakerTech::Oscar::InvalidTaxonomyError, "initial state #{initial.inspect} is not a declared state"
    end

    validate_transitions_reference_declared_states!
    validate_states_reachable!
  end

  def validate_transitions_reference_declared_states!
    transitions.each do |name, transition|
      (transition[:from] + [transition[:to]]).each do |state|
        next if state?(state)

        raise WhittakerTech::Oscar::InvalidTaxonomyError,
              "transition #{name.inspect} references undeclared state #{state.inspect}"
      end
    end
  end

  def validate_states_reachable!
    reachable = transitions.values.to_set { |t| t[:to] }
    reachable << initial
    unreachable = states.keys - reachable.to_a

    return if unreachable.empty?

    raise WhittakerTech::Oscar::InvalidTaxonomyError,
          "states unreachable by any transition or :initial: #{unreachable.inspect}"
  end
end
