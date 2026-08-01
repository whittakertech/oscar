# WhittakerTech::Oscar

A configurable lifecycle-visibility state machine engine for Rails.

Oscar generalizes soft-delete into a taxonomy-driven lifecycle state machine —
blog-post-shaped (`draft`, `published`, `archived`, `trashed`, `purged`) but
configurable per host model. States are exclusive, transitions are declared,
and nothing changes state except through a named transition. State history
persists via [Poly::Stack](https://github.com/whittakertech/poly).

Oscar owns lifecycle **visibility**; nothing else. `published` is a visibility
state. Private/public is a separate *access* concern, conditional on
visibility, that lives entirely outside this engine.

See [`docs/design.md`](docs/design.md) for the full identity, taxonomy config
schema, and boundary rules, or the full docs site — [Installation](docs/installation.md),
[Usage](docs/usage.md), [Architecture](docs/architecture.md),
[API Reference](docs/api.md), [Examples](docs/examples.md).

## Installation

Add to your Gemfile:

```ruby
gem 'whittaker_tech-oscar', github: 'whittakertech/oscar'
```

Then run the installer:

```bash
bundle exec rails generate whittaker_tech:oscar:install
```

## Status

**v0.2 — internal engine.** No RubyGems publish; tag/publish is a separate
go/no-go decision.

## License

MIT.
