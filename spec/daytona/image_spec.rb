# frozen_string_literal: true

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
end
