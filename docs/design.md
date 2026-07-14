# Oscar — Design

## Identity

Oscar owns lifecycle visibility; nothing else. Oscar is a configurable
lifecycle-state engine — WordPress-shaped (`draft`, `published`, `archived`,
`trashed`, `purged`) but taxonomy-driven per model. States are exclusive;
transitions are declared; nothing changes state except through a named
transition. `published` is a visibility state (Oscar's). Private vs public is
an *access* state (Solomon/Leeloo's) that only matters if also `published` —
access is conditional on visibility and lives entirely outside this engine.
Poly versions; Oscar retires. Oscar stamps state and does not know who reads
it.

## Boundary tripwires (reject in review)

- An `audience:` or `visibility_for:` key in taxonomy config — that's Solomon's
  job, not Oscar's.
- A `superseded:` / versioning state — that's Poly's job. Oscar must never
  grow a supersede state; that would build versioning twice (see the
  Subscribify PlanSet ADR).
- Any `default_scope` — see Scopes-as-tabs below.
- Any per-actor logic anywhere in this engine.

## Taxonomy config schema (v0.1)

A boring, well-validated hash in `config/initializers/oscar.rb` — root-level
defaults plus per-model overrides. No DSL in v0.1; a DSL is only extracted
once two engines actually consume the hash.

Root defaults live in `config/initializers/oscar.rb`:

```ruby
WhittakerTech::Oscar.configure do |config|
  config.taxonomy = {
    initial: :draft,
    states: {
      draft:     {},
      published: {},
      archived:  {},
      trashed:   {},
      purged:    { destroyable: true, locked: true }
    },
    transitions: {
      publish: { from: :draft,     to: :published, past: :published },
      archive: { from: :published, to: :archived,  past: :archived },
      trash:   { from: %i[draft published archived], to: :trashed, past: :trashed },
      restore: { from: :trashed,   to: :draft,      past: :draft },
      purge:   { from: :trashed,   to: :purged,     past: :purged }
    }
  }
end
```

Per-model overrides are declared on the host model itself, via the
`oscar_taxonomy` class macro from `WhittakerTech::Oscar::Stateful` — not a
global registry keyed by class name (which would fight Rails autoloading: a
model class object isn't a stable, always-loaded key at initializer-run
time). The macro deep-merges its hash over the root defaults, key-by-key per
state/transition, and validates immediately:

```ruby
class Package < ApplicationRecord
  include WhittakerTech::Oscar::Stateful

  oscar_taxonomy states: { retired: { destroyable: true } },
                 transitions: { retire: { from: %i[draft published], to: :retired, past: :retired } }
end
```

A transition may also declare `escapes_lock: true` to be the sanctioned exit
from an otherwise-locked state (e.g. a `reinstate` transition off a locked
`banned` state) — see Concurrency/lock enforcement in `Oscar::Stateful`
below. Boot-time validation (`WhittakerTech::Oscar::Taxonomy.new`, raising
`InvalidTaxonomyError`) rejects: unknown top-level or per-state/per-transition
keys, an undeclared `:initial` state, transitions referencing undeclared
states, states unreachable via `:initial` or any transition's `:to`, and any
transition missing its declared `:past` form.

Declared past forms are **required in config**, not inflected automatically —
irregular English (`set_aside`, not `set_asided`) makes automatic inflection
unsafe.

## Protected verbs

`destroy`, `delete`, and `update` may never be generated or overridden by the
verb generator; Oscar raises at include/config time (`method_defined?` guard).
Inbound protection is separate: `before_destroy` raises unless the record's
current state has `destroyable: true` — so `dependent: :destroy` from a parent
association can never silently hard-delete a live (non-purge-eligible)
record. `destroy` stays lethal, but only from states the taxonomy explicitly
marks destroyable; the taxonomy lock is the safety, not method aliasing.

## State history (Poly::Stack)

State history persists on a separate polymorphic card table
(`oscar_statuses`) via `Poly::Stack`, not by mutating a column on the host
row:

```ruby
class WhittakerTech::Oscar::Status < WhittakerTech::Oscar::ApplicationRecord
  belongs_to :resource, polymorphic: true
  include Poly::Joins
  include Poly::Stack
  poly_stack :resource
end
```

`WhittakerTech::Oscar::Stateful` (the host concern) declares
`has_many :oscar_statuses, as: :resource, dependent: :destroy` and exposes
`oscar_state` (resolves from `oscar_statuses.prime.first&.state`, falling
back to the taxonomy's `:initial` when no transition has fired yet),
`oscar_state?(name)`, and `oscar_transition!(name)` (validates the declared
transition, then appends a card). "Current" = `superseded_by_id.nil? &&
is_prime?` — real indexable columns, no JSONB digging. **Decision for v0.1:
stack-only** (no denormalized host-table state column). A denormalized
column would add a same-transaction column/stack-head agreement invariant to
spec for no requirement v0.1
actually has; the fork stays documented here for later if scope-query
performance ever demands it.

### History disposal on purge

A real `destroy` fired from a purge-eligible state must not orphan
`oscar_statuses` rows. **Decision: history dies with the record** — the host
concern declares `has_many :oscar_statuses, as: :resource, dependent:
:destroy`. The host row is the uniqueness anchor (a locked-until-purge name
frees only when the row itself is destroyed); a status row surviving past
purge would silently break that invariant for anything that ever checked name
occupancy via the status table instead of the host table. Tombstone/audit
history that survives purge is Argus/audit territory, not Oscar's.

## Uniqueness: locked-until-purge

Plain unique indexes on host-table attributes (e.g. `name`) are legal as-is:
a name frees only when the terminal-state (purge-eligible) row is actually
destroyed. No partial-index machinery, no name-reuse config flag in v0.1 —
documented fork for later: a model that needs name-reuse-while-history-persists
would need state denormalized to a host column plus a partial index, or
validation-only enforcement, gated by a per-taxonomy config flag.

## Cascade: independent registered callbacks

Implemented via `ActiveSupport::Notifications` (`WhittakerTech::Oscar::TRANSITION_EVENT`,
fired by `WhittakerTech::Oscar.instrument_transition` — see
`lib/whittaker_tech/oscar/events.rb`). Every `oscar_transition!` call fires
exactly ONE generic event, from inside the same `with_lock` transaction that
appended the status card:

```ruby
WhittakerTech::Oscar.on_transition do |payload|
  # payload => { resource_gid:, from:, to:, verb: }
  record = GlobalID::Locator.locate(payload[:resource_gid])
  # ...
end
```

Sibling-engine concerns (e.g. Aeon) hook this event independently — each
concern registers its own subscriber via `on_transition`; no hook reads
another's output; no hook can halt the set for reasons other than raising.
Because instrumentation happens inside the transition's own transaction, a
raise in ANY subscriber rolls back that subscriber's writes AND the status
card AND every other subscriber's writes from the same call — atomicity by
construction, not by explicit rollback code. This is **not** literal
threads — `Thread.new` gets its own DB connection and cannot join the
parent transaction, breaking atomicity. The invariant to test is
commutativity: registering subscribers in either order must produce
identical final state (each subscriber's effect must be independent of the
others', per the ADR). Payload is deliberately GID + state symbols + verb —
no domain data, no live record reference — so subscribers resolve the
record themselves (`GlobalID::Locator.locate`) and should query unscoped
once resolved (default-scope trap — moot given Oscar has no default_scope,
but spec'd anyway as a regression guard).

## Restore is mechanical-only

There is no special-cased "restore" event or transition type — `restore` is
just whatever transition name a taxonomy declares for reversing a state
(e.g. `trashed → draft`). It fires the exact same generic
`TRANSITION_EVENT` as every other transition, with `verb: :restore` (or
whatever name was used). Subscribers *may* observe it, but no engine is
obligated to undo anything, and Oscar itself never inspects the verb to
decide whether to auto-cascade anything — "mechanical-only" holds by
construction, not by a runtime special case. Forward cascade (subtract) and
restore are not inverse operations — restore is generative (it re-creates
facts about the future), which is a different, harder problem than
subtraction; that policy belongs to the host app, not Oscar.

## Scopes-as-tabs

One table. Oscar generates a named scope per taxonomy state on the **host**
class (e.g. `Package.trashed`, `Package.published`), for admin UI (Spectra/
host) to render as tabs from the taxonomy config. Since `oscar_statuses` is
polymorphic and shared across every Oscar-managed model, every generated
scope filters on **both** `resource_type` and `state`:

```ruby
scope :trashed, -> {
  where(id: WhittakerTech::Oscar::Status.prime
                                         .where(state: 'trashed', resource_type: name)
                                         .select(:resource_id))
}
```

Implemented by `WhittakerTech::Oscar::ScopeGenerator` (generates one scope per
declared state, plus an `all_states` escape hatch that ignores state
entirely) at the same `oscar_taxonomy` declaration time as verb generation.
Omitting `resource_type` is semantically wrong — the subquery would return IDs
from every Oscar-managed model, not just this host class — even though UUID
collision across models is practically impossible. `NO default_scope`
anywhere; visibility filtering is explicit scopes plus Solomon resolution, not
implicit query scoping. Per-tab counts (WordPress `Trash (14)`) are a
host/Clio concern, not Oscar's.

## Concurrency

Transition execution wraps the read-validate-append sequence in
`record.with_lock` (row-level `SELECT ... FOR UPDATE` inside the transaction).
Without it, two concurrent transitions on the same record can race
`Poly::Stack`'s prime-demotion (`before_create`/`after_create`) across two
connections and produce two primes or an interleaved `superseded_by_id`
chain. The lock wraps the whole transition, not just the card insert, so a
losing writer sees the winner's already-applied state and raises the
ordinary undeclared-transition error rather than double-applying.
