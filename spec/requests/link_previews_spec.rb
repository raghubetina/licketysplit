require "rails_helper"

RSpec.describe "Link previews", type: :request do
  let(:safari_9) { "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_1) AppleWebKit/601.2.4 (KHTML, like Gecko) Version/9.0.1 Safari/601.2.4" }
  let(:imessage_preview_fetcher) { "#{safari_9} facebookexternalhit/1.1 Facebot Twitterbot/1.0" }

  it "serves iMessage's preview fetcher the page and its Open Graph tags" do
    get root_path, headers: {"User-Agent" => imessage_preview_fetcher}

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('property="og:title" content="Lickety Split"')
    expect(response.body).to match(%r{property="og:image" content="http://www\.example\.com/assets/og-image-\w+\.png"})
  end

  it "still turns away a genuinely outdated Safari" do
    get root_path, headers: {"User-Agent" => safari_9}

    expect(response).to have_http_status(:not_acceptable)
  end
end
