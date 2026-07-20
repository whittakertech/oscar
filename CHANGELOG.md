# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Internal v0.1 engine — no RubyGems publish; tag/publish is a separate go/no-go.

### Added
- Engine skeleton, CI (RSpec/RuboCop/Brakeman/bundler-audit against
  `postgres-hatchery`), install generator.
- `WhittakerTech::Oscar::Taxonomy`: validated, immutable taxonomy config
  (states, declared transitions, `:initial`, `destroyable`/`locked` flags).
  `WhittakerTech::Oscar.configure` for root-level defaults; `oscar_taxonomy`
  class macro for per-model overrides, deep-merged over the root.
- `WhittakerTech::Oscar::Stateful`: `oscar_state`/`oscar_state?`/
  `oscar_transition!`, backed by `WhittakerTech::Oscar::Status`
  (Poly::Stack on a polymorphic `oscar_statuses` table). Transition
  execution wraps the whole read-validate-append sequence in `with_lock`
  for concurrency safety.
- `WhittakerTech::Oscar::VerbGenerator`: `<transition>!`/`<past>?` methods
  generated from the taxonomy, raising `ProtectedVerbError` on any unsafe
  collision (`destroy`/`delete`/`update`, or a pre-existing method).
  `before_destroy` guard raises `LockedStateError` unless the current state
  is `destroyable: true`.
- `WhittakerTech::Oscar::ScopeGenerator`: named scope per taxonomy state
  (`Package.trashed`, `Package.published`) plus an `all_states` escape
  hatch, filtered by both `resource_type` and `state` against the shared
  polymorphic card table. No `default_scope` anywhere.
- Cascade events: `WhittakerTech::Oscar::TRANSITION_EVENT` fired via
  `ActiveSupport::Notifications` from inside the same transaction as the
  status-card write, so a subscriber raising rolls back everything from
  that transition. `WhittakerTech::Oscar.on_transition` registration sugar.
  No special-cased "restore" event — restore is just a regular transition.
- Dummy-app proofs: `Post` (canonical WordPress taxonomy, full lifecycle
  through a real `destroy`) and `Package`/`Order` (Hello Dancer
  Package-retirement scenario: rejects new-order-style transitions once
  retired, historical associations stay readable, name reuse blocked until
  purge).

### Fixed
- `create_oscar_statuses` hardcoded `id_type: :uuid` on the polymorphic
  `resource` reference, overriding `Poly::Migration#poly_resource`'s own
  `:string` default (which exists precisely so `oscar_statuses` works
  against any host PK convention, not just UUID). Removed the override.
  `ScopeGenerator`'s generated state scopes also needed an explicit
  `::text` cast on the host's own PK column in their subquery -- Postgres
  has no implicit `uuid = varchar` (or `bigint = varchar`) comparison
  operator, so a bare `where(id: subquery)` broke for any host whose PK
  type doesn't happen to already be textual. Regression-covered with a new
  bigint-PK dummy model (`Gizmo`) alongside the existing uuid-PK ones.
  Found consuming Oscar from Subscribify (bigint PKs) for its T1 build.
- Removed the `oscar.generators` initializer's global
  `primary_key_type: :uuid` override in `engine.rb` -- it silently changed
  the **host app's** default `rails generate model` behavior for every
  future model, not just Oscar's own (which generates none).
