# Be sure to restart your server when you modify this file.

# Defense-in-depth against injected content (complements sanitizing AI reasoning
# before render). script-src is kept to :self — the app ships a single bundled
# module and has no inline scripts — so injected <script> cannot execute.
# style-src allows inline styles (the app uses style="" attributes and Bootstrap)
# and Google Fonts; img-src allows Cloudinary-delivered receipts and data URIs.
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.base_uri :self
    policy.font_src :self, :data, "https://fonts.gstatic.com"
    policy.img_src :self, :data, "https://res.cloudinary.com"
    policy.object_src :none
    policy.script_src :self
    policy.style_src :self, :unsafe_inline, "https://fonts.googleapis.com"
    policy.connect_src :self
    policy.frame_ancestors :self
  end
end
