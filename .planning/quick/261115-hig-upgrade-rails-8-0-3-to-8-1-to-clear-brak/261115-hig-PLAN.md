---
quick_id: 261115-hig
description: Upgrade Rails 8.0.3 to 8.1 to clear brakeman EOLRails CI failure
date: 2026-11-15
---

# Quick Task 261115-hig: Upgrade Rails to 8.1

## Problem

CI `scan_ruby` fails on `main` and on PR #35 with exit code 3. Brakeman 7.1.0 reports:
"Support for Rails 8.0.3 ended on 2026-10-07" (check EOLRails, Gemfile.lock). Its EOL table
covers the whole 8.0 series (`8.0.0` to `8.0.99`), so upgrading to a later 8.0.x patch does not
help. The app is on a Rails series that no longer receives security fixes.

## Tasks

1. Change the Gemfile pin to `gem "rails", "~> 8.1.4"`, then run `bundle update rails brakeman`.
2. Keep `config.load_defaults 8.0`, so no framework defaults change behavior.
3. Run `db:schema:dump` to move the schema headers to `ActiveRecord::Schema[8.1]`.
4. Fix the new Rack 3.2 deprecation by replacing `:unprocessable_entity` with
   `:unprocessable_content`. This covers the controllers, the Devise responder, and the specs.
5. Verify:
   - `bin/brakeman` exits 0
   - `bundle exec rspec` is green
   - `bin/rubocop` is clean
   - the app boots in production

## Rejected alternative

Adding the EOL warning to `config/brakeman.ignore`. That only hides the fact that the
framework no longer gets security patches.
