class AddAuthorProfileToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :bio, :text
    add_column :users, :job_title, :string
    add_column :users, :linkedin_url, :string
    add_column :users, :twitter_handle, :string
  end
end
