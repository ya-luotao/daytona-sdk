# frozen_string_literal: true

require "tempfile"

RSpec.describe Daytona::Image do
  describe ".base" do
    it "creates an image from base" do
      image = described_class.base("python:3.12-slim")
      expect(image.dockerfile).to eq("FROM python:3.12-slim\n")
    end
  end

  describe ".debian_slim" do
    it "creates a debian slim image with Python" do
      image = described_class.debian_slim("3.12")
      expect(image.dockerfile).to include("FROM python:3.12.10-slim-bookworm")
      expect(image.dockerfile).to include("apt-get update")
      expect(image.dockerfile).to include("pip install --upgrade pip")
    end

    it "uses latest micro version" do
      image = described_class.debian_slim("3.11")
      expect(image.dockerfile).to include("python:3.11.12-slim-bookworm")
    end

    it "raises for unsupported Python version" do
      expect { described_class.debian_slim("2.7") }
        .to raise_error(Daytona::DaytonaError, /Unsupported Python version/)
    end
  end

  describe "#pip_install" do
    it "adds pip install command" do
      image = described_class.base("python:3.12")
                             .pip_install("numpy", "pandas")

      expect(image.dockerfile).to include("RUN python -m pip install numpy pandas")
    end

    it "sorts packages" do
      image = described_class.base("python:3.12")
                             .pip_install("zlib", "aiohttp")

      expect(image.dockerfile).to include("pip install aiohttp zlib")
    end

    it "supports index_url" do
      image = described_class.base("python:3.12")
                             .pip_install("torch", index_url: "https://download.pytorch.org/whl/cpu")

      expect(image.dockerfile).to include("--index-url")
    end

    it "supports pre flag" do
      image = described_class.base("python:3.12")
                             .pip_install("mypackage", pre: true)

      expect(image.dockerfile).to include("--pre")
    end

    it "returns self for chaining" do
      image = described_class.base("python:3.12")
      result = image.pip_install("numpy")
      expect(result).to be(image)
    end
  end

  describe "#env" do
    it "adds environment variables" do
      image = described_class.base("python:3.12")
                             .env("MY_VAR" => "value", "OTHER" => "thing")

      expect(image.dockerfile).to include("ENV MY_VAR=value")
      expect(image.dockerfile).to include("ENV OTHER=thing")
    end

    it "raises for non-string values" do
      image = described_class.base("python:3.12")
      expect { image.env("NUM" => 123) }
        .to raise_error(Daytona::DaytonaError, /must be strings/)
    end
  end

  describe "#workdir" do
    it "adds WORKDIR command" do
      image = described_class.base("python:3.12")
                             .workdir("/home/user")

      expect(image.dockerfile).to include("WORKDIR /home/user")
    end
  end

  describe "#run_commands" do
    it "adds RUN commands" do
      image = described_class.base("python:3.12")
                             .run_commands("echo hello", "ls -la")

      expect(image.dockerfile).to include("RUN echo hello")
      expect(image.dockerfile).to include("RUN ls -la")
    end
  end

  describe "#entrypoint" do
    it "adds ENTRYPOINT command" do
      image = described_class.base("python:3.12")
                             .entrypoint(["/bin/bash", "-c"])

      expect(image.dockerfile).to include('ENTRYPOINT ["/bin/bash", "-c"]')
    end

    it "raises for non-array" do
      image = described_class.base("python:3.12")
      expect { image.entrypoint("/bin/bash") }
        .to raise_error(Daytona::DaytonaError)
    end
  end

  describe "#cmd" do
    it "adds CMD command" do
      image = described_class.base("python:3.12")
                             .cmd(["python", "app.py"])

      expect(image.dockerfile).to include('CMD ["python", "app.py"]')
    end
  end

  describe "chaining" do
    it "allows method chaining" do
      image = described_class.debian_slim("3.12")
                             .pip_install("flask", "gunicorn")
                             .env("PORT" => "8080")
                             .workdir("/app")
                             .run_commands("mkdir -p /app/data")
                             .cmd(["gunicorn", "app:app"])

      dockerfile = image.dockerfile
      expect(dockerfile).to include("FROM python:")
      expect(dockerfile).to include("pip install flask gunicorn")
      expect(dockerfile).to include("ENV PORT=8080")
      expect(dockerfile).to include("WORKDIR /app")
      expect(dockerfile).to include("RUN mkdir -p /app/data")
      expect(dockerfile).to include('CMD ["gunicorn", "app:app"]')
    end
  end

  describe ".from_dockerfile" do
    it "reads the Dockerfile contents" do
      Tempfile.create(["Dockerfile", ""]) do |tmp|
        tmp.write("FROM alpine:3.19\nRUN apk add curl\n")
        tmp.flush

        image = described_class.from_dockerfile(tmp.path)
        expect(image.dockerfile).to eq("FROM alpine:3.19\nRUN apk add curl\n")
      end
    end

    it "raises when the file does not exist" do
      expect { described_class.from_dockerfile("/no/such/Dockerfile") }
        .to raise_error(Daytona::DaytonaError, /not found/)
    end
  end

  describe "#pip_install extra options" do
    it "appends find_links and extra_index_url flags" do
      image = described_class.base("python:3.12")
                             .pip_install("pkg",
                                          find_links: ["https://links.example"],
                                          extra_index_urls: ["https://extra.example"],
                                          extra_options: "--no-cache-dir")

      expect(image.dockerfile).to include("--find-links https://links.example")
      expect(image.dockerfile).to include("--extra-index-url https://extra.example")
      expect(image.dockerfile).to include("--no-cache-dir")
    end

    it "is a no-op when given no packages" do
      image = described_class.base("python:3.12")
      expect(image.pip_install.dockerfile).to eq("FROM python:3.12\n")
    end
  end

  describe "#run_commands with array form" do
    # NOTE: documents current behavior. `run_commands` calls `commands.flatten`,
    # which fully flattens nested arrays, so the intended exec-form branch
    # (command.is_a?(Array)) is never reached and each token becomes its own RUN
    # line. See the SDK notes: this looks like a bug worth revisiting.
    it "currently flattens array arguments into separate RUN lines" do
      image = described_class.base("python:3.12")
                             .run_commands(["bash", "-c", "echo hi"])

      expect(image.dockerfile).to include("RUN bash\nRUN -c\nRUN echo hi\n")
    end
  end

  describe "#add_local_file" do
    it "records a context entry and emits a COPY directive" do
      Tempfile.create("local") do |tmp|
        image = described_class.base("python:3.12")
                               .add_local_file(tmp.path, "/app/config.json")

        expect(image.dockerfile).to match(%r{COPY context/\h+/.+ /app/config.json})
        expect(image.context_list.size).to eq(1)
        expect(image.context_list.first[:source_path]).to eq(File.expand_path(tmp.path))
      end
    end
  end

  describe "#dockerfile_commands" do
    it "appends raw commands" do
      image = described_class.base("python:3.12")
                             .dockerfile_commands(["EXPOSE 8080", "USER app"])

      expect(image.dockerfile).to include("EXPOSE 8080\nUSER app\n")
    end

    it "raises when the context directory is missing" do
      expect do
        described_class.base("python:3.12")
                       .dockerfile_commands(["COPY . ."], context_dir: "/no/such/dir")
      end.to raise_error(Daytona::DaytonaError, /Context directory not found/)
    end
  end

  describe "#to_h" do
    it "returns the dockerfile content and context list" do
      image = described_class.base("python:3.12")

      expect(image.to_h).to eq(
        dockerfileContent: "FROM python:3.12\n",
        contextList: []
      )
    end
  end
end
