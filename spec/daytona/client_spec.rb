# frozen_string_literal: true

require "spec_helper"

RSpec.describe Daytona::Client do
  let(:api_url) { "https://api.daytona.io" }
  let(:client) { described_class.new(api_key: "test-api-key", api_url: api_url) }

  def sandbox_url(path = "")
    "#{api_url}/sandbox#{path}"
  end

  describe "#initialize" do
    it "raises ConfigurationError without credentials" do
      expect { described_class.new(api_url: api_url) }
        .to raise_error(Daytona::ConfigurationError)
    end

    it "exposes volume and snapshot services" do
      expect(client.volume).to be_a(Daytona::Services::VolumeService)
      expect(client.snapshot).to be_a(Daytona::Services::SnapshotService)
    end

    it "accepts a Configuration object" do
      config = Daytona::Configuration.new(api_key: "k", api_url: api_url)
      expect(described_class.new(config).config).to eq(config)
    end

    it "rejects unsupported argument types" do
      expect { described_class.new(42) }.to raise_error(ArgumentError)
    end
  end

  describe "#get" do
    it "raises when the id is blank" do
      expect { client.get("") }.to raise_error(Daytona::DaytonaError)
      expect { client.get(nil) }.to raise_error(Daytona::DaytonaError)
    end

    it "returns a Sandbox for a valid id" do
      stub_request(:get, sandbox_url("/sb-1"))
        .to_return(status: 200, body: { id: "sb-1", state: "started" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      sandbox = client.get("sb-1")

      expect(sandbox).to be_a(Daytona::Sandbox)
      expect(sandbox.id).to eq("sb-1")
    end

    it "propagates NotFoundError" do
      stub_request(:get, sandbox_url("/missing"))
        .to_return(status: 404, body: { message: "not found" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect { client.get("missing") }.to raise_error(Daytona::NotFoundError)
    end
  end

  describe "#list" do
    it "rejects non-positive page and limit" do
      expect { client.list(page: 0) }.to raise_error(Daytona::DaytonaError)
      expect { client.list(limit: 0) }.to raise_error(Daytona::DaytonaError)
    end

    it "serializes label filters as JSON" do
      stub = stub_request(:get, sandbox_url)
             .with(query: { labels: { env: "prod" }.to_json })
             .to_return(status: 200, body: { items: [], total: 0, page: 1, totalPages: 1 }.to_json,
                        headers: { "Content-Type" => "application/json" })

      client.list(labels: { env: "prod" })

      expect(stub).to have_been_requested
    end

    it "wraps a paginated object response" do
      stub_request(:get, sandbox_url)
        .to_return(status: 200,
                   body: { items: [{ id: "sb-1", state: "started" }], total: 5, page: 2, totalPages: 3 }.to_json,
                   headers: { "Content-Type" => "application/json" })

      result = client.list

      expect(result).to be_a(Daytona::PaginatedSandboxes)
      expect(result.items.map(&:id)).to eq(["sb-1"])
      expect(result.total).to eq(5)
      expect(result.page).to eq(2)
      expect(result.total_pages).to eq(3)
    end

    it "handles a bare array response" do
      stub_request(:get, sandbox_url)
        .to_return(status: 200, body: [{ id: "sb-1", state: "started" }].to_json,
                   headers: { "Content-Type" => "application/json" })

      result = client.list

      expect(result.total).to eq(1)
      expect(result.page).to eq(1)
      expect(result.total_pages).to eq(1)
    end
  end

  describe "#create" do
    it "rejects a negative timeout" do
      expect { client.create(timeout: -1) }.to raise_error(Daytona::DaytonaError)
    end

    it "creates a default Python snapshot sandbox" do
      stub = stub_request(:post, sandbox_url)
             .to_return(status: 200, body: { id: "sb-new", state: "started" }.to_json,
                        headers: { "Content-Type" => "application/json" })

      sandbox = client.create

      expect(sandbox).to be_a(Daytona::Sandbox)
      expect(sandbox.id).to eq("sb-new")
      expect(stub).to have_been_requested
    end

    it "builds a Dockerfile buildInfo for a string image and waits for start" do
      stub = stub_request(:post, sandbox_url)
             .with(body: hash_including(buildInfo: { dockerfileContent: "FROM python:3.12-slim\n" }))
             .to_return(status: 200, body: { id: "sb-img", state: "starting" }.to_json,
                        headers: { "Content-Type" => "application/json" })
      stub_request(:get, sandbox_url("/sb-img"))
        .to_return(status: 200, body: { id: "sb-img", state: "started" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      params = Daytona::Models::CreateSandboxFromImageParams.new(image: "python:3.12-slim")
      sandbox = client.create(params)

      expect(sandbox.state).to eq("started")
      expect(stub).to have_been_requested
    end

    it "rejects a negative auto_stop_interval in params" do
      params = Daytona::Models::CreateSandboxFromSnapshotParams.new(auto_stop_interval: -5)

      expect { client.create(params) }.to raise_error(Daytona::DaytonaError, /auto_stop_interval/)
    end
  end

  describe "lifecycle delegation" do
    let(:sandbox) { instance_double(Daytona::Sandbox) }

    it "#start delegates to the sandbox" do
      expect(sandbox).to receive(:start).with(timeout: 30)
      client.start(sandbox, timeout: 30)
    end

    it "#stop delegates to the sandbox" do
      expect(sandbox).to receive(:stop).with(timeout: 60)
      client.stop(sandbox)
    end

    it "#delete delegates to the sandbox" do
      expect(sandbox).to receive(:delete).with(timeout: 60)
      client.delete(sandbox)
    end
  end

  describe "#find_one" do
    it "delegates to #get when an id is given" do
      stub_request(:get, sandbox_url("/sb-1"))
        .to_return(status: 200, body: { id: "sb-1", state: "started" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect(client.find_one(sandbox_id_or_name: "sb-1").id).to eq("sb-1")
    end

    it "raises when no sandbox matches the labels" do
      stub_request(:get, sandbox_url)
        .with(query: hash_including(labels: { env: "ghost" }.to_json))
        .to_return(status: 200, body: { items: [], total: 0, page: 1, totalPages: 1 }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect { client.find_one(labels: { env: "ghost" }) }
        .to raise_error(Daytona::DaytonaError, /No sandbox found/)
    end
  end
end

RSpec.describe Daytona::PaginatedSandboxes do
  subject(:page) { described_class.new(items: [1, 2], total: 5, page: page_num, total_pages: 3) }

  let(:page_num) { 1 }

  it "is enumerable over its items" do
    expect(page.map { |i| i * 2 }).to eq([2, 4])
  end

  describe "#first_page?" do
    it { expect(page.first_page?).to be(true) }

    context "when not on the first page" do
      let(:page_num) { 2 }

      it { expect(page.first_page?).to be(false) }
    end
  end

  describe "#next_page?" do
    it "is true when more pages remain" do
      expect(page.next_page?).to be(true)
    end

    context "on the last page" do
      let(:page_num) { 3 }

      it "is false" do
        expect(page.next_page?).to be(false)
      end
    end
  end
end
