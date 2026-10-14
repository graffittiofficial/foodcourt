require "net/http"
require "json"
require "openssl"

class GoogleRoutes
  class Error < StandardError; end

  ROUTES_URL = URI("https://routes.googleapis.com/directions/v2:computeRoutes")

  def self.distance_km(origin_place_id:, destination_place_id:)
    api_key = ENV["GOOGLE_MAPS_SERVER_API_KEY"]
    raise Error, "Google Maps server API key is not configured" if api_key.blank?
    raise Error, "A Google Place ID is required for both locations" if origin_place_id.blank? || destination_place_id.blank?

    request = Net::HTTP::Post.new(ROUTES_URL)
    request["Content-Type"] = "application/json"
    request["X-Goog-Api-Key"] = api_key
    request["X-Goog-FieldMask"] = "routes.distanceMeters"
    request.body = {
      origin: { placeId: origin_place_id },
      destination: { placeId: destination_place_id },
      travelMode: "DRIVE",
      routingPreference: "TRAFFIC_UNAWARE"
    }.to_json

    response = Net::HTTP.start(ROUTES_URL.host, ROUTES_URL.port, use_ssl: true, open_timeout: 5, read_timeout: 10) do |http|
      http.request(request)
    end
    raise Error, "Google Routes API returned HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    meters = JSON.parse(response.body).dig("routes", 0, "distanceMeters")
    raise Error, "Google Routes API did not return a driving route" unless meters.is_a?(Numeric) && meters >= 0

    BigDecimal(meters.to_s) / 1000
  rescue JSON::ParserError => error
    raise Error, "Google Routes API returned invalid JSON: #{error.message}"
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError, OpenSSL::SSL::SSLError => error
    raise Error, "Google Routes API request failed: #{error.message}"
  end
end
