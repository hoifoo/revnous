require "test_helper"

class Admin::ProductsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get admin_products_url
    assert_response :success
  end

  test "should get new" do
    get new_admin_product_url
    assert_response :success
  end

  test "should create product" do
    assert_difference("Product.count") do
      post admin_products_url, params: { product: { name: "Test Product" } }
    end
    assert_redirected_to admin_products_url
  end

  test "should get edit" do
    product = create(:product)
    get edit_admin_product_url(product)
    assert_response :success
  end

  test "should update product" do
    product = create(:product)
    patch admin_product_url(product), params: { product: { name: "Updated Name" } }
    assert_redirected_to admin_products_url
  end

  test "should destroy product" do
    product = create(:product)
    assert_difference("Product.count", -1) do
      delete admin_product_url(product)
    end
    assert_redirected_to admin_products_url
  end
end
