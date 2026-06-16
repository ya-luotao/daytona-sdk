# frozen_string_literal: true

require "spec_helper"

RSpec.describe Daytona::Services::Process do
  subject(:process) { build_service(described_class) }

  describe "#exec" do
    it "POSTs the command and wraps the response" do
      stub_request(:post, toolbox_url("/process/execute"))
        .with(body: { command: "echo hi" })
        .to_return(status: 200, body: { exitCode: 0, result: "hi\n" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      response = process.exec("echo hi")

      expect(response).to be_a(Daytona::Models::ExecuteResponse)
      expect(response.exit_code).to eq(0)
      expect(response.result).to eq("hi\n")
    end

    it "includes cwd, env and timeout when provided" do
      stub = stub_request(:post, toolbox_url("/process/execute"))
             .with(body: { command: "npm test", cwd: "/app", env: { "NODE_ENV" => "test" }, timeout: 30 })
             .to_return(status: 200, body: { exitCode: 0 }.to_json,
                        headers: { "Content-Type" => "application/json" })

      process.exec("npm test", cwd: "/app", env: { "NODE_ENV" => "test" }, timeout: 30)

      expect(stub).to have_been_requested
    end
  end

  describe "#code_run" do
    it "defaults to python and returns an ExecuteResponse" do
      stub = stub_request(:post, toolbox_url("/process/code-run"))
             .with(body: { code: "print(1)", language: "python" })
             .to_return(status: 200, body: { exitCode: 0, result: "1\n" }.to_json,
                        headers: { "Content-Type" => "application/json" })

      response = process.code_run("print(1)")

      expect(response.result).to eq("1\n")
      expect(stub).to have_been_requested
    end
  end

  describe "session management" do
    it "create_session POSTs sessionId" do
      stub = stub_request(:post, toolbox_url("/process/session"))
             .with(body: { sessionId: "s1" })
             .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      process.create_session("s1")

      expect(stub).to have_been_requested
    end

    it "get_session GETs the session by id" do
      stub_request(:get, toolbox_url("/process/session/s1"))
        .to_return(status: 200, body: { "sessionId" => "s1" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect(process.get_session("s1")).to eq({ "sessionId" => "s1" })
    end

    it "delete_session DELETEs the session" do
      stub = stub_request(:delete, toolbox_url("/process/session/s1"))
             .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      process.delete_session("s1")

      expect(stub).to have_been_requested
    end

    it "execute_session_command accepts a Hash request" do
      stub_request(:post, toolbox_url("/process/session/s1/exec"))
        .with(body: { command: "ls" })
        .to_return(status: 200, body: { cmdId: "c1" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      response = process.execute_session_command("s1", { command: "ls" })

      expect(response).to be_a(Daytona::Models::SessionExecuteResponse)
    end
  end

  describe "#connect_pty_session" do
    it "builds a ws:// URL from the toolbox URL" do
      url = process.connect_pty_session("pty1")

      expect(url).to eq("wss://api.daytona.io/toolbox/#{ToolboxHelpers::SANDBOX_ID}/toolbox/pty/pty1/connect")
    end
  end

  describe "#list_pty_sessions" do
    it "returns the sessions array" do
      stub_request(:get, toolbox_url("/pty"))
        .to_return(status: 200, body: { sessions: [{ "id" => "pty1" }] }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect(process.list_pty_sessions).to eq([{ "id" => "pty1" }])
    end
  end
end
