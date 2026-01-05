# frozen_string_literal: true

# Copyright 2025 Daytona Platforms Inc.
# SPDX-License-Identifier: Apache-2.0

module Daytona
  module Services
    # Language Server Protocol (LSP) server for Sandbox
    #
    # Provides language intelligence features like code completion,
    # hover information, and diagnostics.
    #
    # @example
    #   lsp = sandbox.create_lsp_server("python", "/home/user/project")
    #   lsp.did_open("/home/user/project/main.py", "python", "print('hello')")
    #   completions = lsp.completions("/home/user/project/main.py", { line: 0, character: 6 })
    class LspServer
      # Supported language IDs
      PYTHON = "python"
      TYPESCRIPT = "typescript"
      JAVASCRIPT = "javascript"

      # @return [String] Language server type
      attr_reader :language_id

      # @return [String] Project root path
      attr_reader :path_to_project

      # Initialize a new LSP server
      #
      # @param language_id [String] Language type (python, typescript, javascript)
      # @param path_to_project [String] Project root directory
      # @param http_client [API::HttpClient] HTTP client
      # @param sandbox_id [String] Sandbox ID
      # @param get_toolbox_url [Proc] Function to get toolbox URL
      def initialize(language_id:, path_to_project:, http_client:, sandbox_id:, get_toolbox_url:)
        @language_id = language_id
        @path_to_project = path_to_project
        @http_client = http_client
        @sandbox_id = sandbox_id
        @get_toolbox_url = get_toolbox_url
        @toolbox_url = nil
        @toolbox_client = nil
      end

      # Notify that a document was opened
      #
      # @param path [String] Document path
      # @param language_id [String] Language identifier
      # @param content [String] Document content
      #
      # @example
      #   lsp.did_open("/project/main.py", "python", "import os\nprint(os.getcwd())")
      def did_open(path, language_id, content)
        toolbox_post("/lsp/did-open", body: {
          path: path,
          languageId: language_id,
          content: content,
        })
      end

      # Notify that a document was changed
      #
      # @param path [String] Document path
      # @param content [String] New document content
      #
      # @example
      #   lsp.did_change("/project/main.py", "import os\nprint('changed')")
      def did_change(path, content)
        toolbox_post("/lsp/did-change", body: {
          path: path,
          content: content,
        })
      end

      # Notify that a document was closed
      #
      # @param path [String] Document path
      def did_close(path)
        toolbox_post("/lsp/did-close", body: { path: path })
      end

      # Get code completions
      #
      # @param path [String] Document path
      # @param position [Hash] Position with :line and :character
      # @return [Array<Hash>] Completion items
      #
      # @example
      #   completions = lsp.completions("/project/main.py", { line: 1, character: 5 })
      #   completions.each { |c| puts c['label'] }
      def completions(path, position)
        response = toolbox_post("/lsp/completions", body: {
          path: path,
          position: position,
        })
        response["items"] || response[:items] || []
      end

      # Get hover information
      #
      # @param path [String] Document path
      # @param position [Hash] Position with :line and :character
      # @return [Hash, nil] Hover information
      #
      # @example
      #   hover = lsp.hover("/project/main.py", { line: 1, character: 10 })
      #   puts hover['contents'] if hover
      def hover(path, position)
        toolbox_post("/lsp/hover", body: {
          path: path,
          position: position,
        })
      end

      # Get document symbols
      #
      # @param path [String] Document path
      # @return [Array<Hash>] Document symbols (functions, classes, etc.)
      #
      # @example
      #   symbols = lsp.document_symbols("/project/main.py")
      #   symbols.each { |s| puts "#{s['kind']}: #{s['name']}" }
      def document_symbols(path)
        response = toolbox_post("/lsp/document-symbols", body: { path: path })
        response["symbols"] || response[:symbols] || []
      end

      # Go to definition
      #
      # @param path [String] Document path
      # @param position [Hash] Position with :line and :character
      # @return [Hash, nil] Definition location
      #
      # @example
      #   definition = lsp.definition("/project/main.py", { line: 5, character: 10 })
      #   puts "Found at: #{definition['path']}:#{definition['range']['start']['line']}" if definition
      def definition(path, position)
        toolbox_post("/lsp/definition", body: {
          path: path,
          position: position,
        })
      end

      # Get references to a symbol
      #
      # @param path [String] Document path
      # @param position [Hash] Position with :line and :character
      # @return [Array<Hash>] Reference locations
      #
      # @example
      #   refs = lsp.references("/project/main.py", { line: 1, character: 5 })
      #   refs.each { |r| puts "#{r['path']}:#{r['range']['start']['line']}" }
      def references(path, position)
        response = toolbox_post("/lsp/references", body: {
          path: path,
          position: position,
        })
        response["references"] || response[:references] || []
      end

      # Format a document
      #
      # @param path [String] Document path
      # @return [Array<Hash>] Text edits to apply
      def format(path)
        response = toolbox_post("/lsp/format", body: { path: path })
        response["edits"] || response[:edits] || []
      end

      # Get document diagnostics
      #
      # @param path [String] Document path
      # @return [Array<Hash>] Diagnostic messages (errors, warnings)
      #
      # @example
      #   diagnostics = lsp.diagnostics("/project/main.py")
      #   diagnostics.each { |d| puts "#{d['severity']}: #{d['message']}" }
      def diagnostics(path)
        response = toolbox_post("/lsp/diagnostics", body: { path: path })
        response["diagnostics"] || response[:diagnostics] || []
      end

      private

      def ensure_toolbox_url!
        return if @toolbox_url

        @toolbox_url = @get_toolbox_url.call
        @toolbox_url = "#{@toolbox_url}/" unless @toolbox_url.end_with?("/")
        @toolbox_url = "#{@toolbox_url}#{@sandbox_id}"
      end

      def toolbox_client
        ensure_toolbox_url!
        @toolbox_client ||= API::HttpClient.new(
          base_url: @toolbox_url,
          api_key: @http_client.instance_variable_get(:@api_key),
          jwt_token: @http_client.instance_variable_get(:@jwt_token),
          organization_id: @http_client.instance_variable_get(:@organization_id)
        )
      end

      def toolbox_post(path, body: nil)
        toolbox_client.post(path, body: body)
      end
    end
  end
end
