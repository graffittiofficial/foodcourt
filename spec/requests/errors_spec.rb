require "rails_helper"

RSpec.describe "Error pages", type: :request do
  it "renders the not found page for unknown paths" do
    get "/this-page-does-not-exist"

    expect(response).to have_http_status(:not_found)
    expect(response.body).to include("Page not found")
  end

  it "renders the unprocessable entity page" do
    get "/422"

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("We couldn't process that request")
  end

  it "renders a generic server error page without exception details" do
    get "/500"

    expect(response).to have_http_status(:internal_server_error)
    expect(response.body).to include("Something went wrong")
    expect(response.body).not_to include("ActionController::")
  end
end
