# frozen_string_literal: true

# Copyright 2025 Daytona Platforms Inc.
# SPDX-License-Identifier: Apache-2.0

module Daytona
  module Services
    # Desktop automation for Sandbox
    #
    # Provides mouse, keyboard, and screen interaction capabilities.
    # Requires a desktop environment in the Sandbox.
    #
    # @example
    #   # Take a screenshot
    #   screenshot = sandbox.computer_use.screenshot.take_full_screen
    #
    #   # Click and type
    #   sandbox.computer_use.mouse.click(100, 200)
    #   sandbox.computer_use.keyboard.type("Hello, World!")
    class ComputerUse < BaseService
      # @return [Mouse] Mouse operations
      attr_reader :mouse

      # @return [Keyboard] Keyboard operations
      attr_reader :keyboard

      # @return [Screenshot] Screenshot operations
      attr_reader :screenshot

      # @return [Display] Display operations
      attr_reader :display

      def initialize(**kwargs)
        super
        @mouse = Mouse.new(self)
        @keyboard = Keyboard.new(self)
        @screenshot = Screenshot.new(self)
        @display = Display.new(self)
      end

      # Start the desktop environment
      def start
        toolbox_post("/computer-use/start")
      end

      # Stop the desktop environment
      def stop
        toolbox_post("/computer-use/stop")
      end

      # Get status of all processes
      #
      # @return [Hash] Status of desktop processes
      def get_status
        toolbox_get("/computer-use/status")
      end

      # Get status of a specific process
      #
      # @param process_name [String] Process name
      # @return [Hash] Process status
      def get_process_status(process_name)
        toolbox_get("/computer-use/processes/#{process_name}/status")
      end

      # Restart a process
      #
      # @param process_name [String] Process name
      def restart_process(process_name)
        toolbox_post("/computer-use/processes/#{process_name}/restart")
      end

      # Get process logs
      #
      # @param process_name [String] Process name
      # @return [String] Process logs
      def get_process_logs(process_name)
        toolbox_get("/computer-use/processes/#{process_name}/logs")
      end

      # Get process errors
      #
      # @param process_name [String] Process name
      # @return [String] Process errors
      def get_process_errors(process_name)
        toolbox_get("/computer-use/processes/#{process_name}/errors")
      end

      # Mouse operations helper
      class Mouse
        def initialize(service)
          @service = service
        end

        # Get current mouse position
        #
        # @return [Hash] Position with x and y coordinates
        def get_position
          @service.send(:toolbox_get, "/computer-use/mouse/position")
        end

        # Move mouse to position
        #
        # @param x [Integer] X coordinate
        # @param y [Integer] Y coordinate
        def move(x, y)
          @service.send(:toolbox_post, "/computer-use/mouse/move", body: { x: x, y: y })
        end

        # Click at position
        #
        # @param x [Integer] X coordinate
        # @param y [Integer] Y coordinate
        # @param button [String] Mouse button (left, right, middle)
        # @param double [Boolean] Double-click
        def click(x, y, button: "left", double: false)
          @service.send(:toolbox_post, "/computer-use/mouse/click", body: {
            x: x,
            y: y,
            button: button,
            double: double,
          })
        end

        # Double-click at position
        #
        # @param x [Integer] X coordinate
        # @param y [Integer] Y coordinate
        # @param button [String] Mouse button
        def double_click(x, y, button: "left")
          click(x, y, button: button, double: true)
        end

        # Drag from one position to another
        #
        # @param start_x [Integer] Starting X coordinate
        # @param start_y [Integer] Starting Y coordinate
        # @param end_x [Integer] Ending X coordinate
        # @param end_y [Integer] Ending Y coordinate
        # @param button [String] Mouse button
        def drag(start_x, start_y, end_x, end_y, button: "left")
          @service.send(:toolbox_post, "/computer-use/mouse/drag", body: {
            startX: start_x,
            startY: start_y,
            endX: end_x,
            endY: end_y,
            button: button,
          })
        end

        # Scroll at position
        #
        # @param x [Integer] X coordinate
        # @param y [Integer] Y coordinate
        # @param direction [String] Scroll direction (up, down, left, right)
        # @param amount [Integer] Scroll amount
        def scroll(x, y, direction, amount: 1)
          @service.send(:toolbox_post, "/computer-use/mouse/scroll", body: {
            x: x,
            y: y,
            direction: direction,
            amount: amount,
          })
        end
      end

      # Keyboard operations helper
      class Keyboard
        def initialize(service)
          @service = service
        end

        # Type text
        #
        # @param text [String] Text to type
        # @param delay [Integer, nil] Delay between keystrokes in ms
        def type(text, delay: nil)
          body = { text: text }
          body[:delay] = delay if delay
          @service.send(:toolbox_post, "/computer-use/keyboard/type", body: body)
        end

        # Press a key
        #
        # @param key [String] Key to press
        # @param modifiers [Array<String>] Modifier keys (ctrl, alt, shift, meta)
        def press(key, modifiers: [])
          @service.send(:toolbox_post, "/computer-use/keyboard/press", body: {
            key: key,
            modifiers: modifiers,
          })
        end

        # Press a hotkey combination
        #
        # @param keys [Array<String>] Keys to press together
        def hotkey(keys)
          @service.send(:toolbox_post, "/computer-use/keyboard/hotkey", body: { keys: keys })
        end
      end

      # Screenshot operations helper
      class Screenshot
        def initialize(service)
          @service = service
        end

        # Take a full screen screenshot
        #
        # @param show_cursor [Boolean] Include cursor in screenshot
        # @return [String] Base64-encoded image data
        def take_full_screen(show_cursor: false)
          @service.send(:toolbox_get, "/computer-use/screenshot", params: { showCursor: show_cursor })
        end

        # Take a screenshot of a region
        #
        # @param region [Hash] Region with x, y, width, height
        # @param show_cursor [Boolean] Include cursor
        # @return [String] Base64-encoded image data
        def take_region(region, show_cursor: false)
          @service.send(:toolbox_post, "/computer-use/screenshot/region", body: {
            region: region,
            showCursor: show_cursor,
          })
        end

        # Take a compressed screenshot
        #
        # @param options [Hash, nil] Compression options
        # @return [String] Compressed image data
        def take_compressed(options: nil)
          body = options || {}
          @service.send(:toolbox_post, "/computer-use/screenshot/compressed", body: body)
        end
      end

      # Display operations helper
      class Display
        def initialize(service)
          @service = service
        end

        # Get display information
        #
        # @return [Hash] Display info (resolution, scaling, etc.)
        def get_info
          @service.send(:toolbox_get, "/computer-use/display/info")
        end

        # Get list of windows
        #
        # @return [Array<Hash>] List of windows
        def get_windows
          response = @service.send(:toolbox_get, "/computer-use/display/windows")
          response["windows"] || response[:windows] || []
        end

        # Focus a window
        #
        # @param window_id [String] Window identifier
        def focus_window(window_id)
          @service.send(:toolbox_post, "/computer-use/display/windows/#{window_id}/focus")
        end
      end
    end
  end
end
