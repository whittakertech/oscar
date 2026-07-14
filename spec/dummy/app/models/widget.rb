# frozen_string_literal: true

# Minimal host model exercising WhittakerTech::Oscar::Stateful for T1/T3
# specs. The Hello Dancer (Package) and WordPress-taxonomy demo scenarios
# belong to T6 — this is intentionally generic.
class Widget < ApplicationRecord
  include WhittakerTech::Oscar::Stateful

  belongs_to :crate, optional: true

  scope :named, ->(name) { where(name: name) }

  oscar_taxonomy(
    initial: :draft,
    states: {
      draft: {},
      published: {},
      trashed: {},
      banned: { locked: true },
      purged: { destroyable: true, locked: true }
    },
    transitions: {
      publish:   { from: :draft,             to: :published, past: :published },
      trash:     { from: %i[draft published], to: :trashed,   past: :trashed },
      restore:   { from: :trashed,            to: :draft,     past: :draft },
      ban:       { from: %i[draft published], to: :banned,    past: :banned },
      # Declared FROM the locked :banned state without escapes_lock, purely so
      # specs can exercise the "locked state blocks a declared-but-non-escaping
      # transition" path without mocking (see stateful_spec.rb).
      revoke_ban: { from: :banned,            to: :purged,    past: :purged },
      reinstate: { from: :banned,             to: :draft,     past: :draft, escapes_lock: true },
      purge:     { from: :trashed,            to: :purged,    past: :purged }
    }
  )
end
