class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :load_active_notice
  before_action :set_seo_metadata

  private

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
end
