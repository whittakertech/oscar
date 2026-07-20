# frozen_string_literal: true

# Bigint-PK host model exercising WhittakerTech::Oscar::Stateful -- see
# db/migrate/20260713220800_create_gizmos.rb for why this exists alongside
# the uuid-PK Widget.
class Gizmo < ApplicationRecord
  include WhittakerTech::Oscar::Stateful

  oscar_taxonomy(
    initial: :draft,
    states: {
      draft: {},
      published: {}
    },
    transitions: {
      publish: { from: :draft, to: :published, past: :published }
    }
  )
end
