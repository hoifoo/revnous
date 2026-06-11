# Rate limiting for the public API. Rules apply only to /api/ paths so the
# rest of the site is unaffected. Uses Rails.cache (solid_cache) as the store.
class Rack::Attack
  # Per-IP throttle: 60 requests/minute to the API.
  throttle("api/ip", limit: 60, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/api/")
  end

  # Burst guard: 10 requests/second to the API.
  throttle("api/ip/burst", limit: 10, period: 1.second) do |req|
    req.ip if req.path.start_with?("/api/")
  end

  # JSON 429 with Retry-After when throttled.
  self.throttled_responder = lambda do |request|
    match_data = request.env["rack.attack.match_data"] || {}
    retry_after = (match_data[:period] || 60).to_i
    [
      429,
      { "Content-Type" => "application/json", "Retry-After" => retry_after.to_s },
      [ { error: "rate_limited", retry_after: retry_after }.to_json ]
    ]
  end
end
