# Derives a Table of Contents from an already-view-sanitized blog body.
#
# Parses the HTML5-vendor-sanitized `body` string exactly once with
# Nokogiri::HTML5, assigns unique `toc-` prefixed anchor ids to every H2/H3
# in document order, and exposes both the ordered entry list and the
# id-injected HTML from that single parse/mutation pass.
class Blog
  class TableOfContents
    HEADING_SELECTOR = "h2, h3".freeze
    ANCHOR_PREFIX = "toc-".freeze
    MAX_SLUG_LENGTH = 80

    # Inline tags permitted inside a TOC entry label (D-08).
    # Deliberately a strict subset of Blog::ALLOWED_TAGS.
    LABEL_TAGS = %w[strong em code a br].freeze
    LABEL_ATTRIBUTES = %w[href].freeze

    Entry = Struct.new(:level, :anchor, :label_html, :text, keyword_init: true)

    attr_reader :fragment, :entries

    # sanitized_html: output of the view-level `sanitize` helper (already a
    # SafeBuffer). MUST be parsed with HTML5 to preserve byte-fidelity —
    # Nokogiri::HTML4 decodes entities like &nbsp;/&mdash; to literal
    # characters and silently corrupts the response.
    def self.call(sanitized_html)
      new(Nokogiri::HTML5.fragment(sanitized_html.to_s)).tap(&:derive!)
    end

    def initialize(fragment)
      @fragment = fragment
      @entries = []
    end

    def derive!
      used = {}

      fragment.css(HEADING_SELECTOR).each_with_index do |node, index|
        anchor = allocate_anchor(base_slug(node, index), used)
        node["id"] = anchor

        entries << Entry.new(
          level: node.name[1].to_i,
          anchor: anchor,
          label_html: sanitized_label(node),
          text: node.text.strip
        )
      end

      self
    end

    def to_html = fragment.to_html

    private

    def base_slug(node, index)
      slug = node.text.parameterize
      return "section-#{index + 1}" if slug.blank? # D-02 positional fallback

      # Truncate before uniqueness allocation, then strip a trailing hyphen
      # truncation may leave behind, so anchors never end in "-".
      slug.first(MAX_SLUG_LENGTH).sub(/-\z/, "")
    end

    # Tracks issued FINAL anchors, not base-slug occurrence counts — a
    # Hash.new(0) counter produces duplicate anchors when a real heading's
    # slug collides with an already-issued suffixed anchor.
    def allocate_anchor(base, used)
      candidate = "#{ANCHOR_PREFIX}#{base}"
      counter = 1

      while used.key?(candidate)
        counter += 1
        candidate = "#{ANCHOR_PREFIX}#{base}-#{counter}"
      end

      used[candidate] = true
      candidate
    end

    def sanitized_label(node)
      ActionController::Base.helpers.sanitize(
        node.inner_html, tags: LABEL_TAGS, attributes: LABEL_ATTRIBUTES
      )
    end
  end
end
