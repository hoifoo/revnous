# Deploy sequence: bin/rails db:migrate, then bundle exec rake blogs:migrate_body

namespace :blogs do
  desc "Migrate blog content from ActionText to blogs.body column"
  task migrate_body: :environment do
    total = Blog.count
    migrated = 0
    skipped = 0

    Blog.find_each do |blog|
      if blog.body.present?
        puts "Skipping post #{blog.id} — body already populated"
        skipped += 1
        next
      end

      rich_text = ActionText::RichText.find_by(
        record_type: "Blog",
        record_id: blog.id,
        name: "content"
      )

      if rich_text.nil? || rich_text.read_attribute(:body).to_s.blank?
        puts "Skipping post #{blog.id} — no ActionText content found"
        skipped += 1
        next
      end

      raw_html = rich_text.read_attribute(:body).to_s

      doc = Nokogiri::HTML.fragment(raw_html)
      doc.css("action-text-attachment").each(&:remove)
      clean_html = doc.to_html

      sanitizer = Rails::Html::SafeListSanitizer.new
      sanitized_html = sanitizer.sanitize(clean_html, tags: Blog::ALLOWED_TAGS, attributes: Blog::ALLOWED_ATTRIBUTES)

      blog.update_column(:body, sanitized_html)
      migrated += 1
      puts "Migrated #{migrated}/#{total} posts"
    end

    puts "Done. #{migrated} posts migrated, #{skipped} skipped."
  end

  desc "Backfill missing slugs from title"
  task backfill_slugs: :environment do
    blogs = Blog.where(slug: [ nil, "" ])
    puts "Found #{blogs.count} blogs missing slugs"
    blogs.find_each do |blog|
      next if blog.title.blank?

      candidate = blog.title.parameterize
      candidate = "#{candidate}-#{blog.id}" if Blog.where(slug: candidate).where.not(id: blog.id).exists?
      blog.update_column(:slug, candidate)
      puts "Set slug '#{candidate}' for blog #{blog.id}"
    end
    puts "Done."
  end
end
