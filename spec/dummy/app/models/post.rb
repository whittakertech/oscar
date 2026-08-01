# frozen_string_literal: true

# T6 canonical WordPress-taxonomy demo — the exact shape documented in
# docs/design.md's taxonomy config schema section, proven end-to-end:
# draft -> published -> trashed -> purged (locked) -> real destroy.
class Post < ApplicationRecord
  include WhittakerTech::Oscar::Stateful

  oscar_taxonomy(base: :blog_post_visibility)
end
