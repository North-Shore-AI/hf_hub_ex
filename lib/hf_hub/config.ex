defmodule HfHub.Config do
  @moduledoc """
  Configuration utilities for HfHub.

  Provides functions to access and manage configuration settings.
  """

  @doc """
  Gets the HuggingFace Hub endpoint URL.

  Defaults to "https://huggingface.co".

  ## Examples

      endpoint = HfHub.Config.endpoint()
      # => "https://huggingface.co"
  """
  @spec endpoint() :: String.t()
  def endpoint do
    Application.get_env(:hf_hub, :endpoint, "https://huggingface.co")
  end

  @doc """
  Gets the cache directory path.

  Defaults to "~/.cache/huggingface".

  ## Examples

      cache_dir = HfHub.Config.cache_dir()
      # => "/home/user/.cache/huggingface"
  """
  @spec cache_dir() :: Path.t()
  def cache_dir do
    Application.get_env(:hf_hub, :cache_dir, default_cache_dir())
  end

  @doc """
  Gets HTTP client options.

  ## Examples

      opts = HfHub.Config.http_opts()
  """
  @spec http_opts() :: keyword()
  def http_opts do
    Application.get_env(:hf_hub, :http_opts, default_http_opts())
  end

  @doc """
  Gets cache options.

  ## Examples

      opts = HfHub.Config.cache_opts()
  """
  @spec cache_opts() :: keyword()
  def cache_opts do
    Application.get_env(:hf_hub, :cache_opts, default_cache_opts())
  end

  defp default_cache_dir do
    Path.expand("~/.cache/huggingface")
  end

  defp default_http_opts do
    [
      receive_timeout: 30_000,
      pool_timeout: 5_000
    ]
  end

  defp default_cache_opts do
    [
      # 10 GB
      max_size: 10 * 1024 * 1024 * 1024,
      eviction_policy: :lru
    ]
  end
end
