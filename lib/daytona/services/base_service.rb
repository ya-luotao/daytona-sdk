# frozen_string_literal: true

# Copyright 2025 Daytona Platforms Inc.
# SPDX-License-Identifier: Apache-2.0

module Daytona
  module Services
    # Base class for all Sandbox services
    #
    # Provides common functionality for toolbox API communication.
    class BaseService
      # @param http_client [API::HttpClient] HTTP client
      # @param sandbox_id [String] Sandbox ID
      # @param get_toolbox_url [Proc] Function to get toolbox URL
      def initialize(http_client:, sandbox_id:, get_toolbox_url:)
        @http_client = http_client
        @sandbox_id = sandbox_id
        @get_toolbox_url = get_toolbox_url
        @toolbox_url = nil
        @toolbox_client = nil
      end

      protected

      # Ensure toolbox URL is initialized
      #
      # The toolbox API is accessed through the main API at:
      #   {api_base}/toolbox/{sandbox_id}/toolbox
      #
      # NOT through the proxyToolboxUrl which is for port forwarding
      def ensure_toolbox_url!
        return if @toolbox_url

        # Build toolbox URL from the main API base URL
        # The path is: /toolbox/{sandbox_id}/toolbox
        api_base = @http_client.base_url
        @toolbox_url = "#{api_base}toolbox/#{@sandbox_id}/toolbox"
      end

      # Get toolbox HTTP client
      #
      # @return [API::HttpClient]
      def toolbox_client
        ensure_toolbox_url!
        @toolbox_client ||= API::HttpClient.new(
          base_url: @toolbox_url,
          api_key: @http_client.instance_variable_get(:@api_key),
          jwt_token: @http_client.instance_variable_get(:@jwt_token),
          organization_id: @http_client.instance_variable_get(:@organization_id)
        )
      end

      # Perform GET request to toolbox API
      #
      # @param path [String] API path
      # @param params [Hash] Query parameters
      # @param timeout [Integer] Request timeout
      # @return [Hash, Array, String] Response
      def toolbox_get(path, params: {}, timeout: 120)
        toolbox_client.get(path, params: params, timeout: timeout)
      end

      # Perform POST request to toolbox API
      #
      # @param path [String] API path
      # @param body [Hash, nil] Request body
      # @param timeout [Integer] Request timeout
      # @return [Hash, Array, String] Response
      def toolbox_post(path, body: nil, timeout: 120)
        toolbox_client.post(path, body: body, timeout: timeout)
      end

      # Perform PUT request to toolbox API
      #
      # @param path [String] API path
      # @param body [Hash, nil] Request body
      # @param timeout [Integer] Request timeout
      # @return [Hash, Array, String] Response
      def toolbox_put(path, body: nil, timeout: 120)
        toolbox_client.put(path, body: body, timeout: timeout)
      end

      # Perform DELETE request to toolbox API
      #
      # @param path [String] API path
      # @param timeout [Integer] Request timeout
      # @return [Hash, Array, String, nil] Response
      def toolbox_delete(path, timeout: 120)
        toolbox_client.delete(path, timeout: timeout)
      end

      # Upload file to toolbox API
      #
      # @param path [String] API path
      # @param file_path [String] Local file path
      # @param timeout [Integer] Request timeout
      # @return [Hash, Array, String] Response
      def toolbox_upload(path, file_path:, timeout: 1800)
        toolbox_client.upload_file(path, file_path: file_path, timeout: timeout)
      end

      # Download file from toolbox API
      #
      # @param path [String] API path
      # @param timeout [Integer] Request timeout
      # @return [String] Binary content
      def toolbox_download(path, timeout: 1800)
        toolbox_client.download_file(path, timeout: timeout)
      end
    end
  end
end
