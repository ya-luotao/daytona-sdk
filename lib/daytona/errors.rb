# frozen_string_literal: true

# Copyright 2025 Daytona Platforms Inc.
# SPDX-License-Identifier: Apache-2.0

module Daytona
  # Base error class for all Daytona SDK errors
  #
  # @attr_reader [Integer, nil] status_code HTTP status code if available
  # @attr_reader [Hash] headers Response headers if available
  class DaytonaError < StandardError
    attr_reader :status_code, :headers

    # Initialize a new DaytonaError
    #
    # @param message [String] Error message
    # @param status_code [Integer, nil] HTTP status code if available
    # @param headers [Hash] Response headers if available
    def initialize(message, status_code: nil, headers: {})
      @status_code = status_code
      @headers = headers || {}
      super(message)
    end
  end

  # Error raised when a requested resource is not found (HTTP 404)
  class NotFoundError < DaytonaError; end

  # Error raised when rate limit is exceeded (HTTP 429)
  class RateLimitError < DaytonaError; end

  # Error raised when an operation times out
  class TimeoutError < DaytonaError; end

  # Error raised when authentication fails
  class AuthenticationError < DaytonaError; end

  # Error raised when configuration is invalid
  class ConfigurationError < DaytonaError; end
end
