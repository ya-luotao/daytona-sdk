# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
end if ENV["COVERAGE"]

require "daytona"
require "webmock/rspec"
require "vcr"

VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.filter_sensitive_data("<API_KEY>") { ENV.fetch("DAYTONA_API_KEY", "test-api-key") }
  # Allow WebMock stubs to work without VCR cassettes
  config.allow_http_connections_when_no_cassette = true
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Run specs in random order
  config.order = :random
  Kernel.srand config.seed
end
