# frozen_string_literal: true

# Copyright 2025 Daytona Platforms Inc.
# SPDX-License-Identifier: Apache-2.0

module Daytona
  module Services
    # Snapshot management service
    #
    # Provides methods for managing Daytona Snapshots (immutable sandbox images).
    #
    # @example
    #   # List snapshots
    #   snapshots = client.snapshot.list
    #
    #   # Create from image
    #   snapshot = client.snapshot.create("python:3.12-slim", name: "my-python")
    class SnapshotService
      # @param http_client [API::HttpClient] HTTP client for API calls
      def initialize(http_client)
        @http_client = http_client
      end

      # List all snapshots
      #
      # @param page [Integer, nil] Page number
      # @param limit [Integer, nil] Items per page
      # @return [Hash] Paginated list with :items, :total, :page, :total_pages
      #
      # @example
      #   result = client.snapshot.list(page: 1, limit: 10)
      #   result[:items].each { |s| puts s[:name] }
      def list(page: nil, limit: nil)
        params = {}
        params[:page] = page if page
        params[:limit] = limit if limit

        response = @http_client.get("/snapshots", params: params)

        {
          items: response["items"] || response[:items] || [],
          total: response["total"] || response[:total] || 0,
          page: response["page"] || response[:page] || 1,
          total_pages: response["totalPages"] || response["total_pages"] || response[:total_pages] || 1,
        }
      end

      # Get a snapshot by ID or name
      #
      # @param snapshot_id_or_name [String] Snapshot ID or name
      # @return [Hash] Snapshot data
      #
      # @raise [NotFoundError] If snapshot is not found
      def get(snapshot_id_or_name)
        @http_client.get("/snapshots/#{snapshot_id_or_name}")
      end

      # Create a snapshot from an image
      #
      # @param image [String, Image] Docker image or Image builder
      # @param name [String, nil] Snapshot name
      # @param entrypoint [Array<String>, nil] Container entrypoint
      # @param on_logs [Proc, nil] Callback for build logs
      # @return [Hash] Created snapshot
      #
      # @example From Docker image
      #   snapshot = client.snapshot.create("python:3.12-slim", name: "my-python")
      #
      # @example From Image builder
      #   image = Daytona::Image.debian_slim("3.12").pip_install("numpy", "pandas")
      #   snapshot = client.snapshot.create(image, name: "data-science")
      def create(image, name: nil, entrypoint: nil, on_logs: nil)
        body = {}
        body[:name] = name if name
        body[:entrypoint] = entrypoint if entrypoint

        if image.is_a?(String)
          body[:buildInfo] = {
            dockerfileContent: "FROM #{image}\n",
          }
        elsif image.respond_to?(:dockerfile)
          body[:buildInfo] = {
            dockerfileContent: image.dockerfile,
          }
        end

        response = @http_client.post("/snapshots", body: body)

        # Handle build logs if callback provided
        if on_logs && response["state"] == "building"
          poll_build_logs(response["id"], on_logs)
          response = get(response["id"])
        end

        response
      end

      # Delete a snapshot
      #
      # @param snapshot_id [String] Snapshot ID
      #
      # @example
      #   client.snapshot.delete("snap-123")
      def delete(snapshot_id)
        @http_client.delete("/snapshots/#{snapshot_id}")
      end

      private

      def poll_build_logs(snapshot_id, on_logs)
        loop do
          snapshot = get(snapshot_id)
          state = snapshot["state"] || snapshot[:state]

          break if %w[ready error failed].include?(state)

          sleep 1
        end
      end
    end
  end
end
