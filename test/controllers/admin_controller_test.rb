require "test_helper"

class AdminControllerTest < ActionDispatch::IntegrationTest
  test "should get overview" do
    get admin_overview_url
    assert_response :success
  end
end
