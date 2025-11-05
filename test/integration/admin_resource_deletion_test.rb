require "test_helper"

class AdminResourceDeletionTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin_user = users(:admin)
    @regular_user = users(:regular_user)
  end

  # Test Notice deletion
  test "admin can delete a notice" do
    sign_in @admin_user
    notice = notices(:one)

    assert_difference('Notice.count', -1) do
      delete admin_notice_path(notice)
    end

    assert_redirected_to admin_notices_path
    assert_equal "Notice deleted successfully.", flash[:notice]
  end

  test "notice deletion requires admin privileges" do
    sign_in @regular_user
    notice = notices(:one)

    assert_no_difference('Notice.count') do
      delete admin_notice_path(notice)
    end

    assert_redirected_to root_path
    assert_equal "Access denied. Admin privileges required.", flash[:alert]
  end

  test "notice deletion requires authentication" do
    notice = notices(:one)

    assert_no_difference('Notice.count') do
      delete admin_notice_path(notice)
    end

    assert_redirected_to new_user_session_path
  end

  # Test Blog deletion
  test "admin can delete a blog post" do
    sign_in @admin_user
    blog = blogs(:one)

    assert_difference('Blog.count', -1) do
      delete admin_blog_path(blog)
    end

    assert_redirected_to admin_blogs_path
    assert_equal "Blog post deleted successfully.", flash[:notice]
  end

  test "blog deletion requires admin privileges" do
    sign_in @regular_user
    blog = blogs(:one)

    assert_no_difference('Blog.count') do
      delete admin_blog_path(blog)
    end

    assert_redirected_to root_path
    assert_equal "Access denied. Admin privileges required.", flash[:alert]
  end

  # Test Case Study deletion
  test "admin can delete a case study" do
    sign_in @admin_user
    case_study = case_studies(:one)

    assert_difference('CaseStudy.count', -1) do
      delete admin_case_study_path(case_study)
    end

    assert_redirected_to admin_case_studies_path
    assert_equal "Case study deleted successfully.", flash[:notice]
  end

  test "case study deletion requires admin privileges" do
    sign_in @regular_user
    case_study = case_studies(:one)

    assert_no_difference('CaseStudy.count') do
      delete admin_case_study_path(case_study)
    end

    assert_redirected_to root_path
    assert_equal "Access denied. Admin privileges required.", flash[:alert]
  end

  # Test Legal Document deletion
  test "admin can delete a legal document" do
    sign_in @admin_user
    legal_document = legal_documents(:one)

    assert_difference('LegalDocument.count', -1) do
      delete admin_legal_document_path(legal_document)
    end

    assert_redirected_to admin_legal_documents_path
    assert_equal "Legal document deleted successfully.", flash[:notice]
  end

  test "legal document deletion requires admin privileges" do
    sign_in @regular_user
    legal_document = legal_documents(:one)

    assert_no_difference('LegalDocument.count') do
      delete admin_legal_document_path(legal_document)
    end

    assert_redirected_to root_path
    assert_equal "Access denied. Admin privileges required.", flash[:alert]
  end

  # Test that deletion works for other existing admin resources
  test "admin can delete a product" do
    sign_in @admin_user
    product = products(:one)

    assert_difference('Product.count', -1) do
      delete admin_product_path(product)
    end

    assert_redirected_to admin_products_path
  end

  test "admin can delete a pricing plan" do
    sign_in @admin_user
    pricing_plan = pricing_plans(:one)

    assert_difference('PricingPlan.count', -1) do
      delete admin_pricing_plan_path(pricing_plan)
    end

    assert_redirected_to admin_pricing_plans_path
  end

  test "admin can delete a partner" do
    sign_in @admin_user
    partner = partners(:one)

    assert_difference('Partner.count', -1) do
      delete admin_partner_path(partner)
    end

    assert_redirected_to admin_partners_path
  end

  test "admin can delete a special offer" do
    sign_in @admin_user
    special_offer = special_offers(:one)

    assert_difference('SpecialOffer.count', -1) do
      delete admin_special_offer_path(special_offer)
    end

    assert_redirected_to admin_special_offers_path
  end

  test "admin can delete a trusted brand" do
    sign_in @admin_user
    trusted_brand = trusted_brands(:one)

    assert_difference('TrustedBrand.count', -1) do
      delete admin_trusted_brand_path(trusted_brand)
    end

    assert_redirected_to admin_trusted_brands_path
  end
end
