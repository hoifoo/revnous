class AddTypeToBlog < ActiveRecord::Migration[8.0]
  def change
    add_column :blogs, :type, :string
  end
end
