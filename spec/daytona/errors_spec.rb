# frozen_string_literal: true

RSpec.describe Daytona::DaytonaError do
  describe "#initialize" do
    it "accepts a message" do
      error = described_class.new("Something went wrong")
      expect(error.message).to eq("Something went wrong")
    end

    it "accepts status_code" do
      error = described_class.new("Error", status_code: 500)
      expect(error.status_code).to eq(500)
    end

    it "accepts headers" do
      error = described_class.new("Error", headers: { "X-Request-Id" => "123" })
      expect(error.headers).to eq({ "X-Request-Id" => "123" })
    end

    it "defaults headers to empty hash" do
      error = described_class.new("Error")
      expect(error.headers).to eq({})
    end
  end
end

RSpec.describe Daytona::NotFoundError do
  it "is a DaytonaError" do
    expect(described_class).to be < Daytona::DaytonaError
  end
end

RSpec.describe Daytona::RateLimitError do
  it "is a DaytonaError" do
    expect(described_class).to be < Daytona::DaytonaError
  end
end

RSpec.describe Daytona::TimeoutError do
  it "is a DaytonaError" do
    expect(described_class).to be < Daytona::DaytonaError
  end
end

RSpec.describe Daytona::AuthenticationError do
  it "is a DaytonaError" do
    expect(described_class).to be < Daytona::DaytonaError
  end
end

RSpec.describe Daytona::ConfigurationError do
  it "is a DaytonaError" do
    expect(described_class).to be < Daytona::DaytonaError
  end
end
