# frozen_string_literal: true

# Helpers for testing toolbox-backed services.
#
# Services (FileSystem, Git, Process, etc.) extend Daytona::Services::BaseService
# and route their requests through the toolbox API at:
#   {api_base}/toolbox/{sandbox_id}/toolbox/{path}
#
# These helpers build a real service instance backed by a real HttpClient and
# expose a `toolbox_url` helper so specs can stub the underlying endpoints with
# WebMock without repeating the URL construction everywhere.
module ToolboxHelpers
  API_URL = "https://api.daytona.io"
  SANDBOX_ID = "sandbox-123"

  # Build an HttpClient pointed at the test API.
  #
  # @return [Daytona::API::HttpClient]
  def build_http_client(api_url: API_URL, api_key: "test-api-key")
    Daytona::API::HttpClient.new(base_url: api_url, api_key: api_key)
  end

  # Instantiate a service backed by a real HttpClient.
  #
  # @param service_class [Class] e.g. Daytona::Services::Git
  # @return [Daytona::Services::BaseService]
  def build_service(service_class, sandbox_id: SANDBOX_ID, http_client: build_http_client)
    service_class.new(
      http_client: http_client,
      sandbox_id: sandbox_id,
      get_toolbox_url: -> { "#{API_URL}/toolbox" }
    )
  end

  # Full URL for a toolbox endpoint path.
  #
  # @param path [String] e.g. "/git/add"
  # @return [String]
  def toolbox_url(path, sandbox_id: SANDBOX_ID, api_url: API_URL)
    "#{api_url}/toolbox/#{sandbox_id}/toolbox#{path}"
  end
end

RSpec.configure do |config|
  config.include ToolboxHelpers
end
