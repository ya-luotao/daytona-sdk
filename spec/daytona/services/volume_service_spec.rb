# frozen_string_literal: true

require "spec_helper"

RSpec.describe Daytona::Services::VolumeService do
  subject(:service) { described_class.new(build_http_client) }

  def volumes_url(path = "")
    "#{ToolboxHelpers::API_URL}/volumes#{path}"
  end

  describe "#list" do
    it "maps items to Volume models" do
      stub_request(:get, volumes_url)
        .to_return(status: 200, body: { items: [{ "id" => "v1", "name" => "data" }] }.to_json,
                   headers: { "Content-Type" => "application/json" })

      volumes = service.list

      expect(volumes.size).to eq(1)
      expect(volumes.first).to be_a(Daytona::Models::Volume)
      expect(volumes.first.name).to eq("data")
    end

    it "wraps a single (non-array) response in an array" do
      stub_request(:get, volumes_url)
        .to_return(status: 200, body: { "id" => "v1", "name" => "solo" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect(service.list.map(&:name)).to eq(["solo"])
    end
  end

  describe "#get" do
    it "fetches a single volume by id" do
      stub_request(:get, volumes_url("/v1"))
        .to_return(status: 200, body: { "id" => "v1", "name" => "data" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect(service.get("v1").id).to eq("v1")
    end
  end

  describe "#create" do
    it "POSTs the name and returns a Volume" do
      stub_request(:post, volumes_url)
        .with(body: { name: "new-vol" })
        .to_return(status: 200, body: { "id" => "v2", "name" => "new-vol" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect(service.create("new-vol").name).to eq("new-vol")
    end
  end

  describe "#delete" do
    it "DELETEs the volume by id" do
      stub = stub_request(:delete, volumes_url("/v1"))
             .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      service.delete("v1")

      expect(stub).to have_been_requested
    end
  end

  describe "#get_or_create" do
    it "returns the existing volume when one matches the name" do
      stub_request(:get, volumes_url)
        .to_return(status: 200, body: { items: [{ "id" => "v1", "name" => "data" }] }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect(service.get_or_create("data").id).to eq("v1")
    end

    it "creates a new volume when none matches" do
      stub_request(:get, volumes_url)
        .to_return(status: 200, body: { items: [] }.to_json,
                   headers: { "Content-Type" => "application/json" })
      create_stub = stub_request(:post, volumes_url)
                    .with(body: { name: "fresh" })
                    .to_return(status: 200, body: { "id" => "v9", "name" => "fresh" }.to_json,
                               headers: { "Content-Type" => "application/json" })

      expect(service.get_or_create("fresh").id).to eq("v9")
      expect(create_stub).to have_been_requested
    end
  end
end
