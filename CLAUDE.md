# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with this repository.

## Project Overview

This is an **unofficial, community-maintained** Ruby SDK for [Daytona](https://daytona.io) - a cloud development environment platform. It provides a Ruby interface for creating and managing Daytona sandboxes.

## Commands

### Install Dependencies
```bash
bundle install
```

### Run Tests
```bash
bundle exec rspec
```

### Run Linter
```bash
bundle exec rubocop
```

### Run Tests with Coverage
```bash
COVERAGE=true bundle exec rspec
```

### Build Gem
```bash
gem build daytona.gemspec
```

### Generate Documentation
```bash
bundle exec yard doc
```

## Architecture

### Main Entry Point
- `lib/daytona.rb` - Main module with global configuration support

### Core Classes
- `Daytona::Client` (`lib/daytona/client.rb`) - Main client for creating/managing sandboxes
- `Daytona::Sandbox` (`lib/daytona/sandbox.rb`) - Sandbox instance with service accessors
- `Daytona::Configuration` (`lib/daytona/configuration.rb`) - API key and URL configuration

### Namespaces

**Models** (`Daytona::Models::*`):
- `Resources` - CPU/memory/disk/GPU specifications
- `CreateParams` - Sandbox creation parameters
- `ExecuteResponse` - Command execution result
- `VolumeMount`, `Volume` - Volume management
- `CodeLanguage` - Language constants (PYTHON, JAVASCRIPT, TYPESCRIPT)

**Services** (`Daytona::Services::*`):
- `FileSystem` - File operations (upload, download, list, search)
- `Process` - Command execution and session management
- `Git` - Git operations (clone, commit, push, pull)
- `CodeInterpreter` - Stateful Python execution environment
- `ComputerUse` - Desktop automation (mouse, keyboard, screenshot)
- `LspServer` - Language Server Protocol support
- `VolumeService` - Volume management
- `SnapshotService` - Snapshot management

**API Layer** (`Daytona::API::*`):
- `HttpClient` - Faraday-based HTTP client with authentication

### Service Pattern

Services inherit from `BaseService` and communicate with the Daytona toolbox API:
```ruby
# Toolbox URL pattern: {api_base}/toolbox/{sandbox_id}/toolbox
sandbox.process.exec("ls -la")  # POST /toolbox/{id}/toolbox/process/execute
sandbox.fs.list_files("/app")   # GET /toolbox/{id}/toolbox/files?path=/app
```

### Image Builder

`Daytona::Image` provides a fluent interface for building Docker images:
```ruby
image = Daytona::Image.debian_slim("3.12")
                      .pip_install("flask", "gunicorn")
                      .env("PORT" => "8080")
                      .workdir("/app")
```

## Testing

Tests use RSpec with WebMock for HTTP mocking and VCR for recording/replaying HTTP interactions.

### Key Test Files
- `spec/spec_helper.rb` - Test configuration with VCR setup
- `spec/daytona/api/http_client_spec.rb` - HTTP client tests
- `spec/daytona/models/resources_spec.rb` - Model tests
- `spec/daytona/configuration_spec.rb` - Configuration tests

### Running Specific Tests
```bash
bundle exec rspec spec/daytona/api/http_client_spec.rb
bundle exec rspec spec/daytona/models/
```

## Dependencies

- Ruby 3.1+
- `faraday` (~> 2.0) - HTTP client
- `websocket-client-simple` (~> 0.8) - WebSocket for PTY/interpreter

## Environment Variables

- `DAYTONA_API_KEY` - API key for authentication
- `DAYTONA_API_URL` - API base URL (default: https://app.daytona.io/api)
- `DAYTONA_TARGET` - Target region (optional)
