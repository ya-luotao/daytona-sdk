# frozen_string_literal: true

require "spec_helper"

RSpec.describe Daytona::Services::LspServer do
  let(:api_url) { ToolboxHelpers::API_URL }
  let(:sandbox_id) { ToolboxHelpers::SANDBOX_ID }

  subject(:lsp) do
    described_class.new(
      language_id: "python",
      path_to_project: "/home/user/project",
      http_client: build_http_client,
      sandbox_id: sandbox_id,
      get_toolbox_url: -> { "#{api_url}/toolbox" }
    )
  end

  # LspServer builds its toolbox URL as: proc result + "/" + sandbox_id
  def lsp_url(path)
    "#{api_url}/toolbox/#{sandbox_id}#{path}"
  end

  describe "#did_open" do
    it "POSTs the path, languageId and content" do
      stub = stub_request(:post, lsp_url("/lsp/did-open"))
             .with(body: { path: "/p/main.py", languageId: "python", content: "x=1" })
             .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      lsp.did_open("/p/main.py", "python", "x=1")

      expect(stub).to have_been_requested
    end
  end

  describe "#completions" do
    it "returns the items array" do
      stub_request(:post, lsp_url("/lsp/completions"))
        .with(body: { path: "/p/main.py", position: { line: 1, character: 5 } })
        .to_return(status: 200, body: { items: [{ "label" => "print" }] }.to_json,
                   headers: { "Content-Type" => "application/json" })

      result = lsp.completions("/p/main.py", { line: 1, character: 5 })

      expect(result).to eq([{ "label" => "print" }])
    end

    it "returns an empty array when items are absent" do
      stub_request(:post, lsp_url("/lsp/completions"))
        .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      expect(lsp.completions("/p/main.py", { line: 0, character: 0 })).to eq([])
    end
  end

  describe "#hover" do
    it "returns the raw hover response" do
      stub_request(:post, lsp_url("/lsp/hover"))
        .to_return(status: 200, body: { "contents" => "int" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect(lsp.hover("/p/main.py", { line: 1, character: 1 })).to eq({ "contents" => "int" })
    end
  end

  describe "#document_symbols" do
    it "returns the symbols array" do
      stub_request(:post, lsp_url("/lsp/document-symbols"))
        .with(body: { path: "/p/main.py" })
        .to_return(status: 200, body: { symbols: [{ "name" => "foo" }] }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect(lsp.document_symbols("/p/main.py")).to eq([{ "name" => "foo" }])
    end
  end

  describe "#diagnostics" do
    it "returns the diagnostics array" do
      stub_request(:post, lsp_url("/lsp/diagnostics"))
        .to_return(status: 200, body: { diagnostics: [{ "message" => "err" }] }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect(lsp.diagnostics("/p/main.py")).to eq([{ "message" => "err" }])
    end
  end

  describe "#did_close" do
    it "POSTs the path" do
      stub = stub_request(:post, lsp_url("/lsp/did-close"))
             .with(body: { path: "/p/main.py" })
             .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      lsp.did_close("/p/main.py")

      expect(stub).to have_been_requested
    end
  end

  describe "#did_change" do
    it "POSTs the path and new content" do
      stub = stub_request(:post, lsp_url("/lsp/did-change"))
             .with(body: { path: "/p/main.py", content: "x=2" })
             .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      lsp.did_change("/p/main.py", "x=2")

      expect(stub).to have_been_requested
    end
  end

  describe "#definition" do
    it "returns the raw definition response" do
      stub_request(:post, lsp_url("/lsp/definition"))
        .to_return(status: 200, body: { "path" => "/p/lib.py" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect(lsp.definition("/p/main.py", { line: 5, character: 1 }))
        .to eq({ "path" => "/p/lib.py" })
    end
  end

  describe "#references" do
    it "returns the references array" do
      stub_request(:post, lsp_url("/lsp/references"))
        .to_return(status: 200, body: { references: [{ "path" => "/p/main.py" }] }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect(lsp.references("/p/main.py", { line: 1, character: 1 }))
        .to eq([{ "path" => "/p/main.py" }])
    end
  end

  describe "#format" do
    it "returns the edits array" do
      stub_request(:post, lsp_url("/lsp/format"))
        .with(body: { path: "/p/main.py" })
        .to_return(status: 200, body: { edits: [{ "newText" => "x = 1" }] }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect(lsp.format("/p/main.py")).to eq([{ "newText" => "x = 1" }])
    end
  end
end
