# WhittakerTech::Oscar

A configurable lifecycle-visibility state machine engine for Rails.

Oscar generalizes soft-delete into a taxonomy-driven lifecycle state machine —
blog-post-shaped (`draft`, `published`, `archived`, `trashed`, `purged`) but
configurable per host model. States are exclusive, transitions are declared,
and nothing changes state except through a named transition. State history
persists via [Poly::Stack](https://github.com/whittakertech/poly).

Oscar owns lifecycle **visibility**; nothing else. `published` is a visibility
state. Private/public is an *access* state owned elsewhere (Solomon/Leeloo) and
is entirely outside this engine's concern.

See [`docs/design.md`](docs/design.md) for the full identity, taxonomy config
schema, and boundary rules.

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

**v0.1 — internal engine.** No RubyGems publish; tag/publish is a separate
go/no-go decision.

## License

MIT.
