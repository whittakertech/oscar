# Examples

Three real, complete models from Oscar's own dummy test app — not invented
snippets. Each demonstrates a different point on the "how much do I inherit
from a base?" spectrum.

---

## Blog-post visibility — inheriting a named base wholesale

`Post` is an exact match for the `blog_post_visibility` preset (see
[Installation](installation/) for registering it), so it inherits the whole
thing with an empty override:

```ruby
class Post < ApplicationRecord
  include WhittakerTech::Oscar::Stateful

  oscar_taxonomy(base: :blog_post_visibility)
end
```

```ruby
post = Post.create!
post.oscar_state          # => :draft

post.publish!
post.published?           # => true

post.archive!
post.archived?            # => true

post.trash!
post.trashed?             # => true

post.restore!
post.oscar_state          # => :draft   (restore is a plain transition, nothing special-cased)

post.trash!
post.purge!
post.destroy!             # succeeds -- :purged is destroyable: true
```

---

## The Hello Dancer scenario — a custom taxonomy from scratch

`Package` doesn't share `blog_post_visibility`'s shape at all — it has a
`retired` state and no `archived`/`trashed` — so it declares itself from
`base: []`:

```ruby
class Package < ApplicationRecord
  include WhittakerTech::Oscar::Stateful

  has_many :orders

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

A retired `Package` stops taking new orders but persists historically — its
`name` stays locked-until-purge (see [Architecture](architecture/)). No
`publish`/order-placement-style transition is declared *from* `:retired`,
which is what makes "retired rejects a new-order-style transition" true: an
ordinary `UndeclaredTransitionError`, not a special retired-specific guard.

```ruby
package = Package.create!(name: 'Hello Dancer')
package.publish!
package.retire!

package.publish!
# => raises UndeclaredTransitionError
#    ("Package cannot publish from :retired (declared from: [:draft])")

package.destroy!
# => raises LockedStateError -- :retired isn't destroyable: true

package.purge!
package.destroy!          # succeeds now
```

Historical associations (`orders`) stay readable throughout — retiring
never touches them, it only closes off the taxonomy's own transitions.

---

## Locked states and the sanctioned escape hatch

`Widget` demonstrates a locked state (`banned`) that blocks every
transition except one explicitly marked `escapes_lock: true`:

```ruby
class Widget < ApplicationRecord
  include WhittakerTech::Oscar::Stateful

  oscar_taxonomy(
    base: [],
    initial: :draft,
    states: {
      draft: {},
      published: {},
      trashed: {},
      banned: { locked: true },
      purged: { destroyable: true, locked: true }
    },
    transitions: {
      publish:    { from: :draft,             to: :published, past: :published },
      trash:      { from: %i[draft published], to: :trashed,   past: :trashed },
      restore:    { from: :trashed,            to: :draft,     past: :draft },
      ban:        { from: %i[draft published], to: :banned,    past: :banned },
      revoke_ban: { from: :banned,             to: :purged,    past: :purged },
      reinstate:  { from: :banned,             to: :draft,     past: :draft, escapes_lock: true },
      purge:      { from: :trashed,            to: :purged,    past: :purged }
    }
  )
end
```

```ruby
widget = Widget.create!
widget.publish!
widget.ban!
widget.banned?            # => true

widget.trash!
# => raises LockedStateError -- :banned is locked; trash doesn't declare escapes_lock: true

widget.reinstate!         # the one sanctioned exit
widget.oscar_state        # => :draft
```

`revoke_ban` is declared *from* the locked `:banned` state without
`escapes_lock: true` — deliberately, so this taxonomy also demonstrates the
"locked state blocks a declared-but-non-escaping transition" path: calling
`widget.revoke_ban!` from `:banned` raises `LockedStateError` just like
`trash!` does, even though the transition itself is validly declared.

---

See [Usage](usage/) for the full `base:` resolution rules and generated
verb/scope reference, and [Architecture](architecture/) for the design
rationale behind locked states, history, and concurrency.
