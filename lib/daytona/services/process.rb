# frozen_string_literal: true

# Copyright 2025 Daytona Platforms Inc.
# SPDX-License-Identifier: Apache-2.0

module Daytona
  module Services
    # Process execution for Sandbox
    #
    # Provides methods for executing commands and code within the Sandbox.
    #
    # @example
    #   # Execute a shell command
    #   response = sandbox.process.exec("ls -la")
    #   puts response.result
    #
    #   # Run Python code
    #   response = sandbox.process.code_run("print('Hello')", language: "python")
    #   puts response.result
    class Process < BaseService
      # Execute a shell command
      #
      # @param command [String] Command to execute
      # @param cwd [String, nil] Working directory
      # @param env [Hash{String => String}, nil] Environment variables
      # @param timeout [Integer, nil] Command timeout in seconds
      # @return [Models::ExecuteResponse] Execution result with exit_code and output
      #
      # @example
      #   response = sandbox.process.exec("echo 'Hello, World!'")
      #   puts response.result  # => "Hello, World!\n"
      #   puts response.exit_code  # => 0
      #
      # @example With working directory and env
      #   response = sandbox.process.exec("npm test",
      #                                   cwd: "/home/user/project",
      #                                   env: { "NODE_ENV" => "test" })
      def exec(command, cwd: nil, env: nil, timeout: nil)
        body = { command: command }
        body[:cwd] = cwd if cwd
        body[:env] = env if env
        body[:timeout] = timeout if timeout

        response = toolbox_post("/process/exec", body: body, timeout: timeout || 120)
        Models::ExecuteResponse.from_hash(response)
      end

      # Run code in the Sandbox
      #
      # @param code [String] Code to execute
      # @param language [String] Programming language (python, javascript, typescript)
      # @param params [Hash, nil] Additional parameters
      # @param timeout [Integer, nil] Execution timeout
      # @return [Models::ExecuteResponse] Execution result
      #
      # @example
      #   response = sandbox.process.code_run("print('Hello')", language: "python")
      #   puts response.result
      def code_run(code, language: "python", params: nil, timeout: nil)
        body = {
          code: code,
          language: language,
        }
        body[:params] = params if params

        response = toolbox_post("/process/code-run", body: body, timeout: timeout || 120)
        Models::ExecuteResponse.from_hash(response)
      end

      # Create a new session
      #
      # @param session_id [String] Unique session identifier
      # @return [Hash] Session information
      #
      # @example
      #   session = sandbox.process.create_session("my-session")
      def create_session(session_id)
        toolbox_post("/sessions", body: { sessionId: session_id })
      end

      # Get session information
      #
      # @param session_id [String] Session identifier
      # @return [Hash] Session information
      def get_session(session_id)
        toolbox_get("/sessions/#{session_id}")
      end

      # Execute command in a session
      #
      # @param session_id [String] Session identifier
      # @param request [Models::SessionExecuteRequest, Hash] Execution request
      # @param timeout [Integer, nil] Command timeout
      # @return [Models::SessionExecuteResponse] Execution response
      #
      # @example
      #   response = sandbox.process.execute_session_command("my-session", command: "ls -la")
      def execute_session_command(session_id, request, timeout: nil)
        body = request.is_a?(Hash) ? request : request.to_h
        response = toolbox_post("/sessions/#{session_id}/exec", body: body, timeout: timeout || 120)
        Models::SessionExecuteResponse.from_hash(response)
      end

      # Get command information from a session
      #
      # @param session_id [String] Session identifier
      # @param command_id [String] Command identifier
      # @return [Hash] Command information
      def get_session_command(session_id, command_id)
        toolbox_get("/sessions/#{session_id}/commands/#{command_id}")
      end

      # Get command logs from a session
      #
      # @param session_id [String] Session identifier
      # @param command_id [String] Command identifier
      # @return [String] Command logs
      def get_session_command_logs(session_id, command_id)
        toolbox_get("/sessions/#{session_id}/commands/#{command_id}/logs")
      end

      # List all sessions
      #
      # @return [Array<Hash>] List of sessions
      def list_sessions
        response = toolbox_get("/sessions")
        response["sessions"] || response[:sessions] || []
      end

      # Delete a session
      #
      # @param session_id [String] Session identifier
      def delete_session(session_id)
        toolbox_delete("/sessions/#{session_id}")
      end

      # Create a PTY (pseudo-terminal) session
      #
      # @param id [String] PTY session identifier
      # @param cwd [String, nil] Working directory
      # @param envs [Hash{String => String}, nil] Environment variables
      # @param pty_size [Hash, nil] PTY size { cols:, rows: }
      # @return [Hash] PTY session information
      #
      # @example
      #   pty = sandbox.process.create_pty_session("my-pty",
      #                                            cwd: "/home/user",
      #                                            pty_size: { cols: 80, rows: 24 })
      def create_pty_session(id, cwd: nil, envs: nil, pty_size: nil)
        body = { id: id }
        body[:cwd] = cwd if cwd
        body[:envs] = envs if envs
        body[:ptySize] = pty_size if pty_size

        toolbox_post("/pty", body: body)
      end

      # Connect to a PTY session (returns WebSocket URL)
      #
      # @param session_id [String] PTY session identifier
      # @return [String] WebSocket URL for PTY connection
      def connect_pty_session(session_id)
        ensure_toolbox_url!
        ws_url = @toolbox_url.sub(/^http/, "ws")
        "#{ws_url}/pty/#{session_id}/connect"
      end

      # List all PTY sessions
      #
      # @return [Array<Hash>] List of PTY sessions
      def list_pty_sessions
        response = toolbox_get("/pty")
        response["sessions"] || response[:sessions] || []
      end

      # Get PTY session information
      #
      # @param session_id [String] PTY session identifier
      # @return [Hash] PTY session information
      def get_pty_session_info(session_id)
        toolbox_get("/pty/#{session_id}")
      end

      # Kill a PTY session
      #
      # @param session_id [String] PTY session identifier
      def kill_pty_session(session_id)
        toolbox_delete("/pty/#{session_id}")
      end

      # Resize a PTY session
      #
      # @param session_id [String] PTY session identifier
      # @param pty_size [Hash] New size { cols:, rows: }
      def resize_pty_session(session_id, pty_size)
        toolbox_post("/pty/#{session_id}/resize", body: pty_size)
      end
    end
  end
end
