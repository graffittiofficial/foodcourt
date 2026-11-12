require "test_helper"

class ErrorsControllerTest < ActionDispatch::IntegrationTest
  test "error endpoints render the corresponding HTTP status" do
    {
      "/404" => :not_found,
      "/422" => :unprocessable_entity,
      "/500" => :internal_server_error
    }.each do |path, status|
      get path
      assert_response status
    end
  end
end
