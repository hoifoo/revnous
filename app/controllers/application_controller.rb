class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :load_active_notice
  before_action :set_seo_metadata
  before_action :set_discovery_headers

  # Site-wide Markdown content negotiation. Registering the :md MIME type
  # means any page may be requested as text/markdown (Accept header or
  # ?format=md). Controllers without a specific handler would otherwise 406;
  # serve a generic Markdown view instead. Specific handlers (e.g.
  # BlogsController#show) still take precedence.
  rescue_from ActionController::UnknownFormat, ActionView::MissingTemplate, with: :render_generic_markdown_or_raise

  private

  def render_generic_markdown_or_raise(exception)
    raise exception unless request.format.to_sym == :md

    title = @page_title.presence || "Revnous"
    md = +"# #{strip_tags(title)}\n\n"
    md << "#{strip_tags(@page_description)}\n\n" if @page_description.present?
    md << "Canonical: #{canonical_markdown_url}\n\n"
    md << "## More\n\n"
    md << "- [Site overview (llms.txt)](#{root_url}llms.txt)\n"
    md << "- [API spec (OpenAPI)](#{root_url}api/v1/openapi.json)\n"
    md << "- [Blog](#{root_url}blog)\n"
    md << "- [Products](#{root_url}products)\n"

    render plain: md, content_type: "text/markdown; charset=utf-8"
  end

  def canonical_markdown_url
    request.original_url.sub(/\.md(?=$|\?)/, "").sub(/[?&]format=md\b/, "")
  end

  def strip_tags(value)
    ActionController::Base.helpers.strip_tags(value.to_s)
  end

  def load_active_notice
    @active_notice = Notice.active_notice
  end

  def set_seo_metadata
    page_identifier = "#{controller_name}##{action_name}"
    seo_data = SeoMetadatum.find_by(page_identifier: page_identifier)

    if seo_data
      @page_title = seo_data.page_title
      @page_description = seo_data.meta_description
    end
  end

  def set_discovery_headers
    response.headers["Link"] = '<https://www.revnous.com/llms.txt>; rel="describedby"'
  end
end
