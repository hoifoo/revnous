class Notice < ApplicationRecord
  validates :message, presence: true
  validates :background_color, inclusion: { in: %w[pink-purple blue green red-orange gray yellow indigo black] }

  before_save :deactivate_other_notices, if: :active?

  BACKGROUND_COLORS = {
    "pink-purple" => { classes: "bg-gradient-to-r from-pink-600 to-purple-600", label: "Pink to Purple" },
    "blue" => { classes: "bg-gradient-to-r from-blue-600 to-blue-700", label: "Blue" },
    "green" => { classes: "bg-gradient-to-r from-green-600 to-green-700", label: "Green" },
    "red-orange" => { classes: "bg-gradient-to-r from-red-600 to-orange-600", label: "Red to Orange" },
    "gray" => { classes: "bg-gradient-to-r from-gray-700 to-gray-900", label: "Gray to Black" },
    "yellow" => { classes: "bg-gradient-to-r from-yellow-500 to-orange-500", label: "Yellow to Orange" },
    "indigo" => { classes: "bg-gradient-to-r from-indigo-600 to-purple-600", label: "Indigo to Purple" },
    "black" => { classes: "bg-black", label: "Solid Black" }
  }.freeze

  def background_classes
    BACKGROUND_COLORS[background_color][:classes]
  end

  def self.active_notice
    find_by(active: true)
  end

  private

  def deactivate_other_notices
    Notice.where.not(id: id).update_all(active: false)
  end
end
