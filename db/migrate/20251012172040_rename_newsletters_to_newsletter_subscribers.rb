class RenameNewslettersToNewsletterSubscribers < ActiveRecord::Migration[8.0]
  def change
    rename_table :newsletters, :newsletter_subscribers
  end
end
