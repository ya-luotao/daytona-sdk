# frozen_string_literal: true

# Copyright 2025 Daytona Platforms Inc.
# SPDX-License-Identifier: Apache-2.0

module Daytona
  module Models
    # Programming languages supported by Daytona
    module CodeLanguage
      PYTHON = "python"
      TYPESCRIPT = "typescript"
      JAVASCRIPT = "javascript"

      ALL = [PYTHON, TYPESCRIPT, JAVASCRIPT].freeze

      # Check if a language is valid
      #
      # @param language [String] Language to check
      # @return [Boolean]
      def self.valid?(language)
        ALL.include?(language.to_s.downcase)
      end

      # Normalize language string
      #
      # @param language [String] Language to normalize
      # @return [String]
      def self.normalize(language)
        lang = language.to_s.downcase
        ALL.include?(lang) ? lang : PYTHON
      end
    end
  end
end
