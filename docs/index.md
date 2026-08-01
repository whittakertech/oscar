# WhittakerTech::Oscar

**Oscar** is a Rails engine that gives any ActiveRecord model a configurable,
validated lifecycle-visibility state machine — without hand-rolling a state
column, a validation layer, and a history table for every model that needs
one.

States are exclusive, transitions are declared, and nothing changes state
except through a named transition. Oscar owns lifecycle **visibility** only
— `published` is a visibility state; private/public access is a separate
concern that lives entirely outside this engine (see
[Architecture](architecture/) for the boundary).

---

## Key capabilities

- **Declarative taxonomy DSL** — `oscar_taxonomy base: ..., initial: ..., states: {...}, transitions: {...}`
  on any ActiveRecord model, validated eagerly at declaration time
- **Named taxonomy bases** — register reusable presets once
  (`config.bases = { blog_post_visibility: {...} }`) and have models opt in
  by name, or opt out entirely and declare their own from scratch
- **No silent defaults** — `base:` is a required keyword; a model either
  names a registered base or explicitly declares `base: []` (nothing
  inherited). There's no implicit "everyone inherits this by default"
  behavior to accidentally rely on
- **Generated verbs and scopes** — `<transition>!` / `<past>?` methods and a
  named scope per state, derived directly from the taxonomy, with a guard
  against silently overriding an existing method
- **Locked states** — a state can require an explicit `escapes_lock: true`
  transition to leave, and can block `destroy` entirely until
  `destroyable: true`
- **Append-only history** — every transition is a new immutable status card
  (via [Poly::Stack](https://github.com/whittakertech/poly)), not a mutated
  column; history dies with the record on purge, by design (nothing to
  restore once destroyed)
- **Concurrency-safe transitions** — `oscar_transition!` wraps the whole
  read-validate-append sequence in a row-level lock, so two concurrent
  transitions on the same record can't race
- **Cascade via events, not callbacks** — `WhittakerTech::Oscar.on_transition`
  subscribes to a fired `ActiveSupport::Notifications` event inside the same
  transaction as the status-card write; no bespoke per-transition callback
  wiring
- **Any primary key type** — generated scopes work against UUID or bigint
  host models alike

---

## Requirements

| Requirement | Version |
|-------------|---------|
| Ruby        | >= 3.2  |
| Rails       | >= 7.1  |
| PostgreSQL  | required (not optional — history persists via `Poly::Stack` on a polymorphic card table) |
| poly gem    | ~> 1.1  |

---

## Quick look

```ruby
# config/initializers/oscar.rb
WhittakerTech::Oscar.configure do |config|
  config.bases = {
    blog_post_visibility: {
      initial: :draft,
      states: {
        draft: {}, published: {}, archived: {}, trashed: {},
        purged: { destroyable: true, locked: true }
      },
      transitions: {
        publish: { from: :draft,     to: :published, past: :published },
        archive: { from: :published, to: :archived,  past: :archived },
        trash:   { from: %i[draft published archived], to: :trashed, past: :trashed },
        restore: { from: :trashed,   to: :draft,      past: :draft },
        purge:   { from: :trashed,   to: :purged,     past: :purged }
      }
    }
  }
end

# app/models/post.rb
class Post < ApplicationRecord
  include WhittakerTech::Oscar::Stateful

  oscar_taxonomy(base: :blog_post_visibility)
end
```

```ruby
post = Post.create!
post.oscar_state        # => :draft
post.publish!
post.published?         # => true
Post.published          # => generated named scope
post.destroy!           # => raises LockedStateError (draft/published aren't destroyable)
```

---

## Documentation sections

- **[Installation](installation/)** — add the gem, run the install generator, register named bases
- **[Usage](usage/)** — the `oscar_taxonomy` DSL, `base:` resolution rules, generated verbs/scopes, transitions, events
- **[Architecture](architecture/)** — identity and boundary tripwires, taxonomy config schema, protected verbs, history model, concurrency
- **[API Reference](api/)** — full method reference; generated API docs at [`api/WhittakerTech/Oscar`](api/WhittakerTech/Oscar/)
- **[Examples](examples/)** — the blog-post-visibility preset, the Hello Dancer package-retirement scenario, and a from-scratch taxonomy

---

## Why Oscar?

Lifecycle state — draft/published/archived, or any bespoke shape a model
actually needs — is the kind of thing every Rails app eventually
hand-rolls: a `state` column, a scattering of `scope :published, -> { where(...) }`
calls, ad hoc validation for "you can't un-delete a purged record," and no
real history of how a record got to its current state. Oscar makes the
taxonomy explicit and validated up front, generates the boring parts
(verbs, scopes), and keeps a real append-only history — so the model class
only has to declare *what* its lifecycle looks like, not re-implement *how*
one works.
