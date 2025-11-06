require "test_helper"

class Admin::PartnersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    sign_in @user
  end

  test "should get index" do
    get admin_partners_url
    assert_response :success
  end

  test "should get new" do
    get new_admin_partner_url
    assert_response :success
  end

  test "should create partner" do
    assert_difference("Partner.count") do
      post admin_partners_url, params: { partner: { name: "Test Partner", website_url: "https://example.com" } }
    end
    assert_redirected_to admin_partners_url
  end

  test "should get edit" do
    partner = create(:partner)
    get edit_admin_partner_url(partner)
    assert_response :success
  end

  test "should update partner" do
    partner = create(:partner)
    patch admin_partner_url(partner), params: { partner: { name: "Updated Name" } }
    assert_redirected_to admin_partners_url
  end

  test "should destroy partner" do
    partner = create(:partner)
    assert_difference("Partner.count", -1) do
      delete admin_partner_url(partner)
    end
    assert_redirected_to admin_partners_url
  end
end
