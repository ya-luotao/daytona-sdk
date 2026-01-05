# frozen_string_literal: true

# Copyright 2025 Daytona Platforms Inc.
# SPDX-License-Identifier: Apache-2.0

require "shellwords"

module Daytona
  # Declarative Dockerfile builder for Daytona sandboxes.
  #
  # Use factory methods like Image.base, Image.debian_slim, or Image.from_dockerfile
  # to create instances.
  #
  # @example From a base image
  #   image = Daytona::Image.base("python:3.12-slim")
  #
  # @example Using debian_slim with pip packages
  #   image = Daytona::Image
  #     .debian_slim("3.12")
  #     .pip_install("numpy", "pandas", "matplotlib")
  #     .env("PROJECT_ROOT" => "/home/daytona")
  #
  # @example From existing Dockerfile
  #   image = Daytona::Image.from_dockerfile("Dockerfile")
  class Image
    # Supported Python version series
    SUPPORTED_PYTHON_SERIES = %w[3.9 3.10 3.11 3.12 3.13].freeze

    # Latest micro versions for each series
    LATEST_PYTHON_MICRO_VERSIONS = {
      "3.9" => "3.9.22",
      "3.10" => "3.10.17",
      "3.11" => "3.11.12",
      "3.12" => "3.12.10",
      "3.13" => "3.13.3",
    }.freeze

    # @return [String] Generated Dockerfile content
    attr_reader :dockerfile

    # @return [Array<Hash>] Context files to include
    attr_reader :context_list

    # Create from an existing base image
    #
    # @param image [String] Base image name
    # @return [Image]
    #
    # @example
    #   image = Daytona::Image.base("python:3.12-slim-bookworm")
    def self.base(image)
      img = new
      img.instance_variable_set(:@dockerfile, "FROM #{image}\n")
      img
    end

    # Create a Debian slim image with Python
    #
    # @param python_version [String, nil] Python version (e.g., "3.12")
    # @return [Image]
    #
    # @example
    #   image = Daytona::Image.debian_slim("3.12")
    def self.debian_slim(python_version = nil)
      version = process_python_version(python_version)

      img = new
      commands = [
        "FROM python:#{version}-slim-bookworm",
        "RUN apt-get update",
        "RUN apt-get install -y gcc gfortran build-essential",
        "RUN pip install --upgrade pip",
        "RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections",
      ]
      img.instance_variable_set(:@dockerfile, "#{commands.join("\n")}\n")
      img
    end

    # Create from an existing Dockerfile
    #
    # @param path [String] Path to Dockerfile
    # @return [Image]
    #
    # @example
    #   image = Daytona::Image.from_dockerfile("Dockerfile")
    def self.from_dockerfile(path)
      path = File.expand_path(path)
      raise DaytonaError, "Dockerfile not found: #{path}" unless File.exist?(path)

      img = new
      img.instance_variable_set(:@dockerfile, File.read(path))
      img
    end

    # Initialize a new Image (use factory methods instead)
    def initialize
      @dockerfile = ""
      @context_list = []
    end

    # Install packages using pip
    #
    # @param packages [Array<String>] Packages to install
    # @param find_links [Array<String>, nil] Find-links URLs
    # @param index_url [String, nil] Index URL
    # @param extra_index_urls [Array<String>, nil] Extra index URLs
    # @param pre [Boolean] Install pre-release packages
    # @param extra_options [String] Additional pip options
    # @return [self]
    #
    # @example
    #   image = Daytona::Image.debian_slim("3.12")
    #     .pip_install("requests", "pandas")
    #     .pip_install("torch", index_url: "https://download.pytorch.org/whl/cpu")
    def pip_install(*packages, find_links: nil, index_url: nil, extra_index_urls: nil, pre: false, extra_options: "")
      pkgs = flatten_args(packages)
      return self if pkgs.empty?

      extra_args = format_pip_install_args(
        find_links: find_links,
        index_url: index_url,
        extra_index_urls: extra_index_urls,
        pre: pre,
        extra_options: extra_options
      )

      @dockerfile += "RUN python -m pip install #{Shellwords.join(pkgs.sort)}#{extra_args}\n"
      self
    end

    # Install from requirements.txt
    #
    # @param requirements_txt [String] Path to requirements.txt
    # @param find_links [Array<String>, nil] Find-links URLs
    # @param index_url [String, nil] Index URL
    # @param extra_index_urls [Array<String>, nil] Extra index URLs
    # @param pre [Boolean] Install pre-release packages
    # @param extra_options [String] Additional pip options
    # @return [self]
    #
    # @example
    #   image = Daytona::Image.debian_slim("3.12")
    #     .pip_install_from_requirements("requirements.txt")
    def pip_install_from_requirements(requirements_txt, find_links: nil, index_url: nil, extra_index_urls: nil, pre: false, extra_options: "")
      requirements_txt = File.expand_path(requirements_txt)
      raise DaytonaError, "Requirements file not found: #{requirements_txt}" unless File.exist?(requirements_txt)

      extra_args = format_pip_install_args(
        find_links: find_links,
        index_url: index_url,
        extra_index_urls: extra_index_urls,
        pre: pre,
        extra_options: extra_options
      )

      archive_path = compute_archive_path(requirements_txt)
      @context_list << { source_path: requirements_txt, archive_path: archive_path }
      @dockerfile += "COPY #{archive_path} /.requirements.txt\n"
      @dockerfile += "RUN python -m pip install -r /.requirements.txt#{extra_args}\n"
      self
    end

    # Add a local file to the image
    #
    # @param local_path [String] Local file path
    # @param remote_path [String] Remote path in the image
    # @return [self]
    #
    # @example
    #   image.add_local_file("config.json", "/home/daytona/config.json")
    def add_local_file(local_path, remote_path)
      local_path = File.expand_path(local_path)
      remote_path = "#{remote_path}#{File.basename(local_path)}" if remote_path.end_with?("/")

      archive_path = compute_archive_path(local_path)
      @context_list << { source_path: local_path, archive_path: archive_path }
      @dockerfile += "COPY #{archive_path} #{remote_path}\n"
      self
    end

    # Add a local directory to the image
    #
    # @param local_path [String] Local directory path
    # @param remote_path [String] Remote path in the image
    # @return [self]
    #
    # @example
    #   image.add_local_dir("src", "/home/daytona/src")
    def add_local_dir(local_path, remote_path)
      local_path = File.expand_path(local_path)

      archive_path = compute_archive_path(local_path)
      @context_list << { source_path: local_path, archive_path: archive_path }
      @dockerfile += "COPY #{archive_path} #{remote_path}\n"
      self
    end

    # Run commands in the image
    #
    # @param commands [Array<String, Array<String>>] Commands to run
    # @return [self]
    #
    # @example
    #   image.run_commands(
    #     "echo 'Hello, world!'",
    #     ["bash", "-c", "echo Hello again"]
    #   )
    def run_commands(*commands)
      commands.flatten.each do |command|
        if command.is_a?(Array)
          escaped = command.map { |c| "\"#{c.gsub('"', '\\"')}\"" }
          @dockerfile += "RUN #{escaped.join(' ')}\n"
        else
          @dockerfile += "RUN #{command}\n"
        end
      end
      self
    end

    # Set environment variables
    #
    # @param env_vars [Hash{String => String}] Environment variables
    # @return [self]
    #
    # @example
    #   image.env("PROJECT_ROOT" => "/home/daytona", "DEBUG" => "true")
    def env(env_vars)
      non_string = env_vars.reject { |_, v| v.is_a?(String) }
      raise DaytonaError, "ENV values must be strings. Invalid keys: #{non_string.keys}" unless non_string.empty?

      env_vars.each do |key, val|
        @dockerfile += "ENV #{key}=#{Shellwords.escape(val)}\n"
      end
      self
    end

    # Set working directory
    #
    # @param path [String] Working directory path
    # @return [self]
    #
    # @example
    #   image.workdir("/home/daytona")
    def workdir(path)
      @dockerfile += "WORKDIR #{Shellwords.escape(path.to_s)}\n"
      self
    end

    # Set entrypoint
    #
    # @param commands [Array<String>] Entrypoint commands
    # @return [self]
    #
    # @example
    #   image.entrypoint(["/bin/bash"])
    def entrypoint(commands)
      raise DaytonaError, "entrypoint must be an array of strings" unless commands.is_a?(Array)

      args_str = commands.map { |c| "\"#{c}\"" }.join(", ")
      @dockerfile += "ENTRYPOINT [#{args_str}]\n"
      self
    end

    # Set default command
    #
    # @param commands [Array<String>] CMD commands
    # @return [self]
    #
    # @example
    #   image.cmd(["/bin/bash", "-c", "echo hello"])
    def cmd(commands)
      raise DaytonaError, "cmd must be an array of strings" unless commands.is_a?(Array)

      args_str = commands.map { |c| "\"#{c}\"" }.join(", ")
      @dockerfile += "CMD [#{args_str}]\n"
      self
    end

    # Add arbitrary Dockerfile commands
    #
    # @param commands [Array<String>] Dockerfile commands
    # @param context_dir [String, nil] Context directory for COPY commands
    # @return [self]
    #
    # @example
    #   image.dockerfile_commands(["RUN echo 'custom'", "EXPOSE 8080"])
    def dockerfile_commands(commands, context_dir: nil)
      if context_dir
        context_dir = File.expand_path(context_dir)
        raise DaytonaError, "Context directory not found: #{context_dir}" unless File.directory?(context_dir)
      end

      @dockerfile += "#{commands.join("\n")}\n"
      self
    end

    # Convert to hash for API requests
    #
    # @return [Hash]
    def to_h
      {
        dockerfileContent: @dockerfile,
        contextList: @context_list,
      }
    end

    private

    def self.process_python_version(python_version)
      if python_version.nil?
        # Match local Ruby version... but we're using Python, so default to 3.12
        python_version = "3.12"
      end

      series = python_version.split(".")[0..1].join(".")

      unless SUPPORTED_PYTHON_SERIES.include?(series)
        raise DaytonaError, "Unsupported Python version: #{python_version}. " \
                            "Supported: #{SUPPORTED_PYTHON_SERIES}"
      end

      # If full version specified, use it
      return python_version if python_version.count(".") >= 2

      # Otherwise, get latest micro version for the series
      LATEST_PYTHON_MICRO_VERSIONS[series]
    end

    def flatten_args(args)
      args.flatten.select { |a| a.is_a?(String) }
    end

    def format_pip_install_args(find_links: nil, index_url: nil, extra_index_urls: nil, pre: false, extra_options: "")
      extra_args = ""

      if find_links
        find_links.each do |link|
          extra_args += " --find-links #{Shellwords.escape(link)}"
        end
      end

      extra_args += " --index-url #{Shellwords.escape(index_url)}" if index_url

      if extra_index_urls
        extra_index_urls.each do |url|
          extra_args += " --extra-index-url #{Shellwords.escape(url)}"
        end
      end

      extra_args += " --pre" if pre
      extra_args += " #{extra_options.strip}" unless extra_options.empty?

      extra_args
    end

    def compute_archive_path(path)
      # Simple hash-based path for context files
      require "digest"
      hash = Digest::SHA256.hexdigest(path)[0..7]
      "context/#{hash}/#{File.basename(path)}"
    end
  end
end
