# frozen_string_literal: true

# Generates `<transition>!` and `<past>?` instance methods on a host class
# from its taxonomy, at `oscar_taxonomy` declaration time (i.e. include/config
# time — see docs/design.md's Protected verbs section). Raises
# WhittakerTech::Oscar::ProtectedVerbError rather than generating or
# overriding anything unsafe.
class WhittakerTech::Oscar::VerbGenerator
  PROTECTED_VERBS = %w[destroy delete update].freeze

  def initialize(host_class, taxonomy)
    @host_class = host_class
    @taxonomy = taxonomy
  end

  def define!
    taxonomy.transitions.each do |name, transition|
      define_bang_verb!(name)
      define_past_predicate!(transition[:past], transition[:to])
    end
  end

  private

  attr_reader :host_class, :taxonomy

  def define_bang_verb!(name)
    guard_protected_verb!(name)
    method_name = :"#{name}!"
    guard_existing_method!(method_name)

    host_class.define_method(method_name) { oscar_transition!(name) }
    record_generated!(method_name)
  end

  def define_past_predicate!(past, to_state)
    guard_protected_verb!(past)
    method_name = :"#{past}?"
    guard_existing_method!(method_name)

    host_class.define_method(method_name) { oscar_state?(to_state) }
    record_generated!(method_name)
  end

  def guard_protected_verb!(verb)
    return unless PROTECTED_VERBS.include?(verb.to_s)

    raise WhittakerTech::Oscar::ProtectedVerbError,
          "#{verb.inspect} is a protected verb (destroy/delete/update) and cannot be used " \
          'as a transition name or declared past form'
  end

  # Redeclaring the identical taxonomy on a class re-runs `define!` and would
  # otherwise trip on its own previously-generated methods (this legitimately
  # happens under Rails class reloading in development). Only a method Oscar
  # did NOT generate itself counts as a real collision.
  def guard_existing_method!(method_name)
    return if generated_methods.include?(method_name)
    return unless host_class.method_defined?(method_name) || host_class.private_method_defined?(method_name)

    raise WhittakerTech::Oscar::ProtectedVerbError,
          "#{host_class}##{method_name} already exists and would be overridden by Oscar's verb generation"
  end

  def generated_methods
    host_class.instance_variable_get(:@oscar_generated_verb_methods) || []
  end

  def record_generated!(method_name)
    host_class.instance_variable_set(:@oscar_generated_verb_methods, generated_methods + [method_name])
  end
end
