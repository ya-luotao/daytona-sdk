# frozen_string_literal: true

RSpec.describe Daytona::Configuration do
  describe "#initialize" do
    it "accepts api_key" do
      config = described_class.new(api_key: "test-key")
      expect(config.api_key).to eq("test-key")
    end

    it "accepts jwt_token and organization_id" do
      config = described_class.new(jwt_token: "jwt", organization_id: "org-123")
      expect(config.jwt_token).to eq("jwt")
      expect(config.organization_id).to eq("org-123")
    end

    it "has default api_url" do
      config = described_class.new
      expect(config.api_url).to eq("https://app.daytona.io/api")
    end

    it "allows custom api_url" do
      config = described_class.new(api_url: "https://custom.api.com")
      expect(config.api_url).to eq("https://custom.api.com")
    end

    it "warns about deprecated server_url" do
      expect { described_class.new(server_url: "https://old.api.com") }
        .to output(/DEPRECATION/).to_stderr
    end

    it "uses server_url as api_url when api_url not provided" do
      config = nil
      expect { config = described_class.new(server_url: "https://old.api.com") }
        .to output.to_stderr
      expect(config.api_url).to eq("https://old.api.com")
    end
  end

  describe "#authenticated?" do
    it "returns true when api_key is present" do
      config = described_class.new(api_key: "key")
      expect(config.authenticated?).to be true
    end

    it "returns true when jwt_token is present" do
      config = described_class.new(jwt_token: "token")
      expect(config.authenticated?).to be true
    end

    it "returns false when neither is present" do
      config = described_class.new
      expect(config.authenticated?).to be false
    end
  end

  describe "#jwt_auth?" do
    it "returns true when using jwt_token without api_key" do
      config = described_class.new(jwt_token: "token")
      expect(config.jwt_auth?).to be true
    end

    it "returns false when api_key is present" do
      config = described_class.new(api_key: "key", jwt_token: "token")
      expect(config.jwt_auth?).to be false
    end
  end

  describe "#validate!" do
    it "raises when no authentication is provided" do
      config = described_class.new
      expect { config.validate! }.to raise_error(Daytona::ConfigurationError, /API key or JWT token/)
    end

    it "raises when jwt_token provided without organization_id" do
      config = described_class.new(jwt_token: "token")
      expect { config.validate! }.to raise_error(Daytona::ConfigurationError, /Organization ID/)
    end

    it "succeeds with api_key" do
      config = described_class.new(api_key: "key")
      expect { config.validate! }.not_to raise_error
    end

    it "succeeds with jwt_token and organization_id" do
      config = described_class.new(jwt_token: "token", organization_id: "org")
      expect { config.validate! }.not_to raise_error
    end
  end

  describe "#to_h" do
    it "returns configuration as hash" do
      config = described_class.new(
        api_key: "key",
        api_url: "https://api.com",
        target: "us"
      )

      expect(config.to_h).to eq({
        api_key: "key",
        jwt_token: nil,
        organization_id: nil,
        api_url: "https://api.com",
        target: "us",
      })
    end
  end
end
