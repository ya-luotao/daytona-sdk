# frozen_string_literal: true

RSpec.describe Daytona do
  it "has a version number" do
    expect(Daytona::VERSION).not_to be_nil
  end

  describe ".configure" do
    after { Daytona.reset_configuration! }

    it "yields a configuration object" do
      expect { |b| Daytona.configure(&b) }.to yield_with_args(Daytona::Configuration)
    end

    it "returns the configuration" do
      config = Daytona.configure do |c|
        c.api_key = "test-key"
      end

      expect(config.api_key).to eq("test-key")
    end

    it "persists configuration" do
      Daytona.configure do |c|
        c.api_key = "persistent-key"
      end

      expect(Daytona.configuration.api_key).to eq("persistent-key")
    end
  end

  describe ".reset_configuration!" do
    it "resets the configuration" do
      Daytona.configure { |c| c.api_key = "to-be-reset" }
      Daytona.reset_configuration!

      expect(Daytona.configuration).to be_nil
    end
  end
end
