require 'rails_helper'

RSpec.describe "Admin::Users", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:member) { create(:user) }

  context "as an admin" do
    before { sign_in admin }

    describe "GET /admin/users" do
      it "renders the index" do
        get admin_users_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Users")
      end
    end

    describe "GET /admin/users/new" do
      it "renders the new user form" do
        get new_admin_user_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("New User")
      end
    end

    describe "POST /admin/users" do
      it "creates a user with profile" do
        expect {
          post admin_users_path, params: {
            user: {
              first_name: "Ada",
              last_name: "Lovelace",
              email: "ada@ex.com",
              password: "password123",
              password_confirmation: "password123",
              job_title: "Engineer",
              bio: "Bio.",
              linkedin_url: "https://linkedin.com/in/ada",
              twitter_handle: "@ada",
              admin: "1"
            }
          }
        }.to change(User, :count).by(1)

        created_user = User.order(:created_at).last
        expect(created_user.bio).to eq("Bio.")
        expect(created_user.twitter_handle).to eq("ada")
        expect(created_user.admin).to eq(true)
        expect(response).to redirect_to(admin_users_path)
      end

      it "re-renders new with 422 when linkedin_url is invalid" do
        expect {
          post admin_users_path, params: {
            user: {
              first_name: "Ada",
              last_name: "Lovelace",
              email: "ada2@ex.com",
              password: "password123",
              password_confirmation: "password123",
              linkedin_url: "javascript:alert(1)"
            }
          }
        }.not_to change(User, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    describe "PATCH /admin/users/:id" do
      it "updates profile fields" do
        patch admin_user_path(member), params: {
          user: {
            bio: "Updated bio.",
            job_title: "New Title",
            password: "",
            password_confirmation: ""
          }
        }

        expect(response).to redirect_to(admin_users_path)
        member.reload
        expect(member.bio).to eq("Updated bio.")
        expect(member.job_title).to eq("New Title")
      end

      it "preserves existing password when password param is blank" do
        patch admin_user_path(member), params: {
          user: {
            bio: "Some bio",
            password: "",
            password_confirmation: ""
          }
        }

        expect(User.find(member.id).valid_password?("password123")).to be true
      end
    end

    describe "DELETE /admin/users/:id" do
      it "removes the user" do
        member_to_delete = create(:user)
        expect {
          delete admin_user_path(member_to_delete)
        }.to change(User, :count).by(-1)
        expect(response).to redirect_to(admin_users_path)
        follow_redirect!
        expect(response.body).to include("deleted")
      end
    end
  end

  context "as a non-admin" do
    before { sign_in member }

    describe "GET /admin/users" do
      it "redirects to root with access denied" do
        get admin_users_path
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include("Access denied")
      end
    end

    describe "DELETE /admin/users/:id" do
      it "does not destroy the user" do
        target = create(:user)
        expect {
          delete admin_user_path(target)
        }.not_to change(User, :count)
      end
    end
  end
end
