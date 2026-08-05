require 'rails_helper'

RSpec.describe BlogsHelper, type: :helper do
  describe "#blog_article" do
    describe "TOC-off short-circuit" do
      it "returns the untouched sanitized body with no entries and toc? false" do
        body = "<h2>Intro</h2><h2>Two</h2><h2>Three</h2>"
        blog = build(:blog, toc_enabled: false, body: body)

        article = helper.blog_article(blog)

        expect(article.html).to eq(
          helper.sanitize(blog.body, tags: Blog::ALLOWED_TAGS, attributes: Blog::ALLOWED_ATTRIBUTES)
        )
        expect(article.toc_entries).to eq([])
        expect(article.toc?).to be false
      end
    end

    describe "TOC-on with 3 headings" do
      it "returns toc? true and 3 ordered Blog::TableOfContents::Entry instances" do
        body = "<h2>Intro</h2><h3>Detail</h3><h2>Outro</h2>"
        blog = build(:blog, toc_enabled: true, body: body)

        article = helper.blog_article(blog)

        expect(article.toc?).to be true
        expect(article.toc_entries.size).to eq(3)
        expect(article.toc_entries).to all(be_a(Blog::TableOfContents::Entry))
        expect(article.toc_entries.map(&:text)).to eq(%w[Intro Detail Outro])
      end
    end

    describe "suppression threshold (TOC-04, D-12)" do
      it "suppresses with 2 headings" do
        body = "<h2>Intro</h2><h3>Detail</h3>"
        blog = build(:blog, toc_enabled: true, body: body)

        article = helper.blog_article(blog)

        expect(article.toc?).to be false
        expect(article.toc_entries).to eq([])
      end

      it "renders with exactly 3 headings" do
        body = "<h2>Intro</h2><h3>Detail</h3><h2>Outro</h2>"
        blog = build(:blog, toc_enabled: true, body: body)

        article = helper.blog_article(blog)

        expect(article.toc?).to be true
        expect(article.toc_entries.size).to eq(3)
      end

      it "renders with 4 headings" do
        body = "<h2>Intro</h2><h3>Detail</h3><h2>Outro</h2><h3>Extra</h3>"
        blog = build(:blog, toc_enabled: true, body: body)

        article = helper.blog_article(blog)

        expect(article.toc?).to be true
        expect(article.toc_entries.size).to eq(4)
      end
    end

    describe "suppressed-but-anchored (D-11)" do
      it "keeps toc- ids in the html even though the entry list is suppressed" do
        body = "<h2>Intro</h2><h3>Detail</h3>"
        blog = build(:blog, toc_enabled: true, body: body)

        article = helper.blog_article(blog)

        expect(article.toc?).to be false
        expect(article.html).to include('id="toc-intro"')
        expect(article.html).to include('id="toc-detail"')
      end
    end

    describe "hide overrides (D-09, D-10)" do
      it "filters a hidden entry out of toc_entries but keeps its id in the html" do
        body = "<h2>Intro</h2><h2>Two</h2><h2>Three</h2><h2>Four</h2>"
        blog = build(:blog, toc_enabled: true, body: body,
                            toc_overrides: { "toc-intro" => { "hidden" => true } })

        article = helper.blog_article(blog)

        expect(article.toc_entries.size).to eq(3)
        expect(article.toc_entries.map(&:anchor)).not_to include("toc-intro")
        expect(article.html).to include('id="toc-intro"')
      end

      it "crosses the suppression threshold once enough entries are hidden" do
        body = "<h2>Intro</h2><h2>Two</h2><h2>Three</h2><h2>Four</h2>"
        blog = build(:blog, toc_enabled: true, body: body,
                            toc_overrides: {
                              "toc-intro" => { "hidden" => true },
                              "toc-two" => { "hidden" => true }
                            })

        article = helper.blog_article(blog)

        expect(article.toc?).to be false
        expect(article.toc_entries).to eq([])
      end
    end

    describe "boolean casting (Pitfall 6)" do
      let(:body) { "<h2>Intro</h2><h2>Two</h2><h2>Three</h2>" }

      it "leaves the entry visible when hidden is the string \"0\"" do
        blog = build(:blog, toc_enabled: true, body: body,
                            toc_overrides: { "toc-intro" => { "hidden" => "0" } })

        expect(helper.blog_article(blog).toc_entries.map(&:anchor)).to include("toc-intro")
      end

      it "leaves the entry visible when hidden is the string \"false\"" do
        blog = build(:blog, toc_enabled: true, body: body,
                            toc_overrides: { "toc-intro" => { "hidden" => "false" } })

        expect(helper.blog_article(blog).toc_entries.map(&:anchor)).to include("toc-intro")
      end

      it "hides the entry when hidden is the string \"1\"" do
        blog = build(:blog, toc_enabled: true, body: body,
                            toc_overrides: { "toc-intro" => { "hidden" => "1" } })

        expect(helper.blog_article(blog).toc_entries.map(&:anchor)).not_to include("toc-intro")
      end

      it "hides the entry when hidden is the boolean true" do
        blog = build(:blog, toc_enabled: true, body: body,
                            toc_overrides: { "toc-intro" => { "hidden" => true } })

        expect(helper.blog_article(blog).toc_entries.map(&:anchor)).not_to include("toc-intro")
      end
    end

    describe "nil/empty overrides" do
      let(:body) { "<h2>Intro</h2><h2>Two</h2><h2>Three</h2>" }

      it "treats an empty overrides hash as nothing hidden without raising" do
        blog = build(:blog, toc_enabled: true, body: body, toc_overrides: {})

        expect { helper.blog_article(blog) }.not_to raise_error
        expect(helper.blog_article(blog).toc_entries.size).to eq(3)
      end

      it "treats a nil overrides value as nothing hidden without raising" do
        blog = build(:blog, toc_enabled: true, body: body)
        allow(blog).to receive(:toc_overrides).and_return(nil)

        expect { helper.blog_article(blog) }.not_to raise_error
        expect(helper.blog_article(blog).toc_entries.size).to eq(3)
      end
    end

    describe "heading permalinks (INTX-04)" do
      let(:body) { "<h2>Intro</h2><h3>Detail</h3><h2>Outro</h2>" }

      it "injects exactly one toc-permalink anchor per H2/H3 heading" do
        blog = build(:blog, toc_enabled: true, body: body)

        html = helper.blog_article(blog).html

        expect(html.scan('class="toc-permalink"').length).to eq(3)
      end

      it "builds each permalink href from its own heading's id" do
        blog = build(:blog, toc_enabled: true, body: body)

        html = helper.blog_article(blog).html

        expect(html).to include('href="#toc-intro"')
        expect(html).to include('href="#toc-detail"')
        expect(html).to include('href="#toc-outro"')
      end

      it "sets aria-label to Permalink to <heading text>" do
        blog = build(:blog, toc_enabled: true, body: body)

        html = helper.blog_article(blog).html

        expect(html).to include('aria-label="Permalink to Intro"')
      end

      it "puts the glyph in an inner aria-hidden span, never on the anchor itself" do
        blog = build(:blog, toc_enabled: true, body: body)

        html = helper.blog_article(blog).html

        expect(html).to include('<span aria-hidden="true">#</span>')
        expect(html).not_to match(/<a[^>]*class="toc-permalink"[^>]*aria-hidden/)
      end

      it "does not contaminate entry labels or text with the permalink glyph" do
        blog = build(:blog, toc_enabled: true, body: body)

        article = helper.blog_article(blog)

        article.toc_entries.each do |entry|
          expect(entry.text).not_to end_with("#")
          expect(entry.label_html).not_to include("toc-permalink")
        end
      end

      it "leaves the heading's opening tag untouched" do
        blog = build(:blog, toc_enabled: true, body: body)

        html = helper.blog_article(blog).html

        expect(html).to include('<h2 id="toc-intro">')
      end

      it "preserves entities such as &amp; in the heading body" do
        blog = build(:blog, toc_enabled: true, body: "<h2>Foo &amp; Bar</h2><h3>Detail</h3><h2>Outro</h2>")

        html = helper.blog_article(blog).html

        expect(html).to include("&amp;")
      end

      it "injects no toc-permalink when the entry list is suppressed" do
        blog = build(:blog, toc_enabled: true, body: "<h2>Intro</h2><h3>Detail</h3>")

        html = helper.blog_article(blog).html

        expect(html).not_to include("toc-permalink")
      end

      it "gives no permalink to headings without a toc- id" do
        blog = build(:blog, toc_enabled: false, body: body)

        html = helper.blog_article(blog).html

        expect(html).not_to include("toc-permalink")
      end
    end
  end
end
