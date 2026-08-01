# Installation

## 1. Add the gem

Oscar isn't published to RubyGems yet (internal engine, tag/publish is a
separate go/no-go decision — see the [changelog](changelog/)). Add it from
GitHub in your `Gemfile`:

```ruby
gem 'whittaker_tech-oscar', github: 'whittakertech/oscar'
```

Then install:

```bash
bundle install
```

---

## 2. Run the install generator

```bash
bin/rails generate whittaker_tech:oscar:install
```

This creates `config/initializers/oscar.rb` — a fully-commented template,
nothing active by default. Oscar's own migration (`oscar_statuses`) ships
with the engine and auto-registers itself; there's no `install:migrations`
copy step to run. Just migrate:

```bash
bin/rails db:migrate
```

---

## 3. Register named taxonomy bases (optional)

No base is pre-registered by the gem itself. If you want a reusable preset
your models can opt into by name — rather than declaring a full taxonomy
inline on every model — register it in the initializer the generator just
created:

```ruby
# config/initializers/oscar.rb
WhittakerTech::Oscar.configure do |config|
  config.bases = {
    blog_post_visibility: {
      initial: :draft,
      states: {
        draft:     { destroyable: false },
        published: { destroyable: false },
        archived:  { destroyable: false },
        trashed:   { destroyable: false },
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
  }
end
```

Each entry is validated eagerly when this `configure` block finishes — an
invalid base raises `InvalidTaxonomyError` at boot, not at first use on a
model. If you don't need a shared preset, skip this step entirely; models
can always declare their own taxonomy from scratch with `base: []` (see
[Usage](usage/)).

---

## 4. Declare a taxonomy on a host model

```ruby
class Post < ApplicationRecord
  include WhittakerTech::Oscar::Stateful

  oscar_taxonomy(base: :blog_post_visibility)
end
```

`base:` is required — there's no default, silent or otherwise. See
[Usage](usage/) for the full set of what `base:` accepts and how overrides
merge over it.

---

## Verifying the installation

```bash
bin/rails runner "
  post = Post.create!
  puts post.oscar_state   # => :draft
  post.publish!
  puts post.published?    # => true
"
```

---

## Requirements

| Requirement | Minimum |
|-------------|---------|
| Ruby        | 3.2     |
| Rails       | 7.1     |
| PostgreSQL  | required — not optional. History persists via [Poly::Stack](https://github.com/whittakertech/poly) on a polymorphic card table |
| poly gem    | ~> 1.1  |
