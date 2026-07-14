# frozen_string_literal: true

# T6 Hello Dancer scenario: the canonical Poly-versioning case study Oscar
# fixes. A retired Package stops taking new orders but persists
# historically; its name stays locked-until-purge (see docs/design.md).
#
# No `publish`/order-placement-style transition is declared FROM :retired —
# that's what makes "retired rejects a new-order-style transition" true: an
# UndeclaredTransitionError, not a special retired-specific guard.
class Package < ApplicationRecord
  include WhittakerTech::Oscar::Stateful

  has_many :orders

  oscar_taxonomy(
    initial: :draft,
    states: {
      draft: {},
      published: {},
      retired: {},
      purged: { destroyable: true, locked: true }
    },
    transitions: {
      publish: { from: :draft, to: :published, past: :published },
      retire: { from: :published, to: :retired, past: :retired },
      purge: { from: :retired, to: :purged, past: :purged }
    }
  )
end
