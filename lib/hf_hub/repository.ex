defmodule HfHub.Repository do
  @moduledoc """
  Repository reference types and helpers for HuggingFace Hub.

  Provides Bumblebee-compatible repository tuple types alongside
  the existing keyword-based API.

  ## Repository Types

  A repository can be referenced as:

    * `{:hf, repository_id}` - HuggingFace Hub repository
    * `{:hf, repository_id, opts}` - HuggingFace Hub repository with options
    * `{:local, directory}` - Local directory containing model files

  ## Options for `:hf` repositories

    * `:revision` - Git revision (branch, tag, or commit). Defaults to `"main"`.
    * `:cache_dir` - Override the cache directory
    * `:offline` - If `true`, only use cached files
    * `:auth_token` - Authentication token for private repos
    * `:subdir` - Subdirectory within the repository

  ## Examples

      # Simple HuggingFace repository
      {:hf, "bert-base-uncased"}

      # With options
      {:hf, "bert-base-uncased", revision: "v1.0", auth_token: "hf_xxx"}

      # Local directory
      {:local, "/path/to/model"}
  """

  @type t ::
          {:hf, String.t()}
          | {:hf, String.t(), keyword()}
          | {:local, Path.t()}

  @type opts :: [
          revision: String.t(),
          cache_dir: Path.t(),
          offline: boolean(),
          auth_token: String.t(),
          subdir: String.t()
        ]

  @doc """
  Normalizes a repository reference to its canonical form.

  Converts `{:hf, id}` to `{:hf, id, []}` for consistent handling.

  ## Examples

      iex> HfHub.Repository.normalize!({:hf, "bert-base-uncased"})
      {:hf, "bert-base-uncased", []}

      iex> HfHub.Repository.normalize!({:hf, "bert-base-uncased", revision: "v1.0"})
      {:hf, "bert-base-uncased", [revision: "v1.0"]}

      iex> HfHub.Repository.normalize!({:local, "/path/to/model"})
      {:local, "/path/to/model"}
  """
  @spec normalize!(t()) :: {:hf, String.t(), keyword()} | {:local, Path.t()}
  def normalize!({:hf, repository_id}) when is_binary(repository_id) do
    {:hf, repository_id, []}
  end

  def normalize!({:hf, repository_id, opts}) when is_binary(repository_id) do
    opts =
      Keyword.validate!(opts, [:revision, :cache_dir, :offline, :auth_token, :subdir])

    {:hf, repository_id, opts}
  end

  def normalize!({:local, dir}) when is_binary(dir) do
    {:local, dir}
  end

  def normalize!(other) do
    raise ArgumentError,
          "expected repository to be either {:hf, repository_id}, {:hf, repository_id, options}" <>
            " or {:local, directory}, got: #{inspect(other)}"
  end

  @doc """
  Returns a URL pointing to a file in a HuggingFace repository.

  ## Examples

      iex> HfHub.Repository.file_url({:hf, "bert-base-uncased", []}, "config.json")
      "https://huggingface.co/bert-base-uncased/resolve/main/config.json"

      iex> HfHub.Repository.file_url({:hf, "bert-base-uncased", revision: "v1.0"}, "config.json")
      "https://huggingface.co/bert-base-uncased/resolve/v1.0/config.json"
  """
  @spec file_url({:hf, String.t(), keyword()}, String.t()) :: String.t()
  def file_url({:hf, repository_id, opts}, filename) do
    revision = Keyword.get(opts, :revision, "main")
    endpoint = HfHub.Config.endpoint()

    filename =
      if subdir = opts[:subdir] do
        subdir <> "/" <> filename
      else
        filename
      end

    "#{endpoint}/#{repository_id}/resolve/#{revision}/#{filename}"
  end

  @doc """
  Returns a URL to list the contents of a HuggingFace repository.

  ## Examples

      iex> HfHub.Repository.file_listing_url({:hf, "bert-base-uncased", []})
      "https://huggingface.co/api/models/bert-base-uncased/tree/main"
  """
  @spec file_listing_url({:hf, String.t(), keyword()}) :: String.t()
  def file_listing_url({:hf, repository_id, opts}) do
    revision = Keyword.get(opts, :revision, "main")
    subdir = Keyword.get(opts, :subdir)
    endpoint = HfHub.Config.endpoint()
    path = if subdir, do: "/" <> subdir, else: ""
    "#{endpoint}/api/models/#{repository_id}/tree/#{revision}#{path}"
  end

  @doc """
  Converts a repository ID to a cache scope string.

  Used for organizing cached files by repository.

  ## Examples

      iex> HfHub.Repository.cache_scope("openai/gpt-2")
      "openai--gpt-2"
  """
  @spec cache_scope(String.t()) :: String.t()
  def cache_scope(repository_id) do
    repository_id
    |> String.replace("/", "--")
    |> String.replace(~r/[^\w-]/, "")
  end
end
