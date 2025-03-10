require "test_helper"

class AiInsightsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get ai_insights_index_url
    assert_response :success
  end
end
