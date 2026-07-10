# Blazer is mounted at /analytics and exposes an ad-hoc SQL console over the
# application database. It ships with no authentication, so we gate it here.
#
# - With credentials set: require HTTP Basic auth.
# - In production without credentials: block entirely (fail closed) rather than
#   leave the whole database readable to anyone.
# - In development/test without credentials: leave open for convenience.
Rails.application.config.to_prepare do
  username = ENV["BLAZER_USERNAME"]
  password = ENV["BLAZER_PASSWORD"]

  if username.present? && password.present?
    Blazer::BaseController.http_basic_authenticate_with(name: username, password: password)
  elsif Rails.env.production?
    Blazer::BaseController.before_action { head :forbidden }
  end
end
