# frozen_string_literal: true

require "spec_helper"

RSpec.describe Daytona::Sandbox do
  let(:api_url) { "https://api.daytona.io" }
  let(:http_client) { Daytona::API::HttpClient.new(base_url: api_url, api_key: "test-api-key") }
  let(:sandbox_data) do
    {
      "id" => "sb-1",
      "name" => "my-box",
      "organizationId" => "org-1",
      "state" => "started",
      "autoStopInterval" => 15,
      "labels" => { "env" => "dev" },
    }
  end

  subject(:sandbox) do
    described_class.new(
      sandbox_data: sandbox_data,
      http_client: http_client,
      get_toolbox_url: -> { "#{api_url}/toolbox" }
    )
  end

  def sandbox_url(path = "")
    "#{api_url}/sandbox#{path}"
  end

  # Toolbox URL as built by Sandbox#ensure_toolbox_url!: proc result + "/" + id
  def toolbox_url(path)
    "#{api_url}/toolbox/sb-1#{path}"
  end

  describe "#initialize" do
    it "maps camelCase fields onto attributes" do
      expect(sandbox.id).to eq("sb-1")
      expect(sandbox.name).to eq("my-box")
      expect(sandbox.organization_id).to eq("org-1")
      expect(sandbox.state).to eq("started")
      expect(sandbox.auto_stop_interval).to eq(15)
      expect(sandbox.labels).to eq({ "env" => "dev" })
    end

    it "wires up the service accessors" do
      expect(sandbox.fs).to be_a(Daytona::Services::FileSystem)
      expect(sandbox.git).to be_a(Daytona::Services::Git)
      expect(sandbox.process).to be_a(Daytona::Services::Process)
    end

    it "raises when given non-hash data" do
      expect do
        described_class.new(sandbox_data: "oops", http_client: http_client, get_toolbox_url: -> {})
      end.to raise_error(Daytona::DaytonaError, /expected Hash/)
    end
  end

  describe "#set_labels" do
    it "stringifies values and PUTs them" do
      stub_request(:put, sandbox_url("/sb-1/labels"))
        .with(body: { labels: { "env" => "prod", "active" => "true" } })
        .to_return(status: 200, body: { labels: { "env" => "prod", "active" => "true" } }.to_json,
                   headers: { "Content-Type" => "application/json" })

      result = sandbox.set_labels("env" => "prod", "active" => true)

      expect(result).to eq({ "env" => "prod", "active" => "true" })
    end
  end

  describe "#start" do
    it "POSTs start and refreshes state" do
      start_stub = stub_request(:post, sandbox_url("/sb-1/start"))
                   .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })
      stub_request(:get, sandbox_url("/sb-1"))
        .to_return(status: 200, body: { id: "sb-1", state: "started" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      sandbox.start

      expect(start_stub).to have_been_requested
      expect(sandbox.state).to eq("started")
    end

    it "rejects a negative timeout" do
      expect { sandbox.start(timeout: -1) }.to raise_error(Daytona::DaytonaError)
    end
  end

  describe "#wait_for_start" do
    subject(:sandbox) do
      described_class.new(
        sandbox_data: sandbox_data.merge("state" => "starting"),
        http_client: http_client,
        get_toolbox_url: -> { "#{api_url}/toolbox" }
      )
    end

    it "raises TimeoutError when the sandbox never starts" do
      stub_request(:get, sandbox_url("/sb-1"))
        .to_return(status: 200, body: { id: "sb-1", state: "starting" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect { sandbox.wait_for_start(timeout: 0.05) }
        .to raise_error(Daytona::TimeoutError, /failed to start/)
    end

    it "raises DaytonaError when the sandbox enters an error state" do
      stub_request(:get, sandbox_url("/sb-1"))
        .to_return(status: 200, body: { id: "sb-1", state: "error", errorReason: "boom" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect { sandbox.wait_for_start(timeout: 1) }
        .to raise_error(Daytona::DaytonaError, /boom/)
    end
  end

  describe "#delete" do
    it "treats a 404 on refresh as destroyed" do
      stub_request(:delete, sandbox_url("/sb-1"))
        .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })
      stub_request(:get, sandbox_url("/sb-1"))
        .to_return(status: 404, body: { message: "gone" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      sandbox.delete

      expect(sandbox.state).to eq("destroyed")
    end
  end

  describe "#set_autostop_interval" do
    it "PUTs a non-negative integer" do
      stub_request(:put, sandbox_url("/sb-1/autostop-interval"))
        .with(body: { interval: 30 })
        .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      sandbox.set_autostop_interval(30)

      expect(sandbox.auto_stop_interval).to eq(30)
    end

    it "rejects negative or non-integer intervals" do
      expect { sandbox.set_autostop_interval(-1) }.to raise_error(Daytona::DaytonaError)
      expect { sandbox.set_autostop_interval(1.5) }.to raise_error(Daytona::DaytonaError)
    end
  end

  describe "#get_user_home_dir" do
    it "reads dir from the toolbox info endpoint" do
      stub_request(:get, toolbox_url("/info/user-home-dir"))
        .to_return(status: 200, body: { dir: "/home/daytona" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect(sandbox.get_user_home_dir).to eq("/home/daytona")
    end
  end

  describe "#get_preview_link" do
    it "GETs the preview url for a port" do
      stub_request(:get, sandbox_url("/sb-1/ports/3000/preview-url"))
        .to_return(status: 200, body: { url: "https://preview", token: "t" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect(sandbox.get_preview_link(3000)).to eq({ "url" => "https://preview", "token" => "t" })
    end
  end

  describe "SSH access" do
    it "create_ssh_access POSTs the expiry" do
      stub = stub_request(:post, sandbox_url("/sb-1/ssh-access"))
             .with(body: { expiresInMinutes: 60 })
             .to_return(status: 200, body: { token: "abc" }.to_json,
                        headers: { "Content-Type" => "application/json" })

      sandbox.create_ssh_access(expires_in_minutes: 60)

      expect(stub).to have_been_requested
    end

    it "revoke_ssh_access DELETEs the token" do
      stub = stub_request(:delete, sandbox_url("/sb-1/ssh-access/abc"))
             .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      sandbox.revoke_ssh_access("abc")

      expect(stub).to have_been_requested
    end

    it "validate_ssh_access POSTs the token" do
      stub = stub_request(:post, "#{api_url}/sandbox/ssh-access/validate")
             .with(body: { token: "abc" })
             .to_return(status: 200, body: { valid: true }.to_json,
                        headers: { "Content-Type" => "application/json" })

      expect(sandbox.validate_ssh_access("abc")).to eq({ "valid" => true })
      expect(stub).to have_been_requested
    end
  end

  describe "#stop" do
    it "POSTs stop and waits for the stopped state" do
      stop_stub = stub_request(:post, sandbox_url("/sb-1/stop"))
                  .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })
      stub_request(:get, sandbox_url("/sb-1"))
        .to_return(status: 200, body: { id: "sb-1", state: "stopped" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      sandbox.stop

      expect(stop_stub).to have_been_requested
      expect(sandbox.state).to eq("stopped")
    end
  end

  describe "#archive" do
    it "POSTs archive and refreshes" do
      archive_stub = stub_request(:post, sandbox_url("/sb-1/archive"))
                     .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })
      stub_request(:get, sandbox_url("/sb-1"))
        .to_return(status: 200, body: { id: "sb-1", state: "archived" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      sandbox.archive

      expect(archive_stub).to have_been_requested
      expect(sandbox.state).to eq("archived")
    end
  end

  describe "#recover" do
    it "POSTs recover and waits for start" do
      recover_stub = stub_request(:post, sandbox_url("/sb-1/recover"))
                     .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })
      stub_request(:get, sandbox_url("/sb-1"))
        .to_return(status: 200, body: { id: "sb-1", state: "started" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      sandbox.recover

      expect(recover_stub).to have_been_requested
    end
  end

  describe "#get_work_dir" do
    it "reads dir from the toolbox work-dir endpoint" do
      stub_request(:get, toolbox_url("/info/work-dir"))
        .to_return(status: 200, body: { dir: "/workspace" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect(sandbox.get_work_dir).to eq("/workspace")
    end
  end

  describe "auto interval setters" do
    it "set_auto_archive_interval PUTs the interval" do
      stub_request(:put, sandbox_url("/sb-1/auto-archive-interval"))
        .with(body: { interval: 120 })
        .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      sandbox.set_auto_archive_interval(120)

      expect(sandbox.auto_archive_interval).to eq(120)
    end

    it "set_auto_archive_interval rejects negatives" do
      expect { sandbox.set_auto_archive_interval(-1) }.to raise_error(Daytona::DaytonaError)
    end

    it "set_auto_delete_interval PUTs the interval (allowing negatives)" do
      stub_request(:put, sandbox_url("/sb-1/auto-delete-interval"))
        .with(body: { interval: -1 })
        .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      sandbox.set_auto_delete_interval(-1)

      expect(sandbox.auto_delete_interval).to eq(-1)
    end
  end

  describe "#refresh_activity" do
    it "POSTs to the activity endpoint" do
      stub = stub_request(:post, sandbox_url("/sb-1/activity"))
             .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      sandbox.refresh_activity

      expect(stub).to have_been_requested
    end
  end

  describe "#create_lsp_server" do
    it "builds an LspServer for the sandbox" do
      lsp = sandbox.create_lsp_server("python", "/home/user/project")

      expect(lsp).to be_a(Daytona::Services::LspServer)
      expect(lsp.language_id).to eq("python")
      expect(lsp.path_to_project).to eq("/home/user/project")
    end
  end
end
