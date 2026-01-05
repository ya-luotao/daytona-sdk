# frozen_string_literal: true

source "https://rubygems.org"

# Specify gem dependencies in daytona.gemspec
gemspec

group :development do
  gem "rake", "~> 13.0"
  gem "rubocop", "~> 1.50"
  gem "rubocop-rake", "~> 0.6"
  gem "rubocop-rspec", "~> 2.22"
  gem "yard", "~> 0.9"
end

group :test do
  gem "rspec", "~> 3.12"
  gem "webmock", "~> 3.18"
  gem "vcr", "~> 6.1"
  gem "simplecov", "~> 0.22", require: false
end
