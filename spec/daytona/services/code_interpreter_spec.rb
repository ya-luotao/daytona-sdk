# frozen_string_literal: true

require "spec_helper"

RSpec.describe Daytona::Services::CodeInterpreter do
  subject(:interpreter) { build_service(described_class) }

  describe "#run_code" do
    it "POSTs the code and returns the response" do
      stub_request(:post, toolbox_url("/interpreter/execute"))
        .with(body: { code: "print(1)" })
        .to_return(status: 200, body: { "output" => "1" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect(interpreter.run_code("print(1)")).to eq({ "output" => "1" })
    end

    it "includes contextId, envs and timeout when provided" do
      stub = stub_request(:post, toolbox_url("/interpreter/execute"))
             .with(body: { code: "x=1", contextId: "ctx-1", envs: { "A" => "b" }, timeout: 10 })
             .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      interpreter.run_code("x=1", context: "ctx-1", envs: { "A" => "b" }, timeout: 10)

      expect(stub).to have_been_requested
    end

    it "streams each output line to the on_stdout callback" do
      stub_request(:post, toolbox_url("/interpreter/execute"))
        .to_return(status: 200, body: { "output" => "a\nb\nc" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      lines = []
      interpreter.run_code("...", on_stdout: ->(line) { lines << line })

      expect(lines).to eq(%w[a b c])
    end
  end

  describe "context management" do
    it "create_context POSTs cwd when given" do
      stub = stub_request(:post, toolbox_url("/interpreter/contexts"))
             .with(body: { cwd: "/home/user" })
             .to_return(status: 200, body: { "id" => "ctx-1" }.to_json,
                        headers: { "Content-Type" => "application/json" })

      expect(interpreter.create_context(cwd: "/home/user")).to eq({ "id" => "ctx-1" })
      expect(stub).to have_been_requested
    end

    it "list_contexts returns the contexts array" do
      stub_request(:get, toolbox_url("/interpreter/contexts"))
        .to_return(status: 200, body: { contexts: [{ "id" => "ctx-1" }] }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect(interpreter.list_contexts).to eq([{ "id" => "ctx-1" }])
    end

    it "delete_context DELETEs by id" do
      stub = stub_request(:delete, toolbox_url("/interpreter/contexts/ctx-1"))
             .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      interpreter.delete_context("ctx-1")

      expect(stub).to have_been_requested
    end
  end
end
