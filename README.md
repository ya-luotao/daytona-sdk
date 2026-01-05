# Daytona Ruby SDK

The official Ruby SDK for [Daytona](https://daytona.io) - a cloud development environment platform.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'daytona'
```

And then execute:

```bash
bundle install
```

Or install it yourself:

```bash
gem install daytona
```

## Quick Start

```ruby
require 'daytona'

# Configure with your API key
Daytona.configure do |config|
  config.api_key = ENV['DAYTONA_API_KEY']
end

# Create a client and sandbox
client = Daytona::Client.new
sandbox = client.create

# Execute commands
result = sandbox.process.exec("echo 'Hello from Daytona!'")
puts result.result

# Clean up
sandbox.delete
```

## Configuration

### Environment Variables

The SDK automatically reads from environment variables:

```bash
export DAYTONA_API_KEY="your-api-key"
export DAYTONA_API_URL="https://app.daytona.io/api"  # optional
export DAYTONA_TARGET="us"                            # optional
```

### Programmatic Configuration

```ruby
Daytona.configure do |config|
  config.api_key = "your-api-key"
  config.api_url = "https://app.daytona.io/api"
  config.target = "us"
end
```

### JWT Authentication

For JWT-based authentication (used in certain integrations):

```ruby
Daytona.configure do |config|
  config.jwt_token = "your-jwt-token"
  config.organization_id = "your-org-id"
end
```

### Per-Client Configuration

```ruby
config = Daytona::Configuration.new(api_key: "different-key")
client = Daytona::Client.new(config)
```

## Creating Sandboxes

### Basic Creation

```ruby
client = Daytona::Client.new

# Create with defaults
sandbox = client.create

# Create with a specific name
sandbox = client.create(name: "my-sandbox")

# Create with labels for organization
sandbox = client.create(labels: { "project" => "my-app", "env" => "dev" })
```

### With Custom Resources

```ruby
resources = Daytona::Resources.new(
  cpu: 4,
  memory: 8,     # GB
  disk: 50,      # GB
  gpu: "nvidia"  # optional
)

sandbox = client.create(resources: resources)
```

### From Custom Image

```ruby
# Using the Image builder
image = Daytona::Image.debian_slim("3.12")
                      .pip_install("flask", "gunicorn", "numpy")
                      .env("PORT" => "8080")
                      .workdir("/app")

sandbox = client.create(image: image)
```

### From Snapshot

```ruby
sandbox = client.create(snapshot_id: "snapshot-123")
```

### With Volume Mounts

```ruby
volume = Daytona::Volume.new(
  volume_id: "vol-123",
  mount_path: "/data"
)

sandbox = client.create(volumes: [volume])
```

### With Timeout

```ruby
# Wait up to 5 minutes for sandbox to be ready
sandbox = client.create(timeout: 300)
```

## Working with Sandboxes

### Retrieving Sandboxes

```ruby
# Get by ID or name
sandbox = client.get("sandbox-id-or-name")

# List all sandboxes
sandboxes = client.list

# List with pagination
result = client.list(page: 1, limit: 10)
result.sandboxes.each { |s| puts s.name }
puts "Total: #{result.total}"

# Filter by labels
sandboxes = client.list(labels: { "project" => "my-app" })
```

### Sandbox Lifecycle

```ruby
# Stop a running sandbox
client.stop(sandbox)

# Start a stopped sandbox
client.start(sandbox, timeout: 60)

# Delete a sandbox
client.delete(sandbox)

# Or using sandbox instance methods
sandbox.stop
sandbox.start(timeout: 60)
sandbox.delete
```

### Archiving

```ruby
# Archive sandbox to save resources
sandbox.archive

# Start will automatically unarchive
sandbox.start
```

## File System Operations

```ruby
fs = sandbox.fs

# Upload a file
fs.upload_file("/app/config.yml", File.read("local/config.yml"))

# Download a file
content = fs.download_file("/app/output.txt")

# Create directories
fs.create_folder("/app/data", mode: "0755")

# List directory contents
files = fs.list_files("/app")
files.each do |file|
  puts "#{file.name} (#{file.is_dir ? 'dir' : 'file'})"
end

# Get file info
info = fs.get_file_info("/app/main.py")
puts "Size: #{info.size}, Modified: #{info.mod_time}"

# Delete files
fs.delete_file("/app/temp.txt")

# Find files by pattern
files = fs.find_files("/app", pattern: "*.py")

# Search file contents
matches = fs.search_files("/app", pattern: "def main")

# Replace text in files
count = fs.replace_in_files("/app", pattern: "old_name", replacement: "new_name")
```

## Process Execution

```ruby
process = sandbox.process

# Simple command execution
result = process.exec("ls -la /app")
puts result.result       # stdout
puts result.exit_code    # exit code

# With working directory
result = process.exec("npm install", cwd: "/app")

# With environment variables
result = process.exec("python app.py", env: { "DEBUG" => "true" })

# With timeout (in seconds)
result = process.exec("long-running-task", timeout: 300)

# With streaming output
process.exec("pip install tensorflow") do |output|
  puts output  # Real-time output
end

# Run Python code directly
result = process.code_run(<<~PYTHON, language: Daytona::CodeLanguage::PYTHON)
  import os
  print(f"Working in: {os.getcwd()}")
PYTHON
```

## Git Operations

```ruby
git = sandbox.git

# Clone a repository
git.clone("https://github.com/user/repo.git", path: "/app")

# With authentication
git.clone(
  "https://github.com/user/private-repo.git",
  path: "/app",
  username: "user",
  password: ENV["GITHUB_TOKEN"]
)

# Stage files
git.add("/app", files: ["src/main.py", "README.md"])
git.add("/app")  # Stage all

# Commit changes
git.commit("/app", message: "Add new feature", author: "Name <email@example.com>")

# Push to remote
git.push("/app", username: "user", password: ENV["GITHUB_TOKEN"])

# Pull latest changes
git.pull("/app")

# List branches
branches = git.branches("/app")
branches.each { |b| puts "#{b.name} #{b.is_current ? '(current)' : ''}" }

# Create and checkout branch
git.create_branch("/app", name: "feature/new-feature")
git.checkout_branch("/app", name: "feature/new-feature")

# Get current status
status = git.status("/app")
```

## Code Interpreter

The code interpreter provides a stateful Python environment with persistent contexts:

```ruby
interpreter = sandbox.code_interpreter

# Create a context (optional - uses default if not specified)
interpreter.create_context("my-context")

# Run code in context
result = interpreter.run_code(<<~PYTHON, context_id: "my-context")
  x = 10
  y = 20
  result = x + y
  print(f"Result: {result}")
PYTHON

puts result[:output]

# Variables persist across executions
result = interpreter.run_code(<<~PYTHON, context_id: "my-context")
  print(f"Previous result was: {result}")
PYTHON

# With callbacks for streaming
interpreter.run_code(code,
  on_stdout: ->(text) { print text },
  on_stderr: ->(text) { warn text },
  on_result: ->(data) { puts "Done: #{data}" }
)

# Delete context when done
interpreter.delete_context("my-context")
```

## Computer Use (Desktop Automation)

For sandboxes with desktop environments:

```ruby
computer = sandbox.computer_use

# Take a screenshot
screenshot_base64 = computer.screenshot

# Mouse operations
computer.mouse_click(x: 100, y: 200)
computer.mouse_double_click(x: 100, y: 200)
computer.mouse_right_click(x: 100, y: 200)
computer.mouse_move(x: 150, y: 250)
computer.mouse_drag(start_x: 100, start_y: 100, end_x: 200, end_y: 200)
computer.mouse_scroll(x: 100, y: 200, direction: "down", amount: 3)

# Keyboard operations
computer.keyboard_type("Hello, World!")
computer.keyboard_key("Return")
computer.keyboard_key("ctrl+c")

# Get display info
info = computer.get_display_info
puts "Resolution: #{info[:width]}x#{info[:height]}"
```

## LSP (Language Server Protocol)

For IDE-like features:

```ruby
lsp = sandbox.lsp

# Start a language server
lsp.start(
  language: "python",
  path: "/app"
)

# Get completions at position
completions = lsp.completions(
  path: "/app/main.py",
  line: 10,
  character: 5
)

# Get hover info
info = lsp.hover(path: "/app/main.py", line: 10, character: 5)

# Get diagnostics
diagnostics = lsp.diagnostics(path: "/app/main.py")

# Stop the server
lsp.stop
```

## Image Builder

Build custom Docker images declaratively:

```ruby
# Start from base image
image = Daytona::Image.base("python:3.12-slim")

# Or use the pre-configured Debian slim
image = Daytona::Image.debian_slim("3.12")

# Chain builder methods
image = Daytona::Image.debian_slim("3.12")
                      .pip_install("flask", "gunicorn", "redis")
                      .pip_install("torch", index_url: "https://download.pytorch.org/whl/cpu")
                      .pip_install("mypackage", pre: true)
                      .env("PORT" => "8080", "DEBUG" => "false")
                      .workdir("/app")
                      .run_commands(
                        "mkdir -p /app/data",
                        "chmod 755 /app/data"
                      )
                      .entrypoint(["/bin/bash", "-c"])
                      .cmd(["python", "app.py"])

# Get the generated Dockerfile
puts image.dockerfile

# Use with sandbox creation
sandbox = client.create(image: image)
```

### Supported Python Versions

The `debian_slim` factory supports Python 3.9 through 3.13:

```ruby
Daytona::Image.debian_slim("3.9")   # python:3.9.22-slim-bookworm
Daytona::Image.debian_slim("3.10")  # python:3.10.17-slim-bookworm
Daytona::Image.debian_slim("3.11")  # python:3.11.12-slim-bookworm
Daytona::Image.debian_slim("3.12")  # python:3.12.10-slim-bookworm
Daytona::Image.debian_slim("3.13")  # python:3.13.3-slim-bookworm
```

## Volume Management

```ruby
volume_service = client.volume

# Create a volume
volume = volume_service.create(name: "my-data")

# List volumes
volumes = volume_service.list
volumes.each { |v| puts "#{v.id}: #{v.name}" }

# Get volume details
volume = volume_service.get("volume-id")

# Delete volume
volume_service.delete("volume-id")
```

## Snapshot Management

```ruby
snapshot_service = client.snapshot

# Create a snapshot from sandbox
snapshot = snapshot_service.create(
  sandbox_id: sandbox.id,
  name: "my-snapshot"
)

# List snapshots
snapshots = snapshot_service.list
snapshots.each { |s| puts "#{s.id}: #{s.name}" }

# Get snapshot details
snapshot = snapshot_service.get("snapshot-id")

# Delete snapshot
snapshot_service.delete("snapshot-id")
```

## Error Handling

```ruby
begin
  sandbox = client.get("non-existent")
rescue Daytona::NotFoundError => e
  puts "Sandbox not found: #{e.message}"
rescue Daytona::AuthenticationError => e
  puts "Authentication failed: #{e.message}"
rescue Daytona::RateLimitError => e
  puts "Rate limited: #{e.message}"
  puts "Headers: #{e.headers}"
rescue Daytona::TimeoutError => e
  puts "Operation timed out: #{e.message}"
rescue Daytona::DaytonaError => e
  puts "API error (#{e.status_code}): #{e.message}"
end
```

## Requirements

- Ruby 3.1 or higher
- Faraday ~> 2.0
- websocket-client-simple ~> 0.8

## Development

```bash
# Clone the repository
git clone https://github.com/daytonaio/daytona-sdk-ruby.git
cd daytona-sdk-ruby

# Install dependencies
bundle install

# Run tests
bundle exec rspec

# Run linter
bundle exec rubocop

# Generate documentation
bundle exec yard doc
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -am 'Add my feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Create a Pull Request

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## Links

- [Daytona Website](https://daytona.io)
- [API Documentation](https://docs.daytona.io)
- [GitHub Repository](https://github.com/daytonaio/daytona-sdk-ruby)
