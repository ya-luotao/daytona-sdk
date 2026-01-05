# frozen_string_literal: true

# Copyright 2025 Daytona Platforms Inc.
# SPDX-License-Identifier: Apache-2.0

module Daytona
  module Models
    # Represents a Volume mount configuration for a Sandbox
    #
    # @example
    #   mount = Daytona::Models::VolumeMount.new(
    #     volume_id: "vol-123",
    #     mount_path: "/data"
    #   )
    class VolumeMount
      # @return [String] ID of the volume to mount
      attr_accessor :volume_id

      # @return [String] Path where the volume will be mounted in the sandbox
      attr_accessor :mount_path

      # @return [String, nil] Optional S3 subpath/prefix within the volume to mount
      attr_accessor :subpath

      # Initialize a new VolumeMount
      #
      # @param volume_id [String] ID of the volume
      # @param mount_path [String] Mount path in the sandbox
      # @param subpath [String, nil] Optional subpath within the volume
      def initialize(volume_id:, mount_path:, subpath: nil)
        @volume_id = volume_id
        @mount_path = mount_path
        @subpath = subpath
      end

      # Convert to hash for API requests
      #
      # @return [Hash]
      def to_h
        {
          volumeId: @volume_id,
          mountPath: @mount_path,
          subpath: @subpath,
        }.compact
      end

      # Create from API response hash
      #
      # @param data [Hash]
      # @return [VolumeMount]
      def self.from_hash(data)
        return nil if data.nil?

        new(
          volume_id: data["volumeId"] || data["volume_id"] || data[:volume_id],
          mount_path: data["mountPath"] || data["mount_path"] || data[:mount_path],
          subpath: data["subpath"] || data[:subpath]
        )
      end
    end

    # Represents a Daytona Volume (shared storage)
    class Volume
      # @return [String] Unique identifier for the Volume
      attr_accessor :id

      # @return [String] Name of the Volume
      attr_accessor :name

      # @return [String] Organization ID of the Volume
      attr_accessor :organization_id

      # @return [String] State of the Volume
      attr_accessor :state

      # @return [String] Date and time when the Volume was created
      attr_accessor :created_at

      # @return [String] Date and time when the Volume was last updated
      attr_accessor :updated_at

      # @return [String] Date and time when the Volume was last used
      attr_accessor :last_used_at

      # Initialize a new Volume
      def initialize(id:, name:, organization_id:, state:, created_at:, updated_at:, last_used_at:)
        @id = id
        @name = name
        @organization_id = organization_id
        @state = state
        @created_at = created_at
        @updated_at = updated_at
        @last_used_at = last_used_at
      end

      # Create from API response hash
      #
      # @param data [Hash]
      # @return [Volume]
      def self.from_hash(data)
        return nil if data.nil?

        new(
          id: data["id"] || data[:id],
          name: data["name"] || data[:name],
          organization_id: data["organizationId"] || data["organization_id"] || data[:organization_id],
          state: data["state"] || data[:state],
          created_at: data["createdAt"] || data["created_at"] || data[:created_at],
          updated_at: data["updatedAt"] || data["updated_at"] || data[:updated_at],
          last_used_at: data["lastUsedAt"] || data["last_used_at"] || data[:last_used_at]
        )
      end
    end
  end
end
