# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

`whittaker_tech-oscar` is a Rails engine gem that owns lifecycle visibility for
host models via a configurable, taxonomy-driven state machine (blog-post-shaped:
draft, published, archived, trashed, purged). It has no UI, no routes, and no
controllers — it's a state machine plus generated scopes/verbs on host models.
PostgreSQL is required (not optional) — state history persists via `Poly::Stack`
on a polymorphic card table.

See `docs/design.md` for the full identity, taxonomy config schema, and
boundary tripwires — read it before writing any code in this repo.

## Domain

Oscar is part of a pantheon of WhittakerTech services that form orthogonal
subsystems. Always read CLAUDE.md in the parent directory (../CLAUDE.md)
before working on this repo.

**Boundary discipline:** Oscar owns lifecycle visibility only. It must never
grow an `audience`/`visibility_for` config key (Solomon's job) or a
`superseded`/versioning state (Poly's job). Reject either in review.

## Workflow

Always run `bundle exec rspec` after any code changes to verify tests pass
before committing. Always run `bundle exec rubocop` and verify 0 offenses
before committing.

## Commands

```bash
bundle exec rspec                                    # full test suite
bundle exec rspec spec/models/whittaker_tech/oscar/   # models only
bundle exec rake rubocop                              # lint
bundle exec rake bundle:audit                         # dependency security audit
bundle exec rake brakeman                             # security scan
```

The dummy app at `spec/dummy/` uses PostgreSQL (`DATABASE_HOST`, defaults to
`127.0.0.1:5432`, user/pass `postgres/postgres`). On Aerie, use the Hatchery
ephemeral-Ruby pattern (see the top-level Aerie CLAUDE.md) rather than a local
Ruby install.

## No RubyGems publish

Internal engine — tag/publish is a separate go/no-go decision, not part of
any v0.1 target.
