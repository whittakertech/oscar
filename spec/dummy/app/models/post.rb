# frozen_string_literal: true

# T6 canonical WordPress-taxonomy demo — the exact shape documented in
# docs/design.md's taxonomy config schema section, proven end-to-end:
# draft -> published -> trashed -> purged (locked) -> real destroy.
class Post < ApplicationRecord
  include WhittakerTech::Oscar::Stateful

  oscar_taxonomy(
    initial: :draft,
    states: {
      draft: {},
      published: {},
      archived: {},
      trashed: {},
      purged: { destroyable: true, locked: true }
    },
    transitions: {
      publish: { from: :draft, to: :published, past: :published },
      archive: { from: :published, to: :archived, past: :archived },
      trash: { from: %i[draft published archived], to: :trashed, past: :trashed },
      restore: { from: :trashed, to: :draft, past: :draft },
      purge: { from: :trashed, to: :purged, past: :purged }
    }
  )
end
