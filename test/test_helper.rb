ENV["RAILS_ENV"] ||= "test"
COVERAGE_ENABLED = ENV["COVERAGE"] == "true"
if COVERAGE_ENABLED
  require "simplecov"
  SimpleCov.start do
    track_files "app/**/*.rb"
    add_filter "/config/"
    add_filter "/test/"
    add_filter "/spec/"
    minimum_coverage line: 80
  end
end

require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"

module ActiveSupport
  class TestCase
    # Keep normal runs parallel while collecting accurate single-process coverage.
    parallelize(workers: COVERAGE_ENABLED ? 1 : :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    def create_organization(name: "Test Organization")
      Organization.create!(name: name)
    end

    def create_restaurant(name:, organization: nil, **attributes)
      Restaurant.create!(
        **attributes,
        name: name,
        organization: organization || create_organization(name: "#{name} Organization")
      )
    end

    def create_staff(email_address:, restaurants:)
      user = User.create!(email_address: email_address, password: "password")
      restaurants.each { |restaurant| RestaurantMembership.create!(restaurant: restaurant, user: user) }
      user
    end
  end
end
