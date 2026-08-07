# Each receipt upload enqueues a paid OpenAI vision call, and the endpoint is
# anonymous, so throttle creation per IP to bound denial-of-wallet abuse.
class Rack::Attack
  throttle("checks/create per ip", limit: 10, period: 1.minute) do |request|
    request.ip if request.post? && request.path == "/checks"
  end

  # Broad safety net against generic floods hitting any endpoint.
  throttle("req/ip", limit: 300, period: 5.minutes, &:ip)

  # This app serves no PHP and no WordPress. Scanner sweeps for those paths are
  # pure noise, and letting them reach Rails means a RoutingError per probe.
  blocklist("php and wordpress probes") do |request|
    request.path.end_with?(".php") || request.path.start_with?("/wp-")
  end

  self.throttled_responder = lambda do |_request|
    [429, {"Content-Type" => "text/plain"}, ["Too many requests. Please slow down and try again shortly.\n"]]
  end
end
