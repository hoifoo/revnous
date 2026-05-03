class CreateAdminInvitations < ActiveRecord::Migration[8.0]
  def change
    create_table :admin_invitations do |t|
      t.string :email, null: false
      t.string :token, null: false
      t.bigint :invited_by_id, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :admin_invitations, :token, unique: true
    add_index :admin_invitations, :email
    add_index :admin_invitations, :invited_by_id
    add_foreign_key :admin_invitations, :users, column: :invited_by_id
  end
end
