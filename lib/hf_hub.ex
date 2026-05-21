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

  Per Elixir runtime-configuration best practices, this library reads only
  from `Application.get_env(:hf_hub, ...)`. No OS environment variables
  are read by library code. Hosts that want the historical env-var
  shortcuts should wire them in `config/runtime.exs`:

      # config/runtime.exs
      import Config

      if token = System.get_env("HF_TOKEN") do
        config :hf_hub, token: token
      end

      cond do
        dir = System.get_env("HF_HUB_CACHE") ->
          config :hf_hub, cache_dir: dir

        dir = System.get_env("HF_HOME") ->
          config :hf_hub, cache_dir: Path.join(dir, "hub")

        true ->
          :ok
      end

      if System.get_env("HF_HUB_OFFLINE") in ~w(1 true) do
        config :hf_hub, offline: true
      end

  Compile-time configuration also works for static values:

      # config/config.exs
      config :hf_hub,
        endpoint: "https://huggingface.co",
        cache_dir: Path.expand("~/.cache/huggingface")

  ## Modules

  - `HfHub.Api` — Hub API client (models, datasets, spaces)
  - `HfHub.Download` — File download with caching
  - `HfHub.Cache` — Cache management and statistics
  - `HfHub.FS` — Filesystem utilities for cache
  - `HfHub.Auth` — Authentication and authorization
  - `HfHub.Hub` — Bumblebee-compatible ETag-based caching
  - `HfHub.Repository` — Repository reference types
  - `HfHub.RepoFiles` — Repository file listing with ETags
  """

  @type repo_type :: :model | :dataset | :space
  @type repo_id :: String.t()
  @type filename :: String.t()
  @type revision :: String.t()

  @typedoc """
  A repository reference (Bumblebee-compatible).

  Can be either:
    * `{:hf, repository_id}` - HuggingFace repository
    * `{:hf, repository_id, opts}` - HuggingFace repository with options
    * `{:local, directory}` - Local directory
  """
  @type repository :: HfHub.Repository.t()

  # Delegates for Bumblebee-compatible API
  defdelegate get_repo_files(repository), to: HfHub.RepoFiles
  defdelegate cached_download(url, opts \\ []), to: HfHub.Hub
  defdelegate file_url(repository_id, filename, revision), to: HfHub.Hub
  defdelegate file_listing_url(repository_id, subdir, revision), to: HfHub.Hub

  @doc """
  Check if offline mode is enabled.

  Offline mode is read from `Application.get_env(:hf_hub, :offline, false)`.
  Hosts wire `HF_HUB_OFFLINE` into that key from `config/runtime.exs` per
  the `## Configuration` section above. Library code no longer reads the
  environment directly.

  When offline mode is enabled, no network requests are made and only
  cached files are used.

  ## Examples

      if HfHub.offline_mode?() do
        IO.puts("Running in offline mode")
      end
  """
  @spec offline_mode?() :: boolean()
  def offline_mode? do
    Application.get_env(:hf_hub, :offline, false) == true
  end

  @doc """
  Alias for `offline_mode?/0` for Python compatibility.

  Deprecated: Use `offline_mode?/0` instead.
  """
  @deprecated "Use offline_mode?/0 instead"
  @spec is_offline_mode() :: boolean()
  # credo:disable-for-next-line Credo.Check.Readability.PredicateFunctionNames
  def is_offline_mode, do: offline_mode?()

  @doc """
  Try to load a file from cache without network access.

  Returns `{:ok, path}` if the file exists in cache, `{:error, :not_cached}` otherwise.
  Does not attempt any network requests, even if offline mode is not enabled.

  This is useful when you want to check if a file is available locally
  before deciding whether to download it.

  ## Arguments

    * `repo_id` - Repository ID (e.g., "bert-base-uncased")
    * `filename` - Name of the file to look up
    * `opts` - Options

  ## Options

    * `:revision` - Git revision. Defaults to `"main"`.
    * `:repo_type` - Type of repository (`:model`, `:dataset`, or `:space`). Defaults to `:model`.

  ## Examples

      case HfHub.try_to_load_from_cache("bert-base-uncased", "config.json") do
        {:ok, path} ->
          # File is cached, use it
          File.read!(path)
        {:error, :not_cached} ->
          # File not cached, need to download
          {:ok, path} = HfHub.Download.hf_hub_download(
            repo_id: "bert-base-uncased",
            filename: "config.json"
          )
          File.read!(path)
      end
  """
  @spec try_to_load_from_cache(repo_id(), filename(), keyword()) ::
          {:ok, Path.t()} | {:error, :not_cached}
  def try_to_load_from_cache(repo_id, filename, opts \\ []) do
    revision = Keyword.get(opts, :revision, "main")
    repo_type = Keyword.get(opts, :repo_type, :model)

    path = HfHub.FS.file_path(repo_id, repo_type, filename, revision)

    if File.exists?(path) do
      {:ok, path}
    else
      {:error, :not_cached}
    end
  end
end
