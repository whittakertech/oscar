# Usage

## The `oscar_taxonomy` macro

Include the concern and declare a taxonomy on any ActiveRecord model:

```ruby
class Package < ApplicationRecord
  include WhittakerTech::Oscar::Stateful

  oscar_taxonomy(
    base: [],
    initial: :draft,
    states: {
      draft: {},
      published: {},
      retired: {},
      purged: { destroyable: true, locked: true }
    },
    transitions: {
      publish: { from: :draft,     to: :published, past: :published },
      retire:  { from: :published, to: :retired,   past: :retired },
      purge:   { from: :retired,   to: :purged,     past: :purged }
    }
  )
end
```

This validates the merged shape immediately (`InvalidTaxonomyError` on any
problem — unknown keys, an unreachable state, a transition missing `:to`,
etc.), then generates verbs and scopes. There's no lazy or deferred
validation: a broken taxonomy fails at class-load time, not on first use.

---

## The `base:` keyword

`base:` is a **required** keyword — omitting it is Ruby's own
`ArgumentError` for a missing keyword, not a custom guard. There's no
default, silent or otherwise: every model states explicitly what it
inherits, if anything.

`base:` accepts:

- **A registered `Symbol`** — resolves via `WhittakerTech::Oscar.configuration.bases`,
  deep-merged under your override, key-by-key per state/transition. An
  override redeclaring a state or transition wins for that entry only;
  sibling entries from the base survive untouched.
  ```ruby
  oscar_taxonomy(base: :blog_post_visibility)   # inherits the whole preset, no override
  ```
  An unregistered symbol raises `UnknownBaseError`, naming the bad symbol,
  before any merge or validation is attempted.

- **`nil`, `[]`, or `{}`** — blank. Nothing inherited; your `states`/
  `transitions`/`initial` *are* the entire taxonomy.
  ```ruby
  oscar_taxonomy(base: [], initial: :trialing, states: { ... }, transitions: { ... })
  ```

- **Anything else** (an unsupported type) — `ArgumentError`, raised before
  `deep_merge` is ever reached.

**Merging is additive only.** A base can be added to, never subtracted
from — there's no way to say "give me `blog_post_visibility` minus
`archived`." A model that doesn't share a base's exact shape declares its
own taxonomy from `base: []` instead (see `Package`/`Widget` above and in
[Examples](examples/)).

---

## Generated verbs

For every declared transition, Oscar generates two methods on the host
class:

| Declaration | Generated |
|---|---|
| `publish: { ..., past: :published }` | `#publish!` — executes the transition |
| same | `#published?` — `true` once the record reached that state |

Past forms are **exactly what you declare** — never auto-inflected. Irregular
English (`set_aside`, not `set_asided`) makes automatic inflection unsafe,
so `past:` is required on every transition.

```ruby
package.publish!
package.published?   # => true
```

A transition name or declared past form that collides with a protected verb
(`destroy`/`delete`/`update`), or with a method that already exists on the
host class, raises `ProtectedVerbError` at declaration time — Oscar never
silently overrides an existing method.

---

## Generated scopes

One named scope per declared state, plus an `all_states` escape hatch:

```ruby
Package.published    # records currently in :published
Package.all_states    # no state filter at all
```

Scopes are filtered by both `resource_type` and `state` against the shared
`oscar_statuses` table, so `Package.published` can never leak another
model's rows even though every Oscar-managed model shares one physical
table. There is no `default_scope` — an un-scoped `Package.all` still
returns every record regardless of state.

---

## Reading state

```ruby
package.oscar_state          # => :draft  (the taxonomy's :initial state, before any transition)
package.oscar_state?(:draft) # => true
```

`oscar_state` resolves from the record's most recent status card, falling
back to the taxonomy's `:initial` only if no transition has ever fired (in
practice this fallback rarely triggers — `oscar_taxonomy` stamps a real
initial-state card on `after_create`, so a fresh record already has one).

---

## Executing transitions

```ruby
card = package.oscar_transition!(:publish)
card.state         # => "published"
card.verb          # => "publish"
card.transitioned_at
```

`oscar_transition!` wraps the whole read-validate-append sequence in
`with_lock` (a row-level `SELECT ... FOR UPDATE`), so two concurrent
transitions on the same record can't race each other into two "current"
states. It raises:

- **`UndeclaredTransitionError`** — the name isn't declared, or the record's
  current state isn't in that transition's `from:` list
- **`LockedStateError`** — the current state is locked and this transition
  doesn't declare `escapes_lock: true`

---

## Locked states

```ruby
states: {
  banned: { locked: true }
},
transitions: {
  ban:       { from: %i[draft published], to: :banned, past: :banned },
  reinstate: { from: :banned, to: :draft,  past: :draft, escapes_lock: true }
}
```

A locked state blocks every transition out of it **except** one explicitly
declaring `escapes_lock: true` — the sanctioned exit. Attempting any other
transition from a locked state raises `LockedStateError`.

---

## Destroy guard

```ruby
states: {
  draft: {},
  purged: { destroyable: true, locked: true }
}
```

`destroy`/`destroy!` (including a parent's `dependent: :destroy`) raises
`LockedStateError` unless the record's current state is marked
`destroyable: true`. The taxonomy is the safety mechanism here — not method
aliasing — so `destroy` itself stays the real, lethal Rails method; it's
just guarded.

---

## Cascading on a transition

```ruby
WhittakerTech::Oscar.on_transition do |payload|
  # payload => { resource_gid:, from:, to:, verb: }
  next unless payload[:to] == :published

  NotifyFollowersJob.perform_later(payload[:resource_gid])
end
```

One generic `WhittakerTech::Oscar::TRANSITION_EVENT` fires per
`oscar_transition!`, regardless of verb name — there's no special-cased
"restore" event; restore is just a regular transition like any other. It
fires from inside the *same* `with_lock` transaction as the status-card
write, so a subscriber raising rolls back the card along with every other
subscriber's writes from that call.

---

## Errors reference

| Error | Raised when |
|---|---|
| `InvalidTaxonomyError` | A malformed taxonomy shape, at declaration time |
| `UndeclaredTransitionError` | An unknown transition name, or the current state isn't in its `from:` list |
| `LockedStateError` | A transition blocked by a locked state, or `destroy` from a non-destroyable state |
| `ProtectedVerbError` | A transition/past name collides with `destroy`/`delete`/`update`, or an existing method |
| `UnknownBaseError` | `base:` names a `Symbol` not registered in `config.bases` |

See [Architecture](architecture/) for the full taxonomy config schema and
validation rules, and [Examples](examples/) for complete worked models.
