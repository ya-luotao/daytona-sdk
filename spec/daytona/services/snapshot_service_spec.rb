# frozen_string_literal: true

require "spec_helper"

RSpec.describe Daytona::Services::SnapshotService do
  subject(:service) { described_class.new(build_http_client) }

  def snapshots_url(path = "")
    "#{ToolboxHelpers::API_URL}/snapshots#{path}"
  end

  describe "#list" do
    it "normalizes the paginated response" do
      stub_request(:get, snapshots_url)
        .with(query: { page: "1", limit: "10" })
        .to_return(status: 200,
                   body: { items: [{ "name" => "s1" }], total: 1, page: 1, totalPages: 1 }.to_json,
                   headers: { "Content-Type" => "application/json" })

      result = service.list(page: 1, limit: 10)

      expect(result[:items]).to eq([{ "name" => "s1" }])
      expect(result[:total]).to eq(1)
      expect(result[:page]).to eq(1)
      expect(result[:total_pages]).to eq(1)
    end

    it "applies defaults when fields are missing" do
      stub_request(:get, snapshots_url)
        .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      result = service.list

      expect(result).to eq(items: [], total: 0, page: 1, total_pages: 1)
    end
  end

  describe "#get" do
    it "fetches a snapshot by id or name" do
      stub_request(:get, snapshots_url("/my-snap"))
        .to_return(status: 200, body: { "name" => "my-snap" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect(service.get("my-snap")).to eq({ "name" => "my-snap" })
    end
  end

  describe "#create" do
    it "wraps a string image in a Dockerfile FROM directive" do
      stub = stub_request(:post, snapshots_url)
             .with(body: { name: "py", buildInfo: { dockerfileContent: "FROM python:3.12-slim\n" } })
             .to_return(status: 200, body: { "id" => "snap-1" }.to_json,
                        headers: { "Content-Type" => "application/json" })

      service.create("python:3.12-slim", name: "py")

      expect(stub).to have_been_requested
    end

    it "uses an Image builder's dockerfile directly" do
      image = Daytona::Image.debian_slim("3.12")

      stub = stub_request(:post, snapshots_url)
             .with(body: { buildInfo: { dockerfileContent: image.dockerfile } })
             .to_return(status: 200, body: { "id" => "snap-2" }.to_json,
                        headers: { "Content-Type" => "application/json" })

      service.create(image)

      expect(stub).to have_been_requested
    end
  end

  describe "#delete" do
    it "DELETEs the snapshot by id" do
      stub = stub_request(:delete, snapshots_url("/snap-1"))
             .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      service.delete("snap-1")

      expect(stub).to have_been_requested
    end
  end
end
