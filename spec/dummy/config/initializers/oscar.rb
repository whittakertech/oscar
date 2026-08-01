# frozen_string_literal: true

# Registers the blog_post_visibility named base so Post's
# `oscar_taxonomy(base: :blog_post_visibility)` resolves — the gem itself
# pre-registers nothing (see docs/design.md's Named bases section).
WhittakerTech::Oscar.configure do |config|
  config.bases = {
    blog_post_visibility: {
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
    }
  }
end
