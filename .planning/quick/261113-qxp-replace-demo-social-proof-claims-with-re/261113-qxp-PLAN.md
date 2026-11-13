---
quick_id: 261113-qxp
type: quick
status: planned
date: 2026-11-13
---

# Quick Task 261113-qxp: Replace demo social-proof claims with real Revnous stats and reviews

Placeholder stats from the design phase ($1B+ revenue, 66,000+ brands, 50,000 brands,
35% AOV, 50M+ monthly updates, "thousands of brands") are live on revnous.com. Replace
them with real, verifiable numbers and real Shopify App Store reviews.

## Source data (2026-11-13)

- Internal dashboard: 130,952 product schedules, 740,079 variant price changes scheduled
- Owner: 100+ merchants using the app
- Shopify App Store (apps.shopify.com/pricing-schedule): 4.8/5 from 8 reviews; AI assistant
  that builds campaigns from plain-language prompts
- Reviews quoted verbatim (checked against the raw review page HTML): Tiny Tales (support),
  SlothBedding, Sadece Satranç

## Tasks

1. **Single source of truth**: `app/models/social_proof.rb` holds the stats, rating, review
   URL, AI assistant example, and the reviews, so future updates touch one file.
2. **Homepage** (`home/index`): hero subtitle, Our Impact stats row (4 real stats; the rating
   links to reviews), a new "Loved for fast, human support" section (rating badge, AI assistant
   callout, 3 review cards), trusted-brands line, bottom CTA.
3. **Other pages**: swap the 66,000+/50,000/thousands copy in blogs index/show, products
   index/show, pricing index/show, contacts, solutions show, case_studies index/show.
4. **SolutionsController**: replace "Used by 66,000+ stores" in the meta description, the
   "50M+ price updates monthly" social proof line, and the "3X Revenue" footer link label.
5. **llms.txt**: "5-star rated" becomes 4.8/5 plus merchants and AI assistant; bump the
   Last updated date.
6. **Golden masters**: the blog show CTA line changes, so update that line in the 5
   `spec/fixtures/golden_master/*.page.html` fixtures and run the blog specs.

## Out of scope (flag to owner)

- CaseStudy DB records (admin-managed content with research-style results such as "17% of
  monthly sales in 6 hours"). Edit them in admin; code does not seed prod.
- Aspirational headlines with no numbers ("Maximize Your Revenue...") stay as they are.

## Verify

- `grep -rnE "66,000|50,000 brands|\$1B|50M\+|thousands of (eCommerce )?brands"` over
  app/ and public/ returns nothing
- `bundle exec rspec spec/requests` passes
- Homepage renders 200 in a request spec / curl
