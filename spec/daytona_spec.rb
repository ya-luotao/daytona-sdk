# frozen_string_literal: true

RSpec.describe Daytona do
  it "has a version number" do
    expect(Daytona::VERSION).not_to be_nil
  end

  describe ".configure" do
    after { described_class.reset_configuration! }

    it "yields a configuration object" do
      expect { |b| described_class.configure(&b) }.to yield_with_args(Daytona::Configuration)
    end

    it "returns the configuration" do
      config = described_class.configure do |c|
        c.api_key = "test-key"
      end

      expect(config.api_key).to eq("test-key")
    end

    it "persists configuration" do
      described_class.configure do |c|
        c.api_key = "persistent-key"
      end

      expect(described_class.configuration.api_key).to eq("persistent-key")
    end
  end

  describe ".reset_configuration!" do
    it "resets the configuration" do
      described_class.configure { |c| c.api_key = "to-be-reset" }
      described_class.reset_configuration!

      expect(described_class.configuration).to be_nil
    end
  end
end
