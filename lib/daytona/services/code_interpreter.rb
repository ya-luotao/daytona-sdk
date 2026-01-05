# frozen_string_literal: true

# Copyright 2025 Daytona Platforms Inc.
# SPDX-License-Identifier: Apache-2.0

module Daytona
  module Services
    # Stateful code interpreter for Sandbox
    #
    # Provides a persistent Python execution environment with context management.
    # Currently supports Python only. For other languages, use Process#code_run.
    #
    # @example
    #   # Run code with streaming output
    #   result = sandbox.code_interpreter.run_code(
    #     "for i in range(5): print(i)",
    #     on_stdout: ->(msg) { puts "OUT: #{msg}" }
    #   )
    class CodeInterpreter < BaseService
      # Run code in the interpreter
      #
      # @param code [String] Python code to execute
      # @param context [String, nil] Context ID for persistent state
      # @param on_stdout [Proc, nil] Callback for stdout messages
      # @param on_stderr [Proc, nil] Callback for stderr messages
      # @param on_error [Proc, nil] Callback for error messages
      # @param envs [Hash{String => String}, nil] Environment variables
      # @param timeout [Integer, nil] Execution timeout
      # @return [Hash] Execution result with output and any errors
      #
      # @example Basic execution
      #   result = sandbox.code_interpreter.run_code("print('Hello')")
      #   puts result['output']
      #
      # @example With streaming callbacks
      #   result = sandbox.code_interpreter.run_code(
      #     "import time; [print(i) or time.sleep(0.1) for i in range(5)]",
      #     on_stdout: ->(msg) { puts ">> #{msg}" },
      #     on_stderr: ->(msg) { warn "ERR: #{msg}" }
      #   )
      #
      # @example With persistent context
      #   ctx = sandbox.code_interpreter.create_context
      #   sandbox.code_interpreter.run_code("x = 10", context: ctx['id'])
      #   sandbox.code_interpreter.run_code("print(x)", context: ctx['id'])  # => 10
      def run_code(code, context: nil, on_stdout: nil, on_stderr: nil, on_error: nil, envs: nil, timeout: nil)
        body = { code: code }
        body[:contextId] = context if context
        body[:envs] = envs if envs
        body[:timeout] = timeout if timeout

        response = toolbox_post("/interpreter/execute", body: body, timeout: timeout || 300)

        # Process streaming output if callbacks provided
        if response.is_a?(Hash) && response["output"]
          output = response["output"]
          lines = output.split("\n")

          lines.each do |line|
            on_stdout&.call(line)
          end
        end

        response
      end

      # Create a new execution context
      #
      # Contexts provide isolated state for code execution.
      # Variables and imports persist within the same context.
      #
      # @param cwd [String, nil] Working directory for the context
      # @return [Hash] Context information with ID
      #
      # @example
      #   ctx = sandbox.code_interpreter.create_context(cwd: "/home/user/project")
      #   puts ctx['id']
      def create_context(cwd: nil)
        body = {}
        body[:cwd] = cwd if cwd
        toolbox_post("/interpreter/contexts", body: body)
      end

      # List all execution contexts
      #
      # @return [Array<Hash>] List of contexts
      #
      # @example
      #   contexts = sandbox.code_interpreter.list_contexts
      #   contexts.each { |c| puts c['id'] }
      def list_contexts
        response = toolbox_get("/interpreter/contexts")
        response["contexts"] || response[:contexts] || []
      end

      # Delete an execution context
      #
      # @param context [String] Context ID to delete
      #
      # @example
      #   sandbox.code_interpreter.delete_context("ctx-123")
      def delete_context(context)
        toolbox_delete("/interpreter/contexts/#{context}")
      end

      # Get context information
      #
      # @param context [String] Context ID
      # @return [Hash] Context information
      def get_context(context)
        toolbox_get("/interpreter/contexts/#{context}")
      end
    end
  end
end
