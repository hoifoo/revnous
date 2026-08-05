# Phase 2 Manual QA Checklist — Public Rendering & Two-Column Layout

This checklist covers everything the request-spec suite (`spec/requests/blogs_toc_spec.rb`)
cannot reach: `position: sticky` actually traveling, the hover-reveal fade, the reading
measure and heading rhythm landing at their intended pixel values, horizontal overflow, and
the widened `max-w-5xl` TOC-on container width. There is no `spec/system` infrastructure in
this repo (Capybara + Selenium are installed but unconfigured) — this checklist is the
verification layer for everything statically unreachable by a request spec.

## Setup

1. Rebuild the stylesheet so this phase's Tailwind classes are compiled: `yarn build:css`
2. Start the server: `bin/rails server`
3. In a separate terminal, open `bin/rails console` and create a TOC-on post with 5+
   H2/H3 headings, a wide `<pre>` code block, and a `<table>`:

   ```ruby
   Blog.create!(
     title: "Manual QA: TOC Layout",
     slug: "manual-qa-toc-layout",
     toc_enabled: true,
     published_at: 1.day.ago,
     excerpt: "Manual QA fixture for Phase 2 sign-off.",
     body: <<~HTML
       <h2>Introduction</h2>
       <p>Opening paragraph with enough text to establish a reading measure.</p>
       <h2>Getting Started</h2>
       <h3>Prerequisites</h3>
       <p>Some prerequisite text.</p>
       <h3>Installation</h3>
       <pre><code>gem install a_package_with_a_very_long_name_or_long_flags --some-very-long-flag-name --another-long-flag-value=1234567890</code></pre>
       <h2>Reference Table</h2>
       <table>
         <thead><tr><th>Option</th><th>Default</th><th>Description</th></tr></thead>
         <tbody>
           <tr><td>timeout</td><td>30</td><td>Request timeout in seconds</td></tr>
           <tr><td>retries</td><td>3</td><td>Number of retry attempts</td></tr>
         </tbody>
       </table>
       <h2>Summary</h2>
       <p>Closing paragraph.</p>
     HTML
   )
   ```

4. Note the TOC-on URL: `http://localhost:3000/blog/manual-qa-toc-layout`
5. Create (or reuse) an existing TOC-off post and note its URL for the comparison items,
   e.g.:

   ```ruby
   Blog.create!(
     title: "Manual QA: TOC Off Comparison",
     slug: "manual-qa-toc-off",
     toc_enabled: false,
     published_at: 1.day.ago,
     excerpt: "Comparison fixture — must render identically to a pre-Phase-2 post.",
     body: "<h2>Introduction</h2><p>Same shape, TOC disabled.</p><h2>Summary</h2><p>Closing paragraph.</p>"
   )
   ```

   TOC-off URL: `http://localhost:3000/blog/manual-qa-toc-off`

## Checklist

Work through all 16 items in a desktop browser at 1280px, then repeat items 12 and 13
while narrowing the window through the 1024px breakpoint.

- [ ] 1. At a 1280px viewport, the sidebar sits to the RIGHT of the article and the article text does not run under it.
- [ ] 2. Scrolling the post: the sidebar stays pinned 32px from the viewport top and travels with the scroll. If it scrolls away instead, inspect computed `align-self` on the sidebar — a `stretch` value means `lg:self-start` was lost.
- [ ] 3. Clicking a sidebar entry jumps to that section and the URL gains the `#toc-…` hash. Note explicitly: smooth scrolling is NOT expected in this phase and its absence is not a defect — the global handler in `_navigation.html.erb` binds on `DOMContentLoaded` and never fires on a Turbo Drive visit.
- [ ] 4. The jumped-to heading is not flush against the viewport top — `prose-headings:scroll-mt-8` gives it 32px of clearance.
- [ ] 5. Hovering an H2 or H3 in the article reveals a gray `#` glyph after the heading text that fades in over ~150ms; it turns pink on hover and is invisible again on mouse-out.
- [ ] 6. Tabbing through the article reaches each permalink and reveals the glyph on focus with a visible focus indicator.
- [ ] 7. Tabbing through the sidebar shows a visible pink focus ring on each entry, and the entry text turns pink.
- [ ] 8. H3 sidebar entries are indented 16px and render smaller and lighter (gray) than H2 entries.
- [ ] 9. Article line length: measure the rendered `div.prose` content width — expect roughly 620-660px, bound by the typography plugin's 65ch, not by the grid track.
- [ ] 10. Heading rhythm in DevTools: `margin-top` computes to 64px on article H2 and 48px on article H3.
- [ ] 11. Container width sanity check (RESEARCH Open Question 1, assumptions A6/A7): the TOC-on page uses `max-w-5xl`, which also widens the hero, title, featured image, and excerpt relative to a TOC-off post. Confirm this is the intended look. It is one class and trivially reversible.
- [ ] 12. Narrow the viewport below 1024px: the sidebar disappears completely with no gap, no placeholder, no dropdown, and no layout shift in the article.
- [ ] 13. On the wide-content post at 1280px: no horizontal page scrollbar appears despite the `<pre>` and `<table>`.
- [ ] 14. Enable the OS reduced-motion setting and confirm the permalink appears instantly with no fade.
- [ ] 15. Open the TOC-off post side by side with a pre-change screenshot or the previous deploy: it looks identical, `max-w-4xl` container, no permalink glyphs, no sidebar.
- [ ] 16. Run an accessibility audit (browser devtools or axe) on the TOC-on post and confirm no new violation relating to nav landmarks, list semantics, contrast, or `aria-hidden` on a focusable element. Note that "two nav landmarks, one unnamed" refers to the pre-existing site header nav and is explicitly out of scope for this phase.

## Known non-defects in this phase

The following are expected absences, not bugs, for Phase 2:

- No smooth scroll on TOC link clicks (native anchor jump only)
- No active-entry highlight in the sidebar as the reader scrolls
- No `aria-current` on the current sidebar entry
- No mobile "Contents" disclosure/dropdown below the `lg` breakpoint
- No sidebar auto-scroll to keep the active entry in view

All five are explicitly deferred to Phase 3 (Reading Navigation Behavior).
