require "test_helper"

class SitemapsControllerTest < ActionDispatch::IntegrationTest
  test "serves public sitemap xml" do
    get "/sitemap.xml"

    assert_response :success
    assert_equal "application/xml", response.media_type
    assert_includes response.body, "<loc>http://www.example.com/</loc>"
    assert_includes response.body, "<loc>http://www.example.com/work</loc>"
  end
end
