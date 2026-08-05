require 'rails_helper'

RSpec.describe "Blog TOC anchor injection", type: :request do
  # Exercises every branch at once: H1 (untouched), H2 "Intro" (twice, to
  # force the dedup suffix), a paragraph, H3 "Detail", and H4 (untouched).
  let(:body_html) do
    "<h1>Title</h1><h2>Intro</h2><p>Some paragraph text.</p>" \
      "<h3>Detail</h3><h4>Sub</h4><h2>Intro</h2>"
  end

  # Two visible headings — below MIN_TOC_ENTRIES, suppresses the sidebar.
  let(:two_heading_body) do
    "<h2>Intro</h2><h3>Detail</h3>"
  end

  # Three visible headings — exactly at the threshold, renders the sidebar.
  let(:three_heading_body) do
    "<h2>Intro</h2><h3>Detail</h3><h2>Summary</h2>"
  end

  # Four visible headings — above the threshold, and enough to exercise
  # single/double hide-override filtering.
  let(:four_heading_body) do
    "<h2>Intro</h2><h3>Detail</h3><h2>Summary</h2><h3>Notes</h3>"
  end

  # First heading contains an inline link (nested-anchor stripping, Pitfall
  # 4); third heading contains a <strong> (must survive re-sanitization).
  let(:linked_heading_body) do
    "<h2>Getting <a href=\"/x\">Started</a> Beyond</h2><h2>Second</h2><h3><strong>Third</strong></h3>"
  end

  describe "rendered response (TOC-03, success criterion #2)" do
    let(:blog) do
      create(:blog, slug: "anchor-on-post", body: body_html, toc_enabled: true,
                    published_at: 1.day.ago)
    end

    it "injects unescaped, unique toc- anchors on H2/H3 in document order" do
      get blog_path(blog.slug)

      expect(response.body).to include('<h2 id="toc-intro">')
      expect(response.body).to include('<h3 id="toc-detail">')
      expect(response.body).to include('<h2 id="toc-intro-2">')
    end

    it "leaves H1 and H4-H6 without any id attribute" do
      get blog_path(blog.slug)

      expect(response.body).to include('<h1>Title</h1>')
      expect(response.body).to include('<h4>Sub</h4>')
    end

    it "injects exactly one anchor per H2/H3 heading, no stray injection" do
      get blog_path(blog.slug)

      expect(response.body.scan('id="toc-').length).to eq(3)
    end
  end

  describe "TOC-off short-circuit (LAYOUT-04)" do
    let(:blog) do
      create(:blog, slug: "anchor-off-post", body: body_html, toc_enabled: false,
                    published_at: 1.day.ago)
    end

    it "injects no toc- anchor at all" do
      get blog_path(blog.slug)

      expect(response.body.scan('id="toc-').length).to eq(0)
    end

    it "renders the article markup unchanged" do
      get blog_path(blog.slug)

      expect(response.body).to include('<h2>Intro</h2>')
      expect(response.body).to include('<h3>Detail</h3>')
    end
  end

  describe "persistence and upstream consumers are untouched (D-05, ASVS V13)" do
    let(:blog) do
      create(:blog, slug: "anchor-persistence-post", body: body_html, toc_enabled: true,
                    published_at: 1.day.ago)
    end

    it "never mutates blogs.body when rendering the TOC-on page" do
      get blog_path(blog.slug)

      expect(blog.reload.body).not_to include("id=")
      expect(blog.reload.body).not_to include("toc-")
    end

    it "excludes toc- and id= from the .md export" do
      get blog_path(blog.slug, format: :md)

      expect(response.body).not_to include("toc-")
      expect(response.body).not_to include("id=")
    end

    it "keeps the public JSON API content_html byte-for-byte equal to blogs.body" do
      get api_v1_blog_path(blog.slug)

      parsed = JSON.parse(response.body)
      expect(parsed["content_html"]).to eq(blog.reload.body)
      expect(parsed["content_html"]).not_to include("toc-")
    end

    it "does not leak toc- into seo_description" do
      expect(blog.seo_description).not_to include("toc-")
    end
  end

  describe "STI coverage (D-06)" do
    let(:article) do
      Article.create!(title: "Article Title", slug: "anchor-on-article", body: body_html,
                       toc_enabled: true, published_at: 1.day.ago)
    end

    it "injects unescaped, unique toc- anchors on H2/H3 for the Article STI subtype" do
      get blog_path(article.slug)

      expect(response.body).to include('<h2 id="toc-intro">')
      expect(response.body).to include('<h3 id="toc-detail">')
      expect(response.body).to include('<h2 id="toc-intro-2">')
    end
  end

  describe "sidebar rendering (LAYOUT-01, A11Y-01)" do
    let(:blog) do
      create(:blog, slug: "sidebar-render-post", body: three_heading_body, toc_enabled: true,
                    published_at: 1.day.ago)
    end

    it "renders the nav landmark with the exact accessible name" do
      get blog_path(blog.slug)

      expect(response.body).to include('<nav aria-label="Table of contents">')
    end

    it "renders one ol[role=list] with exactly 3 direct li children, each linking to a heading id in the document" do
      get blog_path(blog.slug)

      doc = Nokogiri::HTML5(response.body)
      nav = doc.at_css('nav[aria-label="Table of contents"]')
      ol = nav.at_css('ol[role="list"]')
      lis = ol.css("> li")
      expect(lis.length).to eq(3)

      lis.each do |li|
        a = li.at_css("a")
        expect(a["href"]).to start_with("#toc-")
        target_id = a["href"].delete_prefix("#")
        expect(doc.at_css("##{target_id}")).not_to be_nil
      end
    end

    it "renders the visible 'Table of Contents' label" do
      get blog_path(blog.slug)

      doc = Nokogiri::HTML5(response.body)
      nav = doc.at_css('nav[aria-label="Table of contents"]')
      expect(nav.at_css("p").text).to eq("Table of Contents")
    end

    it "does not include an aria-current attribute anywhere in the nav (Phase 3 owns that)" do
      get blog_path(blog.slug)

      doc = Nokogiri::HTML5(response.body)
      nav = doc.at_css('nav[aria-label="Table of contents"]')
      expect(nav.css("[aria-current]")).to be_empty
    end

    it "includes the two-column grid track and the widened container" do
      get blog_path(blog.slug)

      expect(response.body).to include("lg:grid-cols-[minmax(0,1fr)_16rem]")
      expect(response.body).to include("max-w-5xl")
    end

    it "places the sidebar nav before div.prose in DOM order" do
      get blog_path(blog.slug)

      nav_index = response.body.index('<nav aria-label="Table of contents">')
      prose_index = response.body.index('class="prose')
      expect(nav_index).to be < prose_index
    end
  end

  describe "sidebar suppression threshold (TOC-04, D-12)" do
    it "suppresses the sidebar at 2 visible entries but keeps heading anchor ids (D-11)" do
      blog = create(:blog, slug: "threshold-two", body: two_heading_body, toc_enabled: true,
                            published_at: 1.day.ago)

      get blog_path(blog.slug)

      expect(response.body).not_to include('<nav aria-label="Table of contents">')
      expect(response.body).not_to include("lg:grid-cols-[minmax(0,1fr)_16rem]")
      expect(response.body).to include("max-w-4xl")
      expect(response.body).to include('id="toc-intro"')
      expect(response.body).to include('id="toc-detail"')
    end

    it "renders the sidebar with 3 entries at exactly the threshold" do
      blog = create(:blog, slug: "threshold-three", body: three_heading_body, toc_enabled: true,
                            published_at: 1.day.ago)

      get blog_path(blog.slug)

      expect(response.body).to include('<nav aria-label="Table of contents">')
      doc = Nokogiri::HTML5(response.body)
      nav = doc.at_css('nav[aria-label="Table of contents"]')
      expect(nav.css('ol[role="list"] > li').length).to eq(3)
    end

    it "renders the sidebar with 4 entries above the threshold" do
      blog = create(:blog, slug: "threshold-four", body: four_heading_body, toc_enabled: true,
                            published_at: 1.day.ago)

      get blog_path(blog.slug)

      expect(response.body).to include('<nav aria-label="Table of contents">')
      doc = Nokogiri::HTML5(response.body)
      nav = doc.at_css('nav[aria-label="Table of contents"]')
      expect(nav.css('ol[role="list"] > li').length).to eq(4)
    end

    it "filters a single hidden anchor down to 3 entries while its heading id survives" do
      blog = create(:blog, slug: "threshold-hide-one", body: four_heading_body, toc_enabled: true,
                            published_at: 1.day.ago,
                            toc_overrides: { "toc-intro" => { "hidden" => true } })

      get blog_path(blog.slug)

      doc = Nokogiri::HTML5(response.body)
      nav = doc.at_css('nav[aria-label="Table of contents"]')
      expect(nav.css('ol[role="list"] > li').length).to eq(3)
      expect(nav.css('a[href="#toc-intro"]')).to be_empty
      expect(response.body).to include('id="toc-intro"')
    end

    it "suppresses the sidebar entirely when two of four anchors are hidden" do
      blog = create(:blog, slug: "threshold-hide-two", body: four_heading_body, toc_enabled: true,
                            published_at: 1.day.ago,
                            toc_overrides: {
                              "toc-intro" => { "hidden" => true },
                              "toc-summary" => { "hidden" => true }
                            })

      get blog_path(blog.slug)

      expect(response.body).not_to include('<nav aria-label="Table of contents">')
    end

    it "treats jsonb string booleans '0'/'false' as visible and '1' as hidden (Pitfall 6)" do
      blog = create(:blog, slug: "threshold-boolean-cast", body: four_heading_body, toc_enabled: true,
                            published_at: 1.day.ago,
                            toc_overrides: {
                              "toc-intro" => { "hidden" => "0" },
                              "toc-summary" => { "hidden" => "false" },
                              "toc-notes" => { "hidden" => "1" }
                            })

      get blog_path(blog.slug)

      doc = Nokogiri::HTML5(response.body)
      nav = doc.at_css('nav[aria-label="Table of contents"]')
      expect(nav.css('a[href="#toc-intro"]')).not_to be_empty
      expect(nav.css('a[href="#toc-summary"]')).not_to be_empty
      expect(nav.css('a[href="#toc-notes"]')).to be_empty
    end
  end

  describe "TOC-off layout is frozen (LAYOUT-03)" do
    let(:blog) do
      create(:blog, slug: "toc-off-frozen", body: three_heading_body, toc_enabled: false,
                    published_at: 1.day.ago)
    end

    it "renders the exact frozen prose class string, including its trailing space" do
      get blog_path(blog.slug)

      expect(response.body).to include('class="prose prose-lg max-w-none mb-16 "')
    end

    it "keeps the container at max-w-4xl and never renders max-w-5xl" do
      get blog_path(blog.slug)

      expect(response.body).to include("max-w-4xl")
      expect(response.body).not_to include("max-w-5xl")
    end

    it "renders no grid track, no permalink glyphs, and no TOC nav" do
      get blog_path(blog.slug)

      expect(response.body).not_to include("lg:grid-cols-[minmax(0,1fr)_16rem]")
      expect(response.body).not_to include("toc-permalink")
      expect(response.body).not_to include("Table of contents")
    end
  end

  describe "heading permalinks (INTX-04)" do
    let(:blog) do
      create(:blog, slug: "permalink-post", body: three_heading_body, toc_enabled: true,
                    published_at: 1.day.ago)
    end

    it "injects exactly one permalink per visible heading" do
      get blog_path(blog.slug)

      expect(response.body.scan('class="toc-permalink"').length).to eq(3)
    end

    it "gives the toc-intro heading's permalink the correct href, aria-label, and inner structure" do
      get blog_path(blog.slug)

      doc = Nokogiri::HTML5(response.body)
      heading = doc.at_css("#toc-intro")
      permalink = heading.at_css("a.toc-permalink")

      expect(permalink["href"]).to eq("#toc-intro")
      expect(permalink["aria-label"]).to eq("Permalink to Intro")
      expect(permalink["aria-hidden"]).to be_nil

      children = permalink.children
      expect(children.length).to eq(1)
      span = children.first
      expect(span.name).to eq("span")
      expect(span["aria-hidden"]).to eq("true")
      expect(span.text).to eq("#")
    end

    it "leaves the heading's opening tag untouched" do
      get blog_path(blog.slug)

      expect(response.body).to include('<h2 id="toc-intro">')
    end

    it "never leaks a trailing # into a sidebar entry's text" do
      get blog_path(blog.slug)

      doc = Nokogiri::HTML5(response.body)
      nav = doc.at_css('nav[aria-label="Table of contents"]')
      nav.css("li").each do |li|
        expect(li.text.strip).not_to end_with("#")
      end
    end

    it "renders zero permalinks on a suppressed (2-heading) TOC-on post" do
      suppressed_blog = create(:blog, slug: "permalink-suppressed", body: two_heading_body,
                                       toc_enabled: true, published_at: 1.day.ago)

      get blog_path(suppressed_blog.slug)

      expect(response.body.scan('class="toc-permalink"').length).to eq(0)
    end
  end

  describe "entry labels with inline markup (Pitfall 4)" do
    let(:blog) do
      create(:blog, slug: "inline-markup-post", body: linked_heading_body, toc_enabled: true,
                    published_at: 1.day.ago)
    end

    it "strips a nested anchor from the sidebar entry while keeping the label text" do
      get blog_path(blog.slug)

      doc = Nokogiri::HTML5(response.body)
      nav = doc.at_css('nav[aria-label="Table of contents"]')

      expect(nav.at_css('a[href="/x"]')).to be_nil

      li = nav.css("li").first
      anchors = li.css("a")
      expect(anchors.length).to eq(1)
      expect(anchors.first["href"]).to eq("#toc-getting-started-beyond")

      link_text = anchors.first.text
      expect(link_text).to include("Getting")
      expect(link_text).to include("Started")
      expect(link_text).to include("Beyond")
    end

    it "keeps a <strong> element inside the sidebar link for a heading containing it" do
      get blog_path(blog.slug)

      doc = Nokogiri::HTML5(response.body)
      nav = doc.at_css('nav[aria-label="Table of contents"]')
      li = nav.css("li").last
      expect(li.at_css("a strong")).not_to be_nil
    end
  end

  describe "wide content does not break the grid (Pitfall 2)" do
    # Bodies reused verbatim from spec/requests/blogs_golden_master_spec.rb's
    # FIXTURES["code_post"]/["tables_post"], each prefixed with two headings
    # so the total clears the 3-entry threshold.
    let(:code_post_body) do
      "<h2>Intro</h2><h3>Detail</h3>" \
        "<h2>Usage</h2><pre><code>a &lt; b &amp;&amp; c &gt; d\n  indent\n</code></pre>" \
        "<p>inline <code>x = 1</code></p>"
    end

    let(:tables_post_body) do
      "<h2>Intro</h2><h3>Detail</h3>" \
        '<h2>Data</h2><table><colgroup><col width="50"></colgroup>' \
        '<thead><tr><th scope="col">A &amp; B</th></tr></thead>' \
        "<tbody><tr><td rowspan=\"2\">x</td></tr></tbody><tfoot><tr><td>f</td></tr></tfoot></table>"
    end

    it "renders 200 with the grid track present for a wide <pre> code block" do
      blog = create(:blog, slug: "wide-code-post", body: code_post_body, toc_enabled: true,
                            published_at: 1.day.ago)

      get blog_path(blog.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lg:grid-cols-[minmax(0,1fr)_16rem]")
    end

    it "renders 200 with the grid track present for a wide <table>" do
      blog = create(:blog, slug: "wide-table-post", body: tables_post_body, toc_enabled: true,
                            published_at: 1.day.ago)

      get blog_path(blog.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("lg:grid-cols-[minmax(0,1fr)_16rem]")
    end
  end

  describe "STI coverage: sidebar renders for the Article subtype (D-06)" do
    let(:article) do
      Article.create!(title: "Article Title", slug: "sidebar-render-article", body: three_heading_body,
                       toc_enabled: true, published_at: 1.day.ago)
    end

    it "renders the nav landmark and 3 entries for an Article" do
      get blog_path(article.slug)

      expect(response.body).to include('<nav aria-label="Table of contents">')

      doc = Nokogiri::HTML5(response.body)
      nav = doc.at_css('nav[aria-label="Table of contents"]')
      expect(nav.css('ol[role="list"] > li').length).to eq(3)
    end
  end
end
