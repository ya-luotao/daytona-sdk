# frozen_string_literal: true

require "spec_helper"

RSpec.describe Daytona::Models::CreateSandboxBaseParams do
  describe "#to_h" do
    it "maps snake_case attributes to camelCase keys and drops nils" do
      params = described_class.new(
        name: "box",
        language: "python",
        os_user: "daytona",
        env_vars: { "A" => "b" },
        auto_stop_interval: 15
      )

      expect(params.to_h).to eq(
        name: "box",
        language: "python",
        osUser: "daytona",
        envVars: { "A" => "b" },
        autoStopInterval: 15
      )
    end

    it "serializes volume mounts via to_h" do
      mount = Daytona::Models::VolumeMount.new(volume_id: "v1", mount_path: "/data")
      params = described_class.new(volumes: [mount])

      expect(params.to_h[:volumes]).to eq([{ volumeId: "v1", mountPath: "/data" }])
    end
  end

  describe "ephemeral handling" do
    it "forces auto_delete_interval to 0 when ephemeral" do
      params = described_class.new(ephemeral: true)

      expect(params.auto_delete_interval).to eq(0)
    end

    it "warns when ephemeral conflicts with a non-zero auto_delete_interval" do
      expect do
        described_class.new(ephemeral: true, auto_delete_interval: 30)
      end.to output(/cannot be used together/).to_stderr

      params = described_class.new(ephemeral: true, auto_delete_interval: 30)
      expect(params.auto_delete_interval).to eq(0)
    end
  end
end

RSpec.describe Daytona::Models::CreateSandboxFromImageParams do
  describe "#to_h" do
    it "includes a string image and serialized resources" do
      resources = Daytona::Models::Resources.new(cpu: 2, memory: 4)
      params = described_class.new(image: "python:3.12-slim", resources: resources)

      hash = params.to_h
      expect(hash[:image]).to eq("python:3.12-slim")
      expect(hash[:resources]).to eq(resources.to_h)
    end

    it "serializes a Daytona::Image via to_h" do
      image = Daytona::Image.debian_slim("3.12")
      params = described_class.new(image: image)

      expect(params.to_h[:image]).to eq(image.to_h)
    end
  end
end

RSpec.describe Daytona::Models::CreateSandboxFromSnapshotParams do
  describe "#to_h" do
    it "includes the snapshot name" do
      params = described_class.new(snapshot: "my-snap", language: "python")

      expect(params.to_h).to include(snapshot: "my-snap", language: "python")
    end

    it "omits the snapshot key when nil" do
      params = described_class.new(language: "python")

      expect(params.to_h).not_to have_key(:snapshot)
    end
  end
end
