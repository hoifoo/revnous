require "application_system_test_case"

class HomePageTest < ApplicationSystemTestCase
  test "visiting the home page" do
    visit root_url

    assert_selector "h1, h2, .navbar", minimum: 1
  end
end
