require "test_helper"

class PricingControllerTest < ActionDispatch::IntegrationTest
  test "should get product pricing" do
    product = create(:product, name: "Test Product")
    get product_pricing_url(product_slug: product.name.parameterize)
    assert_response :success
  end
end
