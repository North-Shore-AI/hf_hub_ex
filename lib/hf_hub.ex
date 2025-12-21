defmodule HfHub do
  @moduledoc """
  Elixir client for HuggingFace Hub.

  `HfHub` provides a comprehensive interface to the HuggingFace Hub API,
  enabling Elixir applications to access models, datasets, and spaces.

  ## Features

  - **Hub API Client** — Fetch metadata for models, datasets, and spaces
  - **File Downloads** — Stream files from HuggingFace repositories with resume support
  - **Smart Caching** — Local file caching with LRU eviction and integrity checks
  - **Filesystem Utilities** — Manage local HuggingFace cache directory structure
  - **Authentication** — Token-based authentication for private repositories

  ## Quick Start

      # Get model information
      {:ok, model_info} = HfHub.Api.model_info("bert-base-uncased")

      # Download a model file
      {:ok, path} = HfHub.Download.hf_hub_download(
        repo_id: "bert-base-uncased",
        filename: "config.json",
        repo_type: :model
      )

      # Check cache
      cached? = HfHub.Cache.cached?(
        repo_id: "bert-base-uncased",
        filename: "config.json"
      )

  ## Configuration

  Configure in `config/config.exs`:

      config :hf_hub,
        token: System.get_env("HF_TOKEN"),
        cache_dir: Path.expand("~/.cache/huggingface"),
        endpoint: "https://huggingface.co"

  ## Modules

  - `HfHub.Api` — Hub API client (models, datasets, spaces)
  - `HfHub.Download` — File download with caching
  - `HfHub.Cache` — Cache management and statistics
  - `HfHub.FS` — Filesystem utilities for cache
  - `HfHub.Auth` — Authentication and authorization
  """

  @type repo_type :: :model | :dataset | :space
  @type repo_id :: String.t()
  @type filename :: String.t()
  @type revision :: String.t()
end
