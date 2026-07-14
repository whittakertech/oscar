# frozen_string_literal: true

# Generates a named scope per taxonomy state on the host class
# (`Package.trashed`, `Package.published`), plus an `all_states` escape
# hatch, at `oscar_taxonomy` declaration time. See docs/design.md's
# "Scopes-as-tabs" section.
#
# `oscar_statuses` is a single polymorphic table shared by every
# Oscar-managed model, so every generated scope filters on BOTH
# `resource_type` and `state` — filtering on `state` alone would return IDs
# from every Oscar-managed model, not just this host class.
#
# Deliberately NEVER calls `default_scope` — see the scopes-as-tabs ADR.
class WhittakerTech::Oscar::ScopeGenerator
  def initialize(host_class, taxonomy)
    @host_class = host_class
    @taxonomy = taxonomy
  end

  def define!
    taxonomy.states.each_key { |state| define_state_scope!(state) }
    define_all_states_scope!
  end

  private

  attr_reader :host_class, :taxonomy

  def define_state_scope!(state)
    resource_type = host_class.name

    host_class.scope state, lambda {
      where(id: WhittakerTech::Oscar::Status.prime
                                            .where(state: state.to_s, resource_type: resource_type)
                                            .select(:resource_id))
    }
  end

  def define_all_states_scope!
    host_class.scope :all_states, -> { all }
  end
end
