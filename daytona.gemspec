# frozen_string_literal: true

require_relative "lib/daytona/version"

Gem::Specification.new do |spec|
  spec.name = "daytona"
  spec.version = Daytona::VERSION
  spec.authors = ["Daytona Platforms Inc."]
  spec.email = ["support@daytona.io"]

  spec.summary = "Ruby SDK for Daytona"
  spec.description = "Official Ruby SDK for interacting with Daytona sandboxes - cloud development environments"
  spec.homepage = "https://github.com/daytonaio/sdk-ruby"
  spec.license = "Apache-2.0"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/daytonaio/sdk-ruby"
  spec.metadata["changelog_uri"] = "https://github.com/daytonaio/sdk-ruby/blob/main/CHANGELOG.md"
  spec.metadata["documentation_uri"] = "https://www.daytona.io/docs/sdk"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(__dir__) do
    Dir["{lib}/**/*", "LICENSE", "README.md", "CHANGELOG.md"].reject { |f| File.directory?(f) }
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "faraday-multipart", "~> 1.0"
  spec.add_dependency "websocket-client-simple", "~> 0.8"
  spec.add_dependency "dotenv", "~> 3.0"

  # Development dependencies are in Gemfile
end
