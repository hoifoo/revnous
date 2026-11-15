---
quick_id: 261115-hig
status: complete
date: 2026-11-15
commit: 55b69b5
---

# Quick Task 261115-hig: Summary

Upgraded Rails from 8.0.3 to 8.1.4.1 to fix the CI `scan_ruby` failure. Brakeman's EOLRails
check reported: "Support for Rails 8.0.3 ended on 2026-10-07".

## Changes

- Gemfile: `rails ~> 8.1.4`. The lockfile resolves Rails 8.1.4.1 and brakeman 8.1.0, plus
  transitive bumps: rack 3.2.8, nokogiri 1.19.7, connection_pool 3.0.2, and others.
- `config.load_defaults 8.0` is unchanged.
- `db/schema.rb` and the cable, cache, and queue schema files: only the header changed, to
  `ActiveRecord::Schema[8.1]`.
- `:unprocessable_entity` became `:unprocessable_content` (29 uses across 15 controllers, the
  Devise responder, and 1 spec). This fixes the Rack 3.2 deprecation warning.

## Verification

- `bin/brakeman`: 0 security warnings, exit code 0.
- `bundle exec rspec`: 210 examples, 0 failures, 5 pending (pre-existing placeholders). No
  deprecation warnings.
- `bin/rubocop`: 175 files, no offenses.
- Production boot (`RAILS_ENV=production rails runner`) reports Rails 8.1.4.1.
