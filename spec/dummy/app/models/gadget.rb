# frozen_string_literal: true

# Second host model, sharing state names with Widget, purely to prove T4's
# generated scopes filter by resource_type against the shared oscar_statuses
# table — without it, Widget.published could leak Gadget rows.
class Gadget < ApplicationRecord
  include WhittakerTech::Oscar::Stateful

  oscar_taxonomy(
    base: [],
    initial: :draft,
    states: { draft: {}, published: {} },
    transitions: { publish: { from: :draft, to: :published, past: :published } }
  )
end
