require 'rails_helper'

RSpec.describe Blog::TableOfContents, type: :model do
  # Runs raw HTML through the same HTML5 view-vendor sanitizer show.html.erb
  # uses, then through the PORO — every example exercises the exact
  # production path, not a hand-crafted fragment.
  def rendered(raw)
    ActionController::Base.helpers.sanitize(raw, tags: Blog::ALLOWED_TAGS, attributes: Blog::ALLOWED_ATTRIBUTES)
  end

  def toc(raw)
    described_class.call(rendered(raw))
  end

  describe "heading scope (TOC-02, D-01, D-10)" do
    it "includes only H2/H3 in document order, keeping an orphaned H3 that precedes any H2" do
      raw = '<h3>Orphan</h3><h1>T</h1><h2>A</h2><h4>D</h4><h3>B</h3><h6>Skip</h6>'
      entries = toc(raw).entries

      expect(entries.map { |e| [ e.level, e.text ] }).to eq([ [ 3, "Orphan" ], [ 2, "A" ], [ 3, "B" ] ])
    end

    it "assigns an id to H2/H3 nodes while leaving H1 and H4 without any id attribute" do
      raw = '<h3>Orphan</h3><h1>T</h1><h2>A</h2><h4>D</h4><h3>B</h3><h6>Skip</h6>'
      html = toc(raw).to_html

      expect(html).to include('<h2 id="toc-a">')
      expect(html).to include('<h1>T</h1>')
      expect(html).to include('<h4>D</h4>')
    end
  end

  describe "anchor contract (TOC-03, D-02)" do
    it "prefixes every anchor with toc-" do
      raw = '<h2>Alpha</h2><h3>Beta</h3><h2>Gamma</h2>'
      anchors = toc(raw).entries.map(&:anchor)

      expect(anchors).to all(start_with("toc-"))
    end

    it "dedupes two identical headings to toc-intro and toc-intro-2" do
      raw = '<h2>Intro</h2><h2>Intro</h2>'
      anchors = toc(raw).entries.map(&:anchor)

      expect(anchors).to eq([ "toc-intro", "toc-intro-2" ])
    end

    it "PITFALL 2 case A: Intro, Intro, Intro 2 yields 3 distinct anchors (a naive per-base counter collides here)" do
      raw = '<h2>Intro</h2><h2>Intro</h2><h2>Intro 2</h2>'
      anchors = toc(raw).entries.map(&:anchor)

      expect(anchors.uniq.size).to eq(3)
    end

    it "PITFALL 2 case B: a real heading's slug colliding with a positional fallback still yields 3 distinct anchors" do
      # "🚀" at index 1 has an empty slug and falls back to "section-2";
      # "Section 2" at index 2 has a real slug of "section-2" and must not collide with it.
      raw = '<h2>x</h2><h2>🚀</h2><h2>Section 2</h2>'
      anchors = toc(raw).entries.map(&:anchor)

      expect(anchors.uniq.size).to eq(3)
    end

    it "falls back to a positional anchor for an emoji-only heading" do
      expect(toc('<h2>🚀</h2>').entries.first.anchor).to eq("toc-section-1")
    end

    it "falls back to a positional anchor for a CJK-only heading" do
      expect(toc('<h2>日本語</h2>').entries.first.anchor).to eq("toc-section-1")
    end

    it "falls back to a positional anchor for a Cyrillic-only heading" do
      expect(toc('<h2>Привет</h2>').entries.first.anchor).to eq("toc-section-1")
    end

    it "falls back to a positional anchor for a punctuation-only heading" do
      expect(toc('<h2>!!!</h2>').entries.first.anchor).to eq("toc-section-1")
    end

    it "PITFALL 4: truncates an anchor longer than MAX_SLUG_LENGTH and never leaves a trailing hyphen" do
      long_text = (%w[Word] * 20).join(" ") # parameterizes to well past 80 characters
      anchor = toc("<h2>#{long_text}</h2>").entries.first.anchor

      expect(anchor.length).to be <= (described_class::MAX_SLUG_LENGTH + described_class::ANCHOR_PREFIX.length)
      expect(anchor).not_to end_with("-")
    end
  end

  describe "labels (D-08)" do
    it "preserves inline markup allowed in LABEL_TAGS" do
      entry = toc('<h2>Getting <code>Started</code></h2>').entries.first

      expect(entry.label_html).to eq('Getting <code>Started</code>')
    end

    it "exposes the plain-text heading separately from the label" do
      entry = toc('<h2>Getting <code>Started</code></h2>').entries.first

      expect(entry.text).to eq("Getting Started")
    end

    it "strips a disallowed-in-labels element while keeping the surrounding text" do
      entry = toc('<h2>Before <img src="x.png" alt="x"> After</h2>').entries.first

      expect(entry.label_html).not_to include("<img")
      expect(entry.label_html).to include("Before")
      expect(entry.label_html).to include("After")
    end
  end

  describe "byte fidelity (PITFALL 1, LAYOUT-04)" do
    it "round-trips an entity-heavy, heading-free body byte-for-byte" do
      raw = '<p>A&nbsp;B &amp; C &mdash; D &hellip; E &copy; F</p><figure><img src="/a.png" alt="G&nbsp;H" width="640"><figcaption>Cap</figcaption></figure>'
      sanitized = rendered(raw)

      expect(described_class.call(sanitized).to_html).to eq(sanitized.to_s)
    end
  end
end
