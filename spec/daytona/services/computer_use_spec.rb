# frozen_string_literal: true

require "spec_helper"

RSpec.describe Daytona::Services::ComputerUse do
  subject(:computer) { build_service(described_class) }

  describe "lifecycle" do
    it "start POSTs to the start endpoint" do
      stub = stub_request(:post, toolbox_url("/computer-use/start"))
             .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      computer.start

      expect(stub).to have_been_requested
    end

    it "get_status GETs the status endpoint" do
      stub_request(:get, toolbox_url("/computer-use/status"))
        .to_return(status: 200, body: { "running" => true }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect(computer.get_status).to eq({ "running" => true })
    end
  end

  describe "mouse" do
    it "move POSTs coordinates" do
      stub = stub_request(:post, toolbox_url("/computer-use/mouse/move"))
             .with(body: { x: 10, y: 20 })
             .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      computer.mouse.move(10, 20)

      expect(stub).to have_been_requested
    end

    it "click POSTs button and double flag" do
      stub = stub_request(:post, toolbox_url("/computer-use/mouse/click"))
             .with(body: { x: 5, y: 6, button: "left", double: false })
             .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      computer.mouse.click(5, 6)

      expect(stub).to have_been_requested
    end

    it "double_click sets double: true" do
      stub = stub_request(:post, toolbox_url("/computer-use/mouse/click"))
             .with(body: { x: 5, y: 6, button: "left", double: true })
             .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      computer.mouse.double_click(5, 6)

      expect(stub).to have_been_requested
    end

    it "drag POSTs start and end coordinates" do
      stub = stub_request(:post, toolbox_url("/computer-use/mouse/drag"))
             .with(body: { startX: 1, startY: 2, endX: 3, endY: 4, button: "left" })
             .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      computer.mouse.drag(1, 2, 3, 4)

      expect(stub).to have_been_requested
    end
  end

  describe "keyboard" do
    it "type omits delay when not given" do
      stub = stub_request(:post, toolbox_url("/computer-use/keyboard/type"))
             .with(body: { text: "hi" })
             .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      computer.keyboard.type("hi")

      expect(stub).to have_been_requested
    end

    it "press includes modifiers" do
      stub = stub_request(:post, toolbox_url("/computer-use/keyboard/press"))
             .with(body: { key: "a", modifiers: ["ctrl"] })
             .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      computer.keyboard.press("a", modifiers: ["ctrl"])

      expect(stub).to have_been_requested
    end
  end

  describe "screenshot" do
    it "take_full_screen GETs with showCursor query" do
      stub_request(:get, toolbox_url("/computer-use/screenshot"))
        .with(query: { showCursor: "false" })
        .to_return(status: 200, body: { "data" => "base64" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect(computer.screenshot.take_full_screen).to eq({ "data" => "base64" })
    end
  end

  describe "display" do
    it "get_windows returns the windows array" do
      stub_request(:get, toolbox_url("/computer-use/display/windows"))
        .to_return(status: 200, body: { windows: [{ "id" => "w1" }] }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect(computer.display.get_windows).to eq([{ "id" => "w1" }])
    end

    it "get_info GETs the display info" do
      stub_request(:get, toolbox_url("/computer-use/display/info"))
        .to_return(status: 200, body: { "width" => 1920 }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect(computer.display.get_info).to eq({ "width" => 1920 })
    end

    it "focus_window POSTs to the focus endpoint" do
      stub = stub_request(:post, toolbox_url("/computer-use/display/windows/w1/focus"))
             .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      computer.display.focus_window("w1")

      expect(stub).to have_been_requested
    end
  end

  describe "process management" do
    it "stop POSTs to the stop endpoint" do
      stub = stub_request(:post, toolbox_url("/computer-use/stop"))
             .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      computer.stop

      expect(stub).to have_been_requested
    end

    it "get_process_status GETs a named process" do
      stub_request(:get, toolbox_url("/computer-use/processes/xvfb/status"))
        .to_return(status: 200, body: { "running" => true }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect(computer.get_process_status("xvfb")).to eq({ "running" => true })
    end

    it "restart_process POSTs to the restart endpoint" do
      stub = stub_request(:post, toolbox_url("/computer-use/processes/xvfb/restart"))
             .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      computer.restart_process("xvfb")

      expect(stub).to have_been_requested
    end
  end

  describe "more input helpers" do
    it "mouse get_position GETs the position" do
      stub_request(:get, toolbox_url("/computer-use/mouse/position"))
        .to_return(status: 200, body: { "x" => 1, "y" => 2 }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect(computer.mouse.get_position).to eq({ "x" => 1, "y" => 2 })
    end

    it "mouse scroll POSTs direction and amount" do
      stub = stub_request(:post, toolbox_url("/computer-use/mouse/scroll"))
             .with(body: { x: 1, y: 2, direction: "down", amount: 3 })
             .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      computer.mouse.scroll(1, 2, "down", amount: 3)

      expect(stub).to have_been_requested
    end

    it "keyboard hotkey POSTs the key combination" do
      stub = stub_request(:post, toolbox_url("/computer-use/keyboard/hotkey"))
             .with(body: { keys: %w[ctrl c] })
             .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      computer.keyboard.hotkey(%w[ctrl c])

      expect(stub).to have_been_requested
    end

    it "screenshot take_region POSTs the region" do
      stub = stub_request(:post, toolbox_url("/computer-use/screenshot/region"))
             .with(body: { region: { x: 0, y: 0, width: 10, height: 10 }, showCursor: false })
             .to_return(status: 200, body: { "data" => "x" }.to_json,
                        headers: { "Content-Type" => "application/json" })

      computer.screenshot.take_region({ x: 0, y: 0, width: 10, height: 10 })

      expect(stub).to have_been_requested
    end
  end
end
