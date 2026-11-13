---
quick_id: 261113-qxp
status: complete
date: 2026-11-13
commit: fbf9baa
---

# Quick Task 261113-qxp: Summary

Replaced the placeholder social proof with real numbers and Shopify App Store reviews.

## Changes

- `app/models/social_proof.rb` (new) is the single source for the stats, rating, review URL,
  AI assistant example, and the 3 verbatim reviews.
- Homepage changes:
  - The hero subtitle names 100+ merchants and the AI assistant.
  - The 4-stat row (100+ / 130K+ / 740K+ / 4.8/5) replaces $1B+, 66,000+, and 35% AOV. The
    rating stat links to the reviews.
  - New "Loved for Fast, Human Support" section with review cards and an AI assistant callout.
  - Trusted line and bottom CTA updated.
- Pages where the 66,000+/50,000/"thousands of brands" copy now reads "100+ Shopify
  merchants": blogs index/show, products index/show, pricing index/show, contacts, solutions
  show, case_studies index/show.
- `SolutionsController` changes:
  - The meta description now says "Rated 4.8/5 on the Shopify App Store" (was 66,000+ stores).
  - The social proof line now reads 740K+ variant price changes (was 50M+ monthly).
  - The "3X Revenue" link is now "Sales Campaign Case Studies".
- `public/llms.txt` now gives the 4.8/5 rating, the merchant count, and the AI assistant.
  Date bumped to 2026-11-13.
- Golden-master fixtures: the CTA line was updated in all 5 files.

## Verification

- `bundle exec rspec spec/requests`: 112 passed
- Throwaway smoke spec checked home, products index/show, product pricing, case studies
  index/show, contact, blog, and both solutions. All returned 200 with no fake-claim regex
  matches, and the expected real numbers and reviews were present.
- rubocop clean on the changed Ruby files
- Review quotes were checked against the raw apps.shopify.com review page HTML

## Not changed (owner action)

- CaseStudy DB records are admin-managed content with research-style results (for example,
  "17% of monthly sales in 6 hours" and "2x increase"). They still appear in the homepage
  "Success Stories" section. Review or deactivate them in admin.
- `pricing/index.html.erb` is not routed (dead template). It was edited anyway for consistency.
- Pre-existing bug: `case_studies/show` raises an error when `product_features` is nil
  (`.downcase` on nil). The factory omits it.
