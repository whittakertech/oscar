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
    table_name = host_class.table_name
    primary_key = host_class.primary_key

    host_class.scope state, lambda {
      matching_ids = WhittakerTech::Oscar::Status.prime
                                                 .where(state: state.to_s, resource_type: resource_type)
                                                 .select(:resource_id)
      # oscar_statuses.resource_id is :string (Poly's own default, so this
      # table works against any host PK convention -- uuid, bigint, etc).
      # Postgres has no implicit uuid=varchar or bigint=varchar comparison
      # operator, so cast the host's own PK to text rather than relying on
      # resource_id's column type to happen to match the host. varchar and
      # text compare natively (no cast needed on the subquery side).
      where("#{table_name}.#{primary_key}::text IN (#{matching_ids.to_sql})")
    }
  end

  def define_all_states_scope!
    host_class.scope :all_states, -> { all }
  end
end
