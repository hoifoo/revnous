class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :load_active_notice

  private

  def load_active_notice
    @active_notice = Notice.active_notice
  end
end
