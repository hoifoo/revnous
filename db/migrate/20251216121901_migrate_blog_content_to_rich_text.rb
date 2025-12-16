class MigrateBlogContentToRichText < ActiveRecord::Migration[8.0]
  # Define a stub class to ensure we can access the table regardless of model changes
  class MigrationBlog < ApplicationRecord
    self.table_name = "blogs"
  end

  def up
    # Migrate existing content to Action Text
    MigrationBlog.find_each do |blog|
      content = blog.read_attribute(:content)
      next if content.blank?

      # Create Action Text record manually
      ActionText::RichText.create!(
        record_type: "Blog",
        record_id: blog.id,
        name: "content",
        body: content
      )
    end

    remove_column :blogs, :content
  end

  def down
    add_column :blogs, :content, :text

    # Restore content from Action Text
    MigrationBlog.reset_column_information
    MigrationBlog.find_each do |blog|
      rich_text = ActionText::RichText.find_by(record_type: "Blog", record_id: blog.id, name: "content")
      if rich_text
        blog.update_column(:content, rich_text.body.to_s)
      end
    end
  end
end
