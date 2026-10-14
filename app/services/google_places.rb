require "net/http"
require "json"
require "openssl"
require "uri"

class GooglePlaces
  class Error < StandardError; end

  def self.address_for(place_id)
    api_key = ENV["GOOGLE_MAPS_SERVER_API_KEY"]
    raise Error, "Google Maps server API key is not configured" if api_key.blank?
    raise Error, "A Google Place ID is required" if place_id.blank?

    uri = URI("https://places.googleapis.com/v1/places/#{URI::DEFAULT_PARSER.escape(place_id)}")
    request = Net::HTTP::Get.new(uri)
    request["X-Goog-Api-Key"] = api_key
    request["X-Goog-FieldMask"] = "id,formattedAddress,addressComponents"
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) do |http|
      http.request(request)
    end
    raise Error, "Google Places API returned HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    place = JSON.parse(response.body)
    components = place.fetch("addressComponents", [])
    street_number = component(components, "street_number")
    route = component(components, "route")
    address = {
      google_place_id: place.fetch("id"),
      address_line1: [ street_number, route ].compact_blank.join(" "),
      city: component(components, "locality") || component(components, "postal_town"),
      region: component(components, "administrative_area_level_1", short_text: true),
      postal_code: component(components, "postal_code"),
      country_code: component(components, "country", short_text: true)&.upcase
    }
    raise Error, "Selected place is not a complete postal address" if address.values.any?(&:blank?)

    address
  rescue JSON::ParserError, KeyError => error
    raise Error, "Google Places API returned incomplete address data: #{error.message}"
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError, OpenSSL::SSL::SSLError => error
    raise Error, "Google Places API request failed: #{error.message}"
  end

  def self.component(components, type, short_text: false)
    entry = components.find { |item| item.fetch("types", []).include?(type) }
    entry&.fetch(short_text ? "shortText" : "longText", nil)
  end
  private_class_method :component
end
