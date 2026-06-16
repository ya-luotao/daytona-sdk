# frozen_string_literal: true

require "spec_helper"

RSpec.describe Daytona::Services::Git do
  subject(:git) { build_service(described_class) }

  def stub_post(path, body)
    stub_request(:post, toolbox_url(path))
      .with(body: body)
      .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })
  end

  describe "#add" do
    it "POSTs path and files" do
      stub = stub_post("/git/add", { path: "/repo", files: ["a.txt"] })
      git.add("/repo", ["a.txt"])
      expect(stub).to have_been_requested
    end
  end

  describe "#branches" do
    it "returns the branches array" do
      stub_request(:get, toolbox_url("/git/branches"))
        .with(query: { path: "/repo" })
        .to_return(status: 200, body: { branches: [{ "name" => "main" }] }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect(git.branches("/repo")).to eq([{ "name" => "main" }])
    end

    it "returns an empty array when the key is missing" do
      stub_request(:get, toolbox_url("/git/branches"))
        .with(query: { path: "/repo" })
        .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      expect(git.branches("/repo")).to eq([])
    end
  end

  describe "#clone" do
    it "POSTs only url and path by default" do
      stub = stub_post("/git/clone", { url: "https://example.com/r.git", path: "/repo" })
      git.clone("https://example.com/r.git", "/repo")
      expect(stub).to have_been_requested
    end

    it "includes optional auth, branch and commit fields" do
      stub = stub_post("/git/clone", {
        url: "https://example.com/r.git",
        path: "/repo",
        branch: "dev",
        commitId: "abc123",
        username: "user",
        password: "token",
      })

      git.clone("https://example.com/r.git", "/repo",
                branch: "dev", commit_id: "abc123", username: "user", password: "token")

      expect(stub).to have_been_requested
    end
  end

  describe "#commit" do
    it "POSTs commit metadata with allowEmpty" do
      stub = stub_post("/git/commit", {
        path: "/repo", message: "msg", author: "Me", email: "me@x.com", allowEmpty: false
      })

      git.commit("/repo", "msg", "Me", "me@x.com")

      expect(stub).to have_been_requested
    end
  end

  describe "#push and #pull" do
    it "push includes credentials when given" do
      stub = stub_post("/git/push", { path: "/repo", username: "u", password: "p" })
      git.push("/repo", username: "u", password: "p")
      expect(stub).to have_been_requested
    end

    it "pull omits credentials when not given" do
      stub = stub_post("/git/pull", { path: "/repo" })
      git.pull("/repo")
      expect(stub).to have_been_requested
    end
  end

  describe "#status" do
    it "GETs status for the path" do
      stub_request(:get, toolbox_url("/git/status"))
        .with(query: { path: "/repo" })
        .to_return(status: 200, body: { "unstaged" => ["a.txt"] }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect(git.status("/repo")).to eq({ "unstaged" => ["a.txt"] })
    end
  end

  describe "#log" do
    it "passes the limit and returns commits" do
      stub_request(:get, toolbox_url("/git/log"))
        .with(query: { path: "/repo", limit: "5" })
        .to_return(status: 200, body: { commits: [{ "message" => "init" }] }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect(git.log("/repo", limit: 5)).to eq([{ "message" => "init" }])
    end
  end

  describe "branch management" do
    it "create_branch POSTs name" do
      stub = stub_post("/git/branch/create", { path: "/repo", name: "feature" })
      git.create_branch("/repo", "feature")
      expect(stub).to have_been_requested
    end

    it "delete_branch POSTs name" do
      stub = stub_post("/git/branch/delete", { path: "/repo", name: "old" })
      git.delete_branch("/repo", "old")
      expect(stub).to have_been_requested
    end

    it "checkout_branch POSTs branch" do
      stub = stub_post("/git/checkout", { path: "/repo", branch: "main" })
      git.checkout_branch("/repo", "main")
      expect(stub).to have_been_requested
    end
  end
end
