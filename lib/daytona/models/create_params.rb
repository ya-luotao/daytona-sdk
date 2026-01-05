# frozen_string_literal: true

# Copyright 2025 Daytona Platforms Inc.
# SPDX-License-Identifier: Apache-2.0

module Daytona
  module Models
    # Base parameters for creating a new Sandbox
    #
    # @example
    #   params = Daytona::Models::CreateSandboxBaseParams.new(
    #     name: "my-sandbox",
    #     language: "python",
    #     env_vars: { "DEBUG" => "true" }
    #   )
    class CreateSandboxBaseParams
      # @return [String, nil] Name of the Sandbox
      attr_accessor :name

      # @return [String, nil] Programming language for the Sandbox
      attr_accessor :language

      # @return [String, nil] OS user for the Sandbox
      attr_accessor :os_user

      # @return [Hash{String => String}, nil] Environment variables
      attr_accessor :env_vars

      # @return [Hash{String => String}, nil] Custom labels
      attr_accessor :labels

      # @return [Boolean, nil] Whether the Sandbox should be public
      attr_accessor :public

      # @return [Integer, nil] Auto-stop interval in minutes (default: 15, 0 = no auto-stop)
      attr_accessor :auto_stop_interval

      # @return [Integer, nil] Auto-archive interval in minutes (default: 7 days)
      attr_accessor :auto_archive_interval

      # @return [Integer, nil] Auto-delete interval in minutes (negative = disabled, 0 = immediate)
      attr_accessor :auto_delete_interval

      # @return [Array<VolumeMount>, nil] Volume mounts to attach
      attr_accessor :volumes

      # @return [Boolean, nil] Whether to block all network access
      attr_accessor :network_block_all

      # @return [String, nil] Comma-separated list of allowed CIDR addresses
      attr_accessor :network_allow_list

      # @return [Boolean, nil] Whether the Sandbox should be ephemeral
      attr_accessor :ephemeral

      def initialize(**kwargs)
        @name = kwargs[:name]
        @language = kwargs[:language]
        @os_user = kwargs[:os_user]
        @env_vars = kwargs[:env_vars]
        @labels = kwargs[:labels]
        @public = kwargs[:public]
        @auto_stop_interval = kwargs[:auto_stop_interval]
        @auto_archive_interval = kwargs[:auto_archive_interval]
        @auto_delete_interval = kwargs[:auto_delete_interval]
        @volumes = kwargs[:volumes]
        @network_block_all = kwargs[:network_block_all]
        @network_allow_list = kwargs[:network_allow_list]
        @ephemeral = kwargs[:ephemeral]

        # Handle ephemeral flag
        handle_ephemeral!
      end

      # Convert to hash for API requests
      #
      # @return [Hash]
      def to_h
        {
          name: @name,
          language: @language,
          osUser: @os_user,
          envVars: @env_vars,
          labels: @labels,
          public: @public,
          autoStopInterval: @auto_stop_interval,
          autoArchiveInterval: @auto_archive_interval,
          autoDeleteInterval: @auto_delete_interval,
          volumes: @volumes&.map(&:to_h),
          networkBlockAll: @network_block_all,
          networkAllowList: @network_allow_list,
        }.compact
      end

      private

      def handle_ephemeral!
        return unless @ephemeral

        if @auto_delete_interval && @auto_delete_interval != 0
          warn "[WARNING] 'ephemeral' and 'auto_delete_interval' cannot be used together. " \
               "auto_delete_interval will be set to 0."
        end
        @auto_delete_interval = 0
      end
    end

    # Parameters for creating a new Sandbox from an image
    #
    # @example
    #   params = Daytona::Models::CreateSandboxFromImageParams.new(
    #     image: "python:3.12-slim",
    #     resources: Daytona::Models::Resources.new(cpu: 2, memory: 4)
    #   )
    class CreateSandboxFromImageParams < CreateSandboxBaseParams
      # @return [String, Daytona::Image] Docker image to use
      attr_accessor :image

      # @return [Resources, nil] Resource configuration
      attr_accessor :resources

      def initialize(image:, resources: nil, **kwargs)
        super(**kwargs)
        @image = image
        @resources = resources
      end

      # Convert to hash for API requests
      #
      # @return [Hash]
      def to_h
        super.merge(
          image: @image.is_a?(String) ? @image : @image.to_h,
          resources: @resources&.to_h
        ).compact
      end
    end

    # Parameters for creating a new Sandbox from a snapshot
    #
    # @example
    #   params = Daytona::Models::CreateSandboxFromSnapshotParams.new(
    #     snapshot: "my-snapshot"
    #   )
    class CreateSandboxFromSnapshotParams < CreateSandboxBaseParams
      # @return [String, nil] Name of the snapshot to use
      attr_accessor :snapshot

      def initialize(snapshot: nil, **kwargs)
        super(**kwargs)
        @snapshot = snapshot
      end

      # Convert to hash for API requests
      #
      # @return [Hash]
      def to_h
        super.merge(snapshot: @snapshot).compact
      end
    end
  end
end
