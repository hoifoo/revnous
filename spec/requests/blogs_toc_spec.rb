require 'rails_helper'

RSpec.describe "Blog TOC anchor injection", type: :request do
  # Exercises every branch at once: H1 (untouched), H2 "Intro" (twice, to
  # force the dedup suffix), a paragraph, H3 "Detail", and H4 (untouched).
  let(:body_html) do
    "<h1>Title</h1><h2>Intro</h2><p>Some paragraph text.</p>" \
      "<h3>Detail</h3><h4>Sub</h4><h2>Intro</h2>"
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
end
