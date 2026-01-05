# frozen_string_literal: true

# Copyright 2025 Daytona Platforms Inc.
# SPDX-License-Identifier: Apache-2.0

module Daytona
  # Main client for interacting with the Daytona API.
  #
  # This class provides methods to create, manage, and interact with Daytona Sandboxes.
  # It can be initialized either with explicit configuration or using environment variables.
  #
  # @example Using environment variables
  #   # Set DAYTONA_API_KEY in your environment
  #   client = Daytona::Client.new
  #   sandbox = client.create
  #
  # @example Using explicit configuration
  #   client = Daytona::Client.new(
  #     api_key: "your-api-key",
  #     api_url: "https://your-api.com",
  #     target: "us"
  #   )
  #   sandbox = client.create
  #
  # @example Using Configuration object
  #   config = Daytona::Configuration.new(api_key: "your-api-key")
  #   client = Daytona::Client.new(config)
  class Client
    # @return [Services::VolumeService] Service for managing volumes
    attr_reader :volume

    # @return [Services::SnapshotService] Service for managing snapshots
    attr_reader :snapshot

    # @return [Configuration] Client configuration
    attr_reader :config

    # Initialize a new Daytona client
    #
    # @param config_or_options [Configuration, Hash, nil] Configuration object or options hash
    # @option config_or_options [String] :api_key API key for authentication
    # @option config_or_options [String] :jwt_token JWT token for authentication
    # @option config_or_options [String] :organization_id Organization ID for JWT auth
    # @option config_or_options [String] :api_url API URL
    # @option config_or_options [String] :target Target runner location
    #
    # @raise [ConfigurationError] If API key or JWT token is not provided
    def initialize(config_or_options = nil)
      @config = resolve_config(config_or_options)
      @config.validate!

      @http_client = API::HttpClient.new(
        base_url: @config.api_url,
        api_key: @config.api_key,
        jwt_token: @config.jwt_token,
        organization_id: @config.organization_id
      )

      @default_language = Models::CodeLanguage::PYTHON
      @proxy_toolbox_url = nil
      @proxy_toolbox_url_mutex = Mutex.new

      # Initialize services
      @volume = Services::VolumeService.new(@http_client)
      @snapshot = Services::SnapshotService.new(@http_client)
    end

    # Create a new Sandbox
    #
    # @param params [Models::CreateSandboxFromSnapshotParams, Models::CreateSandboxFromImageParams, nil]
    #   Parameters for Sandbox creation. If not provided, creates a default Python sandbox.
    # @param timeout [Float] Timeout in seconds for sandbox creation (default: 60, 0 = no timeout)
    # @param on_snapshot_create_logs [Proc, nil] Callback for snapshot creation logs
    #
    # @return [Sandbox] The created Sandbox instance
    #
    # @raise [DaytonaError] If timeout is negative or sandbox fails to start
    #
    # @example Create a default Python sandbox
    #   sandbox = client.create
    #
    # @example Create a sandbox from snapshot
    #   params = Daytona::Models::CreateSandboxFromSnapshotParams.new(
    #     snapshot: "my-snapshot",
    #     language: "python",
    #     env_vars: { "DEBUG" => "true" }
    #   )
    #   sandbox = client.create(params, timeout: 120)
    #
    # @example Create a sandbox from image
    #   params = Daytona::Models::CreateSandboxFromImageParams.new(
    #     image: "python:3.12-slim",
    #     resources: Daytona::Models::Resources.new(cpu: 2, memory: 4)
    #   )
    #   sandbox = client.create(params)
    def create(params = nil, timeout: 60, on_snapshot_create_logs: nil)
      raise DaytonaError, "Timeout must be a non-negative number" if timeout.negative?

      # Default to Python sandbox from default snapshot
      params ||= Models::CreateSandboxFromSnapshotParams.new(language: @default_language)
      params.language ||= @default_language

      validate_create_params!(params)

      # Build request body
      body = build_create_sandbox_body(params)

      # Create the sandbox
      start_time = Time.now
      response = @http_client.post("/sandbox", body: body, timeout: timeout.zero? ? nil : timeout)

      # Handle build logs if creating from image
      if response["state"] == "pending_build" && on_snapshot_create_logs
        handle_build_logs(response["id"], on_snapshot_create_logs, timeout, start_time)
        response = @http_client.get("/sandbox/#{response['id']}")
      end

      # Create Sandbox instance
      sandbox = Sandbox.new(
        sandbox_data: response,
        http_client: @http_client,
        get_toolbox_url: method(:get_proxy_toolbox_url)
      )

      # Wait for sandbox to start if not already started
      unless sandbox.state == "started"
        elapsed = Time.now - start_time
        remaining = timeout.zero? ? nil : [0.001, timeout - elapsed].max
        sandbox.wait_for_start(timeout: remaining)
      end

      sandbox
    end

    # Get a Sandbox by ID or name
    #
    # @param sandbox_id_or_name [String] The ID or name of the Sandbox
    # @return [Sandbox] The Sandbox instance
    #
    # @raise [DaytonaError] If sandbox_id_or_name is not provided
    # @raise [NotFoundError] If sandbox is not found
    #
    # @example
    #   sandbox = client.get("my-sandbox-id")
    #   puts sandbox.state
    def get(sandbox_id_or_name)
      raise DaytonaError, "sandbox_id_or_name is required" if sandbox_id_or_name.nil? || sandbox_id_or_name.empty?

      response = @http_client.get("/sandbox/#{sandbox_id_or_name}")

      # Validate response is a hash (single sandbox)
      unless response.is_a?(Hash)
        # If it's a string that looks like JSON, try to parse it
        if response.is_a?(String) && response.start_with?('{')
          begin
            parsed = JSON.parse(response)
            if parsed.is_a?(Hash)
              Rails.logger.info "[Daytona::Client] Parsed string response as JSON" if defined?(Rails)
              response = parsed
            end
          rescue JSON::ParserError => e
            Rails.logger.error "[Daytona::Client] Failed to parse response as JSON: #{e.message}" if defined?(Rails)
          end
        end
      end

      # Still not a hash? Raise error with details
      unless response.is_a?(Hash)
        response_preview = response.to_s[0..500] rescue response.class.to_s
        Rails.logger.error "[Daytona::Client] Invalid response type #{response.class} for sandbox #{sandbox_id_or_name}: #{response_preview}" if defined?(Rails)
        raise DaytonaError, "Invalid API response (#{response.class}): #{response_preview}"
      end

      Sandbox.new(
        sandbox_data: response,
        http_client: @http_client,
        get_toolbox_url: method(:get_proxy_toolbox_url)
      )
    end

    # Find first Sandbox matching criteria
    #
    # @param sandbox_id_or_name [String, nil] The ID or name of the Sandbox
    # @param labels [Hash{String => String}, nil] Labels to filter by
    # @return [Sandbox] First matching Sandbox
    #
    # @raise [DaytonaError] If no sandbox is found
    #
    # @example
    #   sandbox = client.find_one(labels: { "env" => "production" })
    def find_one(sandbox_id_or_name: nil, labels: nil)
      return get(sandbox_id_or_name) if sandbox_id_or_name

      result = list(labels: labels, page: 1, limit: 1)
      raise DaytonaError, "No sandbox found with labels #{labels}" if result.items.empty?

      result.items.first
    end

    # List Sandboxes with optional filtering
    #
    # @param labels [Hash{String => String}, nil] Labels to filter by
    # @param page [Integer, nil] Page number (starting from 1)
    # @param limit [Integer, nil] Maximum items per page
    # @return [PaginatedSandboxes] Paginated list of Sandboxes
    #
    # @raise [DaytonaError] If page or limit is less than 1
    #
    # @example
    #   result = client.list(labels: { "env" => "dev" }, page: 1, limit: 10)
    #   result.items.each { |s| puts "#{s.id}: #{s.state}" }
    def list(labels: nil, page: nil, limit: nil)
      raise DaytonaError, "page must be a positive integer" if page && page < 1
      raise DaytonaError, "limit must be a positive integer" if limit && limit < 1

      params = {}
      params[:labels] = labels.to_json if labels
      params[:page] = page if page
      params[:limit] = limit if limit

      response = @http_client.get("/sandbox", params: params)

      # Handle both array response (non-paginated) and object response (paginated)
      sandbox_list = if response.is_a?(Array)
        response
      else
        response["items"] || []
      end

      items = sandbox_list.map do |sandbox_data|
        Sandbox.new(
          sandbox_data: sandbox_data,
          http_client: @http_client,
          get_toolbox_url: method(:get_proxy_toolbox_url)
        )
      end

      # For array responses, calculate pagination from the result
      total = response.is_a?(Array) ? response.length : (response["total"] || items.length)
      current_page = response.is_a?(Array) ? 1 : (response["page"] || 1)
      total_pages = response.is_a?(Array) ? 1 : (response["totalPages"] || response["total_pages"] || 1)

      PaginatedSandboxes.new(
        items: items,
        total: total,
        page: current_page,
        total_pages: total_pages
      )
    end

    # Start a Sandbox
    #
    # @param sandbox [Sandbox] The Sandbox to start
    # @param timeout [Float] Timeout in seconds (default: 60, 0 = no timeout)
    #
    # @raise [DaytonaError] If timeout is negative or sandbox fails to start
    def start(sandbox, timeout: 60)
      sandbox.start(timeout: timeout)
    end

    # Stop a Sandbox
    #
    # @param sandbox [Sandbox] The Sandbox to stop
    # @param timeout [Float] Timeout in seconds (default: 60, 0 = no timeout)
    #
    # @raise [DaytonaError] If timeout is negative or sandbox fails to stop
    def stop(sandbox, timeout: 60)
      sandbox.stop(timeout: timeout)
    end

    # Delete a Sandbox
    #
    # @param sandbox [Sandbox] The Sandbox to delete
    # @param timeout [Float] Timeout in seconds (default: 60, 0 = no timeout)
    #
    # @raise [DaytonaError] If sandbox fails to delete
    #
    # @example
    #   sandbox = client.create
    #   # ... use sandbox ...
    #   client.delete(sandbox)
    def delete(sandbox, timeout: 60)
      sandbox.delete(timeout: timeout)
    end

    private

    def resolve_config(config_or_options)
      case config_or_options
      when Configuration
        config_or_options
      when Hash
        Configuration.new(**config_or_options)
      when nil
        Daytona.configuration || Configuration.new
      else
        raise ArgumentError, "Expected Configuration, Hash, or nil"
      end
    end

    def validate_create_params!(params)
      if params.auto_stop_interval && params.auto_stop_interval.negative?
        raise DaytonaError, "auto_stop_interval must be a non-negative integer"
      end

      if params.auto_archive_interval && params.auto_archive_interval.negative?
        raise DaytonaError, "auto_archive_interval must be a non-negative integer"
      end
    end

    def build_create_sandbox_body(params)
      body = {
        name: params.name,
        user: params.os_user,
        env: params.env_vars || {},
        labels: params.labels,
        public: params.public,
        target: @config.target,
        autoStopInterval: params.auto_stop_interval,
        autoArchiveInterval: params.auto_archive_interval,
        autoDeleteInterval: params.auto_delete_interval,
        volumes: params.volumes&.map(&:to_h),
        networkBlockAll: params.network_block_all,
        networkAllowList: params.network_allow_list,
      }.compact

      # Handle snapshot-based creation
      if params.respond_to?(:snapshot) && params.snapshot
        body[:snapshot] = params.snapshot
      end

      # Handle image-based creation
      if params.respond_to?(:image) && params.image
        image_content = params.image.is_a?(String) ? params.image : params.image.dockerfile
        body[:buildInfo] = {
          dockerfileContent: "FROM #{image_content}\n",
        }
      end

      # Handle resources
      if params.respond_to?(:resources) && params.resources
        body[:cpu] = params.resources.cpu
        body[:memory] = params.resources.memory
        body[:disk] = params.resources.disk
        body[:gpu] = params.resources.gpu
      end

      body.compact
    end

    def handle_build_logs(sandbox_id, callback, timeout, start_time)
      # Poll for build logs and status
      loop do
        elapsed = Time.now - start_time
        break if !timeout.zero? && elapsed >= timeout

        response = @http_client.get("/sandbox/#{sandbox_id}")
        state = response["state"]

        break if %w[started starting error build_failed].include?(state)

        sleep 1
      end
    end

    def get_proxy_toolbox_url
      return @proxy_toolbox_url if @proxy_toolbox_url

      @proxy_toolbox_url_mutex.synchronize do
        return @proxy_toolbox_url if @proxy_toolbox_url

        config_response = @http_client.get("/config")
        @proxy_toolbox_url = config_response["proxyToolboxUrl"] || config_response["proxy_toolbox_url"]
      end

      @proxy_toolbox_url
    end
  end

  # Paginated collection of Sandboxes
  class PaginatedSandboxes
    # @return [Array<Sandbox>] List of sandboxes on this page
    attr_reader :items

    # @return [Integer] Total number of sandboxes
    attr_reader :total

    # @return [Integer] Current page number
    attr_reader :page

    # @return [Integer] Total number of pages
    attr_reader :total_pages

    def initialize(items:, total:, page:, total_pages:)
      @items = items
      @total = total
      @page = page
      @total_pages = total_pages
    end

    # Check if there are more pages
    #
    # @return [Boolean]
    def next_page?
      @page < @total_pages
    end

    # Check if this is the first page
    #
    # @return [Boolean]
    def first_page?
      @page == 1
    end

    # Iterate over items
    #
    # @yield [Sandbox] Each sandbox in the page
    def each(&block)
      @items.each(&block)
    end

    include Enumerable
  end
end
