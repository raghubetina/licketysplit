# Each receipt upload enqueues a paid OpenAI vision call, and the endpoint is
# anonymous, so throttle creation per IP to bound denial-of-wallet abuse.
class Rack::Attack
  throttle("checks/create per ip", limit: 10, period: 1.minute) do |request|
    request.ip if request.post? && request.path == "/checks"
  end

  # Broad safety net against generic floods hitting any endpoint.
  throttle("req/ip", limit: 300, period: 5.minutes, &:ip)

  self.throttled_responder = lambda do |_request|
    [429, {"Content-Type" => "text/plain"}, ["Too many requests. Please slow down and try again shortly.\n"]]
  end
end
