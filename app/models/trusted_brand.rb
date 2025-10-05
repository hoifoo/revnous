class TrustedBrand < ApplicationRecord
  validates :name, presence: true
  validates :position, presence: true, numericality: { only_integer: true }
  validates :font_style, inclusion: { in: %w[bold serif light normal] }

  scope :ordered, -> { order(:position) }

  FONT_STYLES = {
    "bold" => "text-2xl font-bold",
    "serif" => "text-2xl font-serif",
    "light" => "text-xl font-light",
    "normal" => "text-2xl font-normal"
  }.freeze

  def css_classes
    FONT_STYLES[font_style] || FONT_STYLES["bold"]
  end
end
