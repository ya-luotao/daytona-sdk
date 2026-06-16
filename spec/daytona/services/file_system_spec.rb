# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe Daytona::Services::FileSystem do
  subject(:fs) { build_service(described_class) }

  describe "#create_folder" do
    it "POSTs the path and mode" do
      stub = stub_request(:post, toolbox_url("/filesystem/folder"))
             .with(body: { path: "/home/user/new", mode: "0755" })
             .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      fs.create_folder("/home/user/new")

      expect(stub).to have_been_requested
    end

    it "uses a custom mode when provided" do
      stub = stub_request(:post, toolbox_url("/filesystem/folder"))
             .with(body: { path: "/home/user/new", mode: "0700" })
             .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      fs.create_folder("/home/user/new", "0700")

      expect(stub).to have_been_requested
    end
  end

  describe "#delete_file" do
    it "DELETEs without recursive flag by default" do
      stub = stub_request(:delete, toolbox_url("/filesystem"))
             .with(query: { path: "/home/user/file.txt" })
             .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      fs.delete_file("/home/user/file.txt")

      expect(stub).to have_been_requested
    end

    it "includes recursive=true when requested" do
      stub = stub_request(:delete, toolbox_url("/filesystem"))
             .with(query: { path: "/home/user/dir", recursive: "true" })
             .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      fs.delete_file("/home/user/dir", recursive: true)

      expect(stub).to have_been_requested
    end
  end

  describe "#download_file" do
    it "returns the content when no local path is given" do
      stub_request(:get, toolbox_url("/filesystem/download"))
        .with(query: { path: "/home/user/file.txt" })
        .to_return(status: 200, body: "file body")

      expect(fs.download_file("/home/user/file.txt")).to eq("file body")
    end

    it "writes to a local path and returns nil" do
      stub_request(:get, toolbox_url("/filesystem/download"))
        .with(query: { path: "/remote.txt" })
        .to_return(status: 200, body: "downloaded")

      Tempfile.create("dl") do |tmp|
        expect(fs.download_file("/remote.txt", tmp.path)).to be_nil
        expect(File.read(tmp.path)).to eq("downloaded")
      end
    end
  end

  describe "#find_files" do
    it "returns the matches array" do
      stub_request(:get, toolbox_url("/filesystem/find"))
        .with(query: { path: "/home/user", pattern: "TODO" })
        .to_return(status: 200, body: { matches: [{ "file" => "a.rb" }] }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect(fs.find_files("/home/user", "TODO")).to eq([{ "file" => "a.rb" }])
    end

    it "returns an empty array when matches key is absent" do
      stub_request(:get, toolbox_url("/filesystem/find"))
        .with(query: { path: "/home/user", pattern: "TODO" })
        .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      expect(fs.find_files("/home/user", "TODO")).to eq([])
    end
  end

  describe "#list_files" do
    it "returns the entries array" do
      stub_request(:get, toolbox_url("/filesystem"))
        .with(query: { path: "/home/user" })
        .to_return(status: 200, body: { entries: [{ "name" => "a.txt" }] }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect(fs.list_files("/home/user")).to eq([{ "name" => "a.txt" }])
    end
  end

  describe "#move_files" do
    it "POSTs source and destination" do
      stub = stub_request(:post, toolbox_url("/filesystem/move"))
             .with(body: { source: "/a.txt", destination: "/b.txt" })
             .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      fs.move_files("/a.txt", "/b.txt")

      expect(stub).to have_been_requested
    end
  end

  describe "#replace_in_files" do
    it "POSTs files, pattern and newValue" do
      stub = stub_request(:post, toolbox_url("/filesystem/replace"))
             .with(body: { files: ["/a.txt"], pattern: "old", newValue: "new" })
             .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      fs.replace_in_files(["/a.txt"], "old", "new")

      expect(stub).to have_been_requested
    end
  end

  describe "#set_file_permissions" do
    it "only includes provided fields" do
      stub = stub_request(:post, toolbox_url("/filesystem/permissions"))
             .with(body: { path: "/script.sh", mode: "0755" })
             .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      fs.set_file_permissions("/script.sh", mode: "0755")

      expect(stub).to have_been_requested
    end
  end

  describe "#read_file_as_text" do
    it "delegates to download_file" do
      stub_request(:get, toolbox_url("/filesystem/download"))
        .with(query: { path: "/config.json" })
        .to_return(status: 200, body: "{\"a\":1}")

      expect(fs.read_file_as_text("/config.json")).to eq("{\"a\":1}")
    end
  end
end
