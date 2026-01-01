defmodule HfHub.Hub do
  @moduledoc """
  Bumblebee-compatible Hub interface for HuggingFace.

  Provides ETag-based caching compatible with Bumblebee's `Bumblebee.HuggingFace.Hub`.
  This module uses URL-based caching with ETag validation, while the existing
  `HfHub.Download` module uses revision-based path caching.

  ## Examples

      # Download with ETag-based caching
      {:ok, path} = HfHub.Hub.cached_download(
        "https://huggingface.co/bert-base-uncased/resolve/main/config.json"
      )

      # With options
      {:ok, path} = HfHub.Hub.cached_download(url,
        cache_dir: "/custom/cache",
        auth_token: "hf_xxx",
        offline: true
      )
  """

  alias HfHub.HTTP

  @doc """
  Returns a URL pointing to a file in a HuggingFace repository.

  ## Examples

      iex> HfHub.Hub.file_url("bert-base-uncased", "config.json", nil)
      "https://huggingface.co/bert-base-uncased/resolve/main/config.json"

      iex> HfHub.Hub.file_url("bert-base-uncased", "config.json", "v1.0")
      "https://huggingface.co/bert-base-uncased/resolve/v1.0/config.json"
  """
  @spec file_url(String.t(), String.t(), String.t() | nil) :: String.t()
  def file_url(repository_id, filename, revision) do
    revision = revision || "main"
    endpoint = HfHub.Config.endpoint()
    "#{endpoint}/#{repository_id}/resolve/#{revision}/#{filename}"
  end

  @doc """
  Returns a URL to list the contents of a HuggingFace repository.

  ## Examples

      iex> HfHub.Hub.file_listing_url("bert-base-uncased", nil, nil)
      "https://huggingface.co/api/models/bert-base-uncased/tree/main"

      iex> HfHub.Hub.file_listing_url("bert-base-uncased", "tokenizer", "v1.0")
      "https://huggingface.co/api/models/bert-base-uncased/tree/v1.0/tokenizer"
  """
  @spec file_listing_url(String.t(), String.t() | nil, String.t() | nil) :: String.t()
  def file_listing_url(repository_id, subdir, revision) do
    revision = revision || "main"
    endpoint = HfHub.Config.endpoint()
    path = if subdir, do: "/" <> subdir, else: ""
    "#{endpoint}/api/models/#{repository_id}/tree/#{revision}#{path}"
  end

  @doc """
  Downloads a file from a URL with ETag-based caching.

  The file is cached based on the received ETag. Subsequent requests
  for the same URL validate the ETag and return a file from the cache
  if there is a match.

  ## Options

    * `:cache_dir` - Override the default cache directory
    * `:offline` - If `true`, only return cached files (no network requests)
    * `:auth_token` - Authentication token for private repositories
    * `:etag` - If known, skip the HEAD request to fetch ETag
    * `:cache_scope` - Namespace for organizing cached files

  ## Examples

      {:ok, path} = HfHub.Hub.cached_download(
        "https://huggingface.co/bert-base-uncased/resolve/main/config.json"
      )
  """
  @spec cached_download(String.t(), keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def cached_download(url, opts \\ []) do
    cache_dir = opts[:cache_dir] || HfHub.FS.cache_dir()
    offline = Keyword.get(opts, :offline, offline?())
    auth_token = opts[:auth_token]

    dir = Path.join(cache_dir, "huggingface")

    dir =
      if cache_scope = opts[:cache_scope] do
        Path.join(dir, cache_scope)
      else
        dir
      end

    File.mkdir_p!(dir)

    headers = build_headers(auth_token)
    metadata_path = Path.join(dir, metadata_filename(url))

    cond do
      offline ->
        fetch_offline(dir, url, metadata_path)

      entry_path = opts[:etag] && cached_path_for_etag(dir, url, opts[:etag]) ->
        {:ok, entry_path}

      true ->
        fetch_and_cache(url, headers, dir, metadata_path)
    end
  end

  defp fetch_offline(dir, url, metadata_path) do
    case load_json(metadata_path) do
      {:ok, %{"etag" => etag}} ->
        {:ok, Path.join(dir, entry_filename(url, etag))}

      _ ->
        {:error, "could not find file in local cache and outgoing traffic is disabled, url: #{url}"}
    end
  end

  defp fetch_and_cache(url, headers, dir, metadata_path) do
    with {:ok, etag, download_url, redirect?} <- head_download(url, headers) do
      case cached_path_for_etag(dir, url, etag) do
        nil -> download_and_store(download_url, url, etag, headers, redirect?, dir, metadata_path)
        entry_path -> {:ok, entry_path}
      end
    end
  end

  defp download_and_store(download_url, url, etag, headers, redirect?, dir, metadata_path) do
    entry_path = Path.join(dir, entry_filename(url, etag))
    download_headers = if redirect?, do: List.keydelete(headers, "Authorization", 0), else: headers

    case HTTP.download_file(download_url, entry_path, headers: download_headers) do
      :ok ->
        :ok = store_json(metadata_path, %{"etag" => etag, "url" => url})
        {:ok, entry_path}

      {:error, reason} ->
        File.rm_rf!(metadata_path)
        File.rm_rf!(entry_path)
        {:error, "download failed: #{inspect(reason)}"}
    end
  end

  defp cached_path_for_etag(dir, url, etag) do
    metadata_path = Path.join(dir, metadata_filename(url))

    case load_json(metadata_path) do
      {:ok, %{"etag" => ^etag}} ->
        path = Path.join(dir, entry_filename(url, etag))

        if File.exists?(path) do
          path
        end

      _ ->
        nil
    end
  end

  defp head_download(url, headers) do
    case HTTP.head(url, headers: headers, follow_redirects: false) do
      {:ok, %{status: status} = response} when status in 300..399 ->
        location = get_header(response, "location")

        if URI.parse(location).host == nil do
          # Follow relative redirects
          url =
            url
            |> URI.parse()
            |> Map.replace!(:path, location)
            |> URI.to_string()

          head_download(url, headers)
        else
          with {:ok, etag} <- fetch_etag(response), do: {:ok, etag, location, true}
        end

      {:ok, %{status: status} = response} when status in 100..399 ->
        with {:ok, etag} <- fetch_etag(response), do: {:ok, etag, url, false}

      {:ok, response} ->
        finish_request_error(response, url)

      {:error, reason} ->
        {:error, "failed to make an HTTP request, reason: #{inspect(reason)}"}
    end
  end

  defp finish_request_error(response, url) do
    case get_header(response, "x-error-code") do
      code when code == "RepoNotFound" or response.status == 401 ->
        {:error,
         "repository not found, url: #{url}. Please make sure you specified" <>
           " the correct repository id. If you are trying to access a private" <>
           " or gated repository, use an authentication token"}

      "EntryNotFound" ->
        {:error, "file not found, url: #{url}"}

      "RevisionNotFound" ->
        {:error, "revision not found, url: #{url}"}

      "GatedRepo" ->
        {:error,
         "cannot access gated repository, url: #{url}. Make sure to request access" <>
           " for the repository and use an authentication token"}

      _ ->
        {:error, "HTTP request failed with status #{response.status}, url: #{url}"}
    end
  end

  defp fetch_etag(response) do
    etag = get_header(response, "x-linked-etag") || get_header(response, "etag")

    case etag do
      nil -> {:error, "no ETag found on the resource"}
      value -> {:ok, value}
    end
  end

  defp get_header(%{headers: headers}, key) do
    key = String.downcase(key)

    Enum.find_value(headers, fn {k, v} ->
      if String.downcase(k) == key, do: v
    end)
  end

  defp build_headers(auth_token) do
    version = Application.spec(:hf_hub, :vsn) || "0.0.0"
    base = [{"user-agent", "hf_hub_ex/#{version}"}]

    if auth_token do
      [{"authorization", "Bearer " <> auth_token} | base]
    else
      base
    end
  end

  defp metadata_filename(url) do
    encode_url(url) <> ".json"
  end

  defp entry_filename(url, etag) do
    encode_url(url) <> "." <> encode_etag(etag)
  end

  defp encode_url(url) do
    url |> :erlang.md5() |> Base.encode32(case: :lower, padding: false)
  end

  defp encode_etag(etag) do
    Base.encode32(etag, case: :lower, padding: false)
  end

  defp load_json(path) do
    case File.read(path) do
      {:ok, content} -> {:ok, Jason.decode!(content)}
      _error -> :error
    end
  end

  defp store_json(path, data) do
    json = Jason.encode!(data)
    File.write(path, json)
  end

  defp offline? do
    System.get_env("HF_HUB_OFFLINE") in ~w(1 true)
  end
end
