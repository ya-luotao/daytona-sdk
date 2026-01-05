# frozen_string_literal: true

# Copyright 2025 Daytona Platforms Inc.
# SPDX-License-Identifier: Apache-2.0

module Daytona
  module Models
    # Resources configuration for Sandbox.
    #
    # @example
    #   resources = Daytona::Models::Resources.new(
    #     cpu: 2,
    #     memory: 4,  # 4GiB RAM
    #     disk: 20,   # 20GiB disk
    #     gpu: 1
    #   )
    class Resources
      # @return [Integer, nil] Number of CPU cores to allocate
      attr_accessor :cpu

      # @return [Integer, nil] Amount of memory in GiB to allocate
      attr_accessor :memory

      # @return [Integer, nil] Amount of disk space in GiB to allocate
      attr_accessor :disk

      # @return [Integer, nil] Number of GPUs to allocate
      attr_accessor :gpu

      # Initialize a new Resources configuration
      #
      # @param cpu [Integer, nil] Number of CPU cores
      # @param memory [Integer, nil] Memory in GiB
      # @param disk [Integer, nil] Disk space in GiB
      # @param gpu [Integer, nil] Number of GPUs
      def initialize(cpu: nil, memory: nil, disk: nil, gpu: nil)
        @cpu = cpu
        @memory = memory
        @disk = disk
        @gpu = gpu
      end

      # Convert to hash for API requests
      #
      # @return [Hash] Resources as a hash (excluding nil values)
      def to_h
        {
          cpu: @cpu,
          memory: @memory,
          disk: @disk,
          gpu: @gpu,
        }.compact
      end

      # Create from API response hash
      #
      # @param data [Hash] API response data
      # @return [Resources]
      def self.from_hash(data)
        return nil if data.nil?

        new(
          cpu: data["cpu"] || data[:cpu],
          memory: data["memory"] || data[:memory],
          disk: data["disk"] || data[:disk],
          gpu: data["gpu"] || data[:gpu]
        )
      end
    end
  end
end
