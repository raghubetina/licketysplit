class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern, unless: :link_preview_fetcher?

  private

  # iMessage fetches link previews as Safari 9 with these tokens appended, and
  # the useragent gem doesn't count that as a bot, so without this exemption
  # shared links unfurl as the 406 page.
  def link_preview_fetcher?
    request.user_agent.to_s.match?(/facebookexternalhit|Facebot|Twitterbot/)
  end
end
