class AddAuthorIdToBlogs < ActiveRecord::Migration[8.0]
  def change
    add_reference :blogs, :author, null: true, foreign_key: { to_table: :users, on_delete: :nullify }
  end
end
