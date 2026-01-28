ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

require 'webmock/minitest'
require 'mocha/minitest'

require 'sidekiq_unique_jobs/testing'
require 'sidekiq/testing'
Sidekiq::Testing.fake!


class ActiveSupport::TestCase
  # Make sure Shoulda Matchers are configured correctly
  Shoulda::Matchers.configure do |config|
    config.integrate do |with|
      with.test_framework :minitest
      with.library :rails
    end
  end

  # If you need transactional fixtures (common for DB tests, less so for controller tests)
  # self.use_transactional_fixtures = true

  # If you need instatiated fixtures
  # fixtures :all

  # Add more helper methods to be used by all tests here...
end

# Ensure WebMock blocks external connections by default, allowing localhost if needed (e.g., Capybara)
WebMock.disable_net_connect!(allow_localhost: true)