# frozen_string_literal: true

RSpec.describe Daytona::Models::Resources do
  describe "#initialize" do
    it "creates resources with all parameters" do
      resources = described_class.new(cpu: 4, memory: 8, disk: 50, gpu: "nvidia-a100")

      expect(resources.cpu).to eq(4)
      expect(resources.memory).to eq(8)
      expect(resources.disk).to eq(50)
      expect(resources.gpu).to eq("nvidia-a100")
    end

    it "creates resources with defaults" do
      resources = described_class.new

      expect(resources.cpu).to be_nil
      expect(resources.memory).to be_nil
      expect(resources.disk).to be_nil
      expect(resources.gpu).to be_nil
    end

    it "allows partial specification" do
      resources = described_class.new(cpu: 2, memory: 4)

      expect(resources.cpu).to eq(2)
      expect(resources.memory).to eq(4)
      expect(resources.disk).to be_nil
    end
  end

  describe "#to_h" do
    it "converts to hash excluding nil values" do
      resources = described_class.new(cpu: 4, memory: 8)

      expect(resources.to_h).to eq({ cpu: 4, memory: 8 })
    end

    it "includes all values when set" do
      resources = described_class.new(cpu: 2, memory: 4, disk: 20, gpu: "nvidia")

      expect(resources.to_h).to eq({ cpu: 2, memory: 4, disk: 20, gpu: "nvidia" })
    end
  end

  describe ".from_hash" do
    it "creates resources from hash with string keys" do
      hash = { "cpu" => 4, "memory" => 8, "disk" => 50, "gpu" => "nvidia" }
      resources = described_class.from_hash(hash)

      expect(resources.cpu).to eq(4)
      expect(resources.memory).to eq(8)
      expect(resources.disk).to eq(50)
      expect(resources.gpu).to eq("nvidia")
    end

    it "creates resources from hash with symbol keys" do
      hash = { cpu: 2, memory: 4 }
      resources = described_class.from_hash(hash)

      expect(resources.cpu).to eq(2)
      expect(resources.memory).to eq(4)
    end

    it "returns nil for nil input" do
      resources = described_class.from_hash(nil)

      expect(resources).to be_nil
    end

    it "handles empty hash" do
      resources = described_class.from_hash({})

      expect(resources.cpu).to be_nil
      expect(resources.memory).to be_nil
    end
  end
end

RSpec.describe Daytona::Models::CodeLanguage do
  describe "constants" do
    it "defines PYTHON" do
      expect(described_class::PYTHON).to eq("python")
    end

    it "defines JAVASCRIPT" do
      expect(described_class::JAVASCRIPT).to eq("javascript")
    end

    it "defines TYPESCRIPT" do
      expect(described_class::TYPESCRIPT).to eq("typescript")
    end
  end
end

RSpec.describe Daytona::Models::VolumeMount do
  describe "#initialize" do
    it "creates volume mount with required parameters" do
      mount = described_class.new(volume_id: "vol-123", mount_path: "/data")

      expect(mount.volume_id).to eq("vol-123")
      expect(mount.mount_path).to eq("/data")
    end

    it "accepts optional subpath" do
      mount = described_class.new(volume_id: "vol-123", mount_path: "/data", subpath: "subdir")

      expect(mount.subpath).to eq("subdir")
    end
  end

  describe "#to_h" do
    it "converts to hash" do
      mount = described_class.new(volume_id: "vol-123", mount_path: "/data")

      expect(mount.to_h).to eq({
        volumeId: "vol-123",
        mountPath: "/data"
      })
    end

    it "includes subpath when present" do
      mount = described_class.new(volume_id: "vol-123", mount_path: "/data", subpath: "sub")

      expect(mount.to_h[:subpath]).to eq("sub")
    end
  end

  describe ".from_hash" do
    it "creates from hash" do
      hash = { "volumeId" => "vol-123", "mountPath" => "/data" }
      mount = described_class.from_hash(hash)

      expect(mount.volume_id).to eq("vol-123")
      expect(mount.mount_path).to eq("/data")
    end
  end
end

RSpec.describe Daytona::Models::Volume do
  describe "#initialize" do
    it "creates volume with all parameters" do
      volume = described_class.new(
        id: "vol-123",
        name: "my-volume",
        organization_id: "org-456",
        state: "ready",
        created_at: "2024-01-01T00:00:00Z",
        updated_at: "2024-01-01T00:00:00Z",
        last_used_at: "2024-01-01T00:00:00Z"
      )

      expect(volume.id).to eq("vol-123")
      expect(volume.name).to eq("my-volume")
      expect(volume.state).to eq("ready")
    end
  end

  describe ".from_hash" do
    it "creates from hash with camelCase keys" do
      hash = {
        "id" => "vol-123",
        "name" => "test",
        "organizationId" => "org-456",
        "state" => "ready",
        "createdAt" => "2024-01-01T00:00:00Z",
        "updatedAt" => "2024-01-01T00:00:00Z",
        "lastUsedAt" => "2024-01-01T00:00:00Z"
      }
      volume = described_class.from_hash(hash)

      expect(volume.id).to eq("vol-123")
      expect(volume.organization_id).to eq("org-456")
    end
  end
end

RSpec.describe Daytona::Models::ExecuteResponse do
  describe "#initialize" do
    it "creates response with required parameters" do
      response = described_class.new(result: "output", exit_code: 0)

      expect(response.result).to eq("output")
      expect(response.exit_code).to eq(0)
    end
  end

  describe "#success?" do
    it "returns true for exit code 0" do
      response = described_class.new(result: "", exit_code: 0)
      expect(response.success?).to be true
    end

    it "returns false for non-zero exit code" do
      response = described_class.new(result: "", exit_code: 1)
      expect(response.success?).to be false
    end
  end

  describe ".from_hash" do
    it "creates response from hash" do
      hash = { "result" => "output", "exitCode" => 0 }
      response = described_class.from_hash(hash)

      expect(response.result).to eq("output")
      expect(response.exit_code).to eq(0)
    end

    it "handles snake_case keys" do
      hash = { "result" => "output", "exit_code" => 1 }
      response = described_class.from_hash(hash)

      expect(response.exit_code).to eq(1)
    end
  end
end
