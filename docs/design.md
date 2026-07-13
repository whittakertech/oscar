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

```ruby
WhittakerTech::Oscar.configure do |config|
  config.taxonomy = {
    states: {
      draft:     { destroyable: false },
      published: { destroyable: false },
      archived:  { destroyable: false },
      trashed:   { destroyable: false, locked: false },
      purged:    { destroyable: true,  locked: true }
    },
    transitions: {
      publish: { from: :draft,     to: :published, past: :published },
      archive: { from: :published, to: :archived,  past: :archived },
      trash:   { from: %i[draft published archived], to: :trashed, past: :trashed },
      restore: { from: :trashed,   to: :draft,      past: :draft },
      purge:   { from: :trashed,   to: :purged,     past: :purged }
    }
  }

  # Per-model override, merged over the root defaults:
  config.taxonomy_for(Package) = { ... }
end
```

Boot-time validation raises (with an actionable message) on:

- unknown top-level or per-state keys
- unreachable states (no transition ever reaches them)
- transitions referencing undeclared states
- missing declared past-tense forms

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

"Current" = `superseded_by_id.nil? && is_prime?` — real indexable columns, no
JSONB digging. **Decision for v0.1: stack-only** (no denormalized host-table
state column). A denormalized column would add a same-transaction
column/stack-head agreement invariant to spec for no requirement v0.1
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

Sibling-engine concerns (e.g. Aeon) hook Oscar's transition event
independently — each concern registers its own callback; no hook reads
another's output; no hook can halt the set; all hooks run inside the single
DB transaction wrapping the transition, so partial failure rolls back as a
unit. This is **not** literal threads — `Thread.new` gets its own DB
connection and cannot join the parent transaction, breaking atomicity. The
invariant to test is commutativity: shuffling concern-inclusion order must
produce identical outcomes. Hooks must query unscoped or receive the record
directly (default-scope trap — moot given Oscar has no default_scope, but
spec'd anyway as a regression guard).

## Restore is mechanical-only

`restore!` flips state and fires its own event that subscribers *may*
observe, but no engine is obligated to undo anything. Forward cascade
(subtract) and restore are not inverse operations — restore is generative
(it re-creates facts about the future), which is a different, harder problem
than subtraction; that policy belongs to the host app, not Oscar.

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
