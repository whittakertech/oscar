# frozen_string_literal: true

# The state-history card. One row per transition ever executed against a
# resource; the most recent row (`is_prime`) is the resource's current state.
# Built on Poly::Stack — see docs/design.md's "State history" section for why
# this is a separate polymorphic table rather than a column on the resource.
#
# Payload-agnostic per Poly::Stack's own design: Oscar adds only `state`
# (the taxonomy state name), `verb` (the transition name that produced this
# card), and `transitioned_at`. No actor/reason column in v0.1 — out of scope.
#
# `resource_role` (from Poly::Role, which Poly::Stack builds on) discriminates
# independent stacks sharing one table — Oscar only ever runs one kind of
# stack per resource, so every card gets the same fixed role.
class WhittakerTech::Oscar::Status < WhittakerTech::Oscar::ApplicationRecord
  LIFECYCLE_ROLE = 'lifecycle'

  belongs_to :resource, polymorphic: true

  include Poly::Joins
  include Poly::Stack

  poly_stack :resource

  attribute :resource_role, :string, default: LIFECYCLE_ROLE

  validates :state, presence: true
  validates :verb, presence: true
  validates :transitioned_at, presence: true
end
