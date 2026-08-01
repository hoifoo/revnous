# Phase 3: SEO Fields & FAQ Schema - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-22
**Phase:** 3-SEO Fields & FAQ Schema
**Areas discussed:** FAQ input UX, Keywords field, OG image input, Canonical URL field

---

## FAQ Input UX

| Option | Description | Selected |
|--------|-------------|----------|
| Dynamic rows | Stimulus controller with Add/Remove buttons. Each row = one Q+A pair. | ✓ |
| Fixed 5 slots | 5 static Q+A field pairs always visible. No JS needed. | |
| Textarea format | Admin types Q:/A: prefixed lines, parsed server-side. | |

**User's choice:** Dynamic rows

| Option | Description | Selected |
|--------|-------------|----------|
| No hard limit | Admin can add as many pairs as needed. | ✓ |
| Cap at 10 | Reasonable upper bound. | |

**User's choice:** No hard limit

| Option | Description | Selected |
|--------|-------------|----------|
| Only when pairs exist | No empty FAQPage schema emitted. | ✓ |
| Always | Emits schema even with 0 pairs. | |

**User's choice:** Only when pairs exist (emit FAQPage JSON-LD only when ≥1 pair)

| Option | Description | Selected |
|--------|-------------|----------|
| Collapsible section at bottom | Collapsed by default, expand when needed. | ✓ |
| Always visible at bottom | Always shown below SEO fields. | |

**User's choice:** Collapsible section at bottom

---

## Keywords Field

| Option | Description | Selected |
|--------|-------------|----------|
| Comma-separated text field | Plain input, stored as-is. Simple, no JS. | |
| Tag chip input | Enter key creates chip. Nicer UX, needs Stimulus. | ✓ |

**User's choice:** Tag chip input

| Option | Description | Selected |
|--------|-------------|----------|
| Suppress tag entirely | No `<meta name="keywords">` when blank. | ✓ |
| Emit empty tag | Always emit `<meta name="keywords" content="">`. | |

**User's choice:** Suppress tag entirely

| Option | Description | Selected |
|--------|-------------|----------|
| text[] array column | Native PG array, Rails array: true. | |
| jsonb column | JSON array. More flexible. | ✓ |
| You decide | Claude's discretion. | |

**User's choice:** jsonb column

---

## OG Image Input

| Option | Description | Selected |
|--------|-------------|----------|
| ActiveStorage upload | has_one_attached :og_image. Same as cover photo/avatar. | ✓ |
| URL field | Admin pastes external URL. Simpler, no upload. | |

**User's choice:** ActiveStorage upload

| Option | Description | Selected |
|--------|-------------|----------|
| og_image → cover_photo → site logo | Graceful degradation. | ✓ |
| og_image → blank | Only show OG if explicitly set. | |

**User's choice:** 3-step fallback chain

---

## Canonical URL Field

| Option | Description | Selected |
|--------|-------------|----------|
| Validate http(s) + allow blank | URI::DEFAULT_PARSER pattern. Rejects javascript:/data:. | ✓ |
| No validation | Plain text, simpler but could emit invalid canonical. | |

**User's choice:** Validate http(s) only + allow blank

| Option | Description | Selected |
|--------|-------------|----------|
| Fall back to blog_url(blog.slug) | Existing controller behavior when blank. | ✓ |
| Omit the canonical tag | No link rel=canonical if not set. | |

**User's choice:** Fall back to blog_url(blog.slug)

---

## Claude's Discretion

- Form field ordering within the SEO metadata grid
- Chip input hidden field strategy for jsonb serialization
- Exact Stimulus controller names
- FAQ collapsible implementation detail (details/summary vs Stimulus toggle)

## Deferred Ideas

None — discussion stayed within phase scope.
