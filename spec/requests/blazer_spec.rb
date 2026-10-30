require "rails_helper"

RSpec.describe "Blazer", type: :request do
  let(:auth_headers) do
    {"Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("test-admin", "test-password")}
  end

  def script_policy
    response.headers.fetch("Content-Security-Policy").split("; ").find { |directive| directive.start_with?("script-src ") }
  end

  def script_nonce
    script_policy[/'nonce-([^']+)'/, 1]
  end

  it "requires authentication before serving the editor" do
    get "/analytics/queries/new"

    expect(response).to have_http_status(:unauthorized)
    expect(script_policy).to eq("script-src 'self'")
  end

  it "authorizes the editor's inline scripts with matching nonces" do
    get "/analytics/queries/new", headers: auth_headers

    expect(response).to have_http_status(:ok)
    nonce = script_nonce
    expect(nonce).to be_present
    expect(script_policy).to eq("script-src 'self' 'nonce-#{nonce}'")

    scripts = Nokogiri::HTML(response.body).css("script:not([src])")
    expect(scripts).not_to be_empty
    expect(scripts.pluck("nonce")).to all(eq(nonce))
    expect(response.headers.fetch("Content-Security-Policy")).to include("style-src 'self' 'unsafe-inline' https://fonts.googleapis.com")
  end

  it "keeps the page's nonce across subsequent requests in the same session" do
    get "/analytics/queries/new", headers: auth_headers
    nonce = script_nonce

    get "/analytics", headers: auth_headers

    expect(script_nonce).to eq(nonce)
  end

  it "gives a separate browser session a different nonce" do
    get "/analytics/queries/new", headers: auth_headers
    nonce = script_nonce

    other_browser = ActionDispatch::Integration::Session.new(Rails.application)
    other_browser.get "/analytics/queries/new", headers: auth_headers

    expect(other_browser.response).to have_http_status(:ok)
    expect(other_browser.response.headers.fetch("Content-Security-Policy")).not_to include("'nonce-#{nonce}'")
  end

  it "keeps the public app's script policy restricted to same-origin scripts" do
    get "/analytics/queries/new", headers: auth_headers
    get "/"

    expect(response).to have_http_status(:ok)
    expect(script_policy).to eq("script-src 'self'")
  end
end
