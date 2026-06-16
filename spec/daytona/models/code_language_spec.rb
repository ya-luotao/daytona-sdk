# frozen_string_literal: true

require "spec_helper"

RSpec.describe Daytona::Models::CodeLanguage do
  describe ".valid?" do
    it "is true for supported languages (case-insensitive)" do
      expect(described_class.valid?("python")).to be(true)
      expect(described_class.valid?("TypeScript")).to be(true)
    end

    it "is false for unsupported languages" do
      expect(described_class.valid?("ruby")).to be(false)
      expect(described_class.valid?(nil)).to be(false)
    end
  end

  describe ".normalize" do
    it "downcases recognized languages" do
      expect(described_class.normalize("JavaScript")).to eq("javascript")
    end

    it "falls back to python for unknown input" do
      expect(described_class.normalize("cobol")).to eq("python")
      expect(described_class.normalize(nil)).to eq("python")
    end
  end
end
