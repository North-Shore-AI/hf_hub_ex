defmodule HfHub.Download do
  @moduledoc """
  File download functionality for HuggingFace Hub.

  Provides functions to download files from HuggingFace repositories with
  caching, resume support, and progress tracking.

  ## Examples

      # Download a single file
      {:ok, path} = HfHub.Download.hf_hub_download(
        repo_id: "bert-base-uncased",
        filename: "config.json",
        repo_type: :model
      )

      # Download entire repository snapshot
      {:ok, snapshot_path} = HfHub.Download.snapshot_download(
        repo_id: "bert-base-uncased",
        repo_type: :model
      )

      # Stream download for large files
      {:ok, stream} = HfHub.Download.download_stream(
        repo_id: "bert-base-uncased",
        filename: "pytorch_model.bin"
      )
  """

  @type download_opts :: [
          repo_id: HfHub.repo_id(),
          filename: HfHub.filename(),
          repo_type: HfHub.repo_type(),
          revision: HfHub.revision(),
          cache_dir: Path.t(),
          force_download: boolean(),
          extract: boolean(),
          extract_dir: Path.t(),
          token: String.t() | nil
        ]

  @doc """
  Downloads a file from a HuggingFace repository.

  Returns the local path to the cached file.

  ## Options

    * `:repo_id` - Repository ID (e.g., "bert-base-uncased")
    * `:filename` - Name of the file to download
    * `:repo_type` - Type of repository (`:model`, `:dataset`, or `:space`). Defaults to `:model`.
    * `:revision` - Git revision. Defaults to `"main"`.
    * `:cache_dir` - Local cache directory. Defaults to configured cache directory.
    * `:force_download` - Force re-download even if cached. Defaults to `false`.
    * `:extract` - Extract archives after download. Defaults to `false`.
    * `:extract_dir` - Destination for extracted files (directory for archives, file path for .gz).
    * `:token` - Authentication token.

  ## Examples

      {:ok, path} = HfHub.Download.hf_hub_download(
        repo_id: "bert-base-uncased",
        filename: "config.json"
      )

      {:ok, path} = HfHub.Download.hf_hub_download(
        repo_id: "squad",
        filename: "train.json",
        repo_type: :dataset,
        revision: "main"
      )
  """
  @spec hf_hub_download(download_opts()) :: {:ok, Path.t()} | {:error, term()}
  def hf_hub_download(opts) do
    repo_id = Keyword.fetch!(opts, :repo_id)
    filename = Keyword.fetch!(opts, :filename)
    repo_type = Keyword.get(opts, :repo_type, :model)
    revision = Keyword.get(opts, :revision, "main")
    force_download = Keyword.get(opts, :force_download, false)
    token = Keyword.get(opts, :token)

    # Check if file is already cached
    cache_path = HfHub.FS.file_path(repo_id, repo_type, filename, revision)

    result =
      if File.exists?(cache_path) and not force_download do
        {:ok, cache_path}
      else
        # Download the file
        url = build_download_url(repo_id, repo_type, filename, revision)
        do_download_file(url, cache_path, token)
      end

    with {:ok, path} <- result do
      maybe_extract(path, opts)
    end
  end

  defp do_download_file(url, cache_path, token) do
    with :ok <- HfHub.FS.ensure_cache_dir(),
         :ok <- File.mkdir_p(Path.dirname(cache_path)),
         {:ok, lock_ref} <- HfHub.FS.lock_file(cache_path, Path.basename(cache_path)),
         :ok <- HfHub.HTTP.download_file(url, cache_path, token: token) do
      HfHub.FS.unlock_file(lock_ref)
      {:ok, cache_path}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_download_url(repo_id, repo_type, filename, revision) do
    endpoint = HfHub.Config.endpoint()
    # Models use bare repo_id, datasets/spaces need a prefix
    repo_path = repo_type_prefix(repo_type) <> repo_id
    "#{endpoint}/#{repo_path}/resolve/#{revision}/#{filename}"
  end

  defp repo_type_prefix(:model), do: ""
  defp repo_type_prefix(:dataset), do: "datasets/"
  defp repo_type_prefix(:space), do: "spaces/"

  @doc """
  Downloads an entire repository snapshot.

  Returns the local path to the snapshot directory.

  ## Options

    * `:repo_id` - Repository ID
    * `:repo_type` - Type of repository. Defaults to `:model`.
    * `:revision` - Git revision. Defaults to `"main"`.
    * `:cache_dir` - Local cache directory.
    * `:ignore_patterns` - List of glob patterns to ignore
    * `:allow_patterns` - List of glob patterns to allow
    * `:token` - Authentication token.

  ## Examples

      {:ok, snapshot_path} = HfHub.Download.snapshot_download(
        repo_id: "bert-base-uncased"
      )

      {:ok, snapshot_path} = HfHub.Download.snapshot_download(
        repo_id: "bert-base-uncased",
        ignore_patterns: ["*.msgpack", "*.h5"]
      )
  """
  @spec snapshot_download(keyword()) :: {:ok, Path.t()} | {:error, term()}
  def snapshot_download(opts) do
    repo_id = Keyword.fetch!(opts, :repo_id)
    repo_type = Keyword.get(opts, :repo_type, :model)
    revision = Keyword.get(opts, :revision, "main")
    token = Keyword.get(opts, :token)
    ignore_patterns = Keyword.get(opts, :ignore_patterns, [])
    allow_patterns = Keyword.get(opts, :allow_patterns, [])

    snapshot_path = HfHub.FS.repo_path(repo_id, repo_type)

    with {:ok, files} <-
           HfHub.Api.list_files(repo_id, repo_type: repo_type, revision: revision, token: token),
         filtered_files <- filter_files(files, ignore_patterns, allow_patterns),
         :ok <- download_all_files(repo_id, repo_type, revision, filtered_files, token) do
      {:ok, Path.join(snapshot_path, "snapshots/#{revision}")}
    end
  end

  defp filter_files(files, ignore_patterns, allow_patterns) do
    files
    |> Enum.map(& &1.rfilename)
    |> reject_ignored(ignore_patterns)
    |> filter_allowed(allow_patterns)
  end

  defp reject_ignored(filenames, patterns) do
    Enum.reject(filenames, &matches_any_pattern?(&1, patterns))
  end

  defp filter_allowed(filenames, []), do: filenames

  defp filter_allowed(filenames, patterns) do
    Enum.filter(filenames, &matches_any_pattern?(&1, patterns))
  end

  defp matches_any_pattern?(filename, patterns) do
    Enum.any?(patterns, &matches_glob?(filename, &1))
  end

  defp matches_glob?(filename, pattern) do
    # Simple glob matching for *, **, and ?
    regex_pattern =
      pattern
      |> String.replace(".", "\\.")
      |> String.replace("**", "<<<DOUBLESTAR>>>")
      |> String.replace("*", "[^/]*")
      |> String.replace("<<<DOUBLESTAR>>>", ".*")
      |> String.replace("?", ".")

    Regex.match?(~r/^#{regex_pattern}$/, filename)
  end

  defp download_all_files(repo_id, repo_type, revision, filenames, token) do
    results =
      filenames
      |> Task.async_stream(
        fn filename ->
          hf_hub_download(
            repo_id: repo_id,
            filename: filename,
            repo_type: repo_type,
            revision: revision,
            token: token
          )
        end,
        max_concurrency: 4,
        timeout: :infinity
      )
      |> Enum.to_list()

    errors =
      results
      |> Enum.filter(fn
        {:ok, {:error, _}} -> true
        {:exit, _} -> true
        _ -> false
      end)

    if errors == [] do
      :ok
    else
      {:error, {:download_failed, errors}}
    end
  end

  @doc """
  Creates a stream for downloading a file.

  Useful for large files where you want to process the data as it downloads.

  ## Options

    * `:repo_id` - Repository ID
    * `:filename` - Name of the file to download
    * `:repo_type` - Type of repository. Defaults to `:model`.
    * `:revision` - Git revision. Defaults to `"main"`.
    * `:token` - Authentication token.

  ## Examples

      {:ok, stream} = HfHub.Download.download_stream(
        repo_id: "bert-base-uncased",
        filename: "pytorch_model.bin"
      )

      stream
      |> Stream.each(fn chunk -> IO.write(chunk) end)
      |> Stream.run()
  """
  @spec download_stream(keyword()) :: {:ok, Enumerable.t()} | {:error, term()}
  def download_stream(opts) do
    repo_id = Keyword.fetch!(opts, :repo_id)
    filename = Keyword.fetch!(opts, :filename)
    repo_type = Keyword.get(opts, :repo_type, :model)
    revision = Keyword.get(opts, :revision, "main")
    token = Keyword.get(opts, :token)

    url = build_download_url(repo_id, repo_type, filename, revision)
    headers = build_stream_headers(token)

    stream =
      Stream.resource(
        fn -> start_stream(url, headers) end,
        &next_chunk/1,
        &close_stream/1
      )

    {:ok, stream}
  end

  defp build_stream_headers(token) do
    base = [{"user-agent", "hf_hub_ex/0.1.1"}]

    case token || get_token() do
      nil -> base
      t -> [{"authorization", "Bearer #{t}"} | base]
    end
  end

  defp maybe_extract(path, opts) do
    if Keyword.get(opts, :extract, false) do
      case HfHub.Extract.detect_archive_type(path) do
        nil ->
          {:ok, path}

        _type ->
          dest = extract_destination(path, opts)

          if File.exists?(dest) do
            {:ok, dest}
          else
            HfHub.Extract.extract(path, dest)
          end
      end
    else
      {:ok, path}
    end
  end

  defp extract_destination(path, opts) do
    case Keyword.get(opts, :extract_dir) do
      nil -> HfHub.Extract.default_extract_path(path)
      dir -> dir
    end
  end

  defp get_token do
    case HfHub.Auth.get_token() do
      {:ok, t} -> t
      _ -> nil
    end
  end

  defp start_stream(url, headers) do
    case Req.get(url, headers: headers, into: :self) do
      {:ok, %Req.Response{status: status} = resp} when status in [200, 206] ->
        {:streaming, resp}

      {:ok, %Req.Response{status: 404}} ->
        {:error, :not_found}

      {:ok, %Req.Response{status: 401}} ->
        {:error, :unauthorized}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp next_chunk({:error, reason}) do
    {:halt, {:error, reason}}
  end

  defp next_chunk({:streaming, resp}) do
    case get_async_ref(resp) do
      nil ->
        # Response body is already available (not async)
        case resp.body do
          body when is_binary(body) ->
            {[body], {:done_sync, resp}}

          %Req.Response.Async{} = async ->
            do_async_chunk(async.ref, resp)

          _ ->
            {:halt, :done}
        end

      ref ->
        do_async_chunk(ref, resp)
    end
  end

  defp next_chunk({:done_sync, _resp}) do
    {:halt, :done}
  end

  defp get_async_ref(resp) do
    case Map.get(resp, :async) do
      %{ref: ref} -> ref
      _ -> nil
    end
  end

  defp do_async_chunk(ref, resp) do
    receive do
      {^ref, {:data, chunk}} ->
        {[chunk], {:streaming, resp}}

      {^ref, :done} ->
        {:halt, :done}

      {^ref, {:error, reason}} ->
        {:halt, {:error, reason}}
    after
      30_000 ->
        {:halt, {:error, :timeout}}
    end
  end

  defp close_stream(:done), do: :ok
  defp close_stream({:error, _}), do: :ok
  defp close_stream({:done_sync, _}), do: :ok

  defp close_stream({:streaming, resp}) do
    case Map.get(resp, :async) do
      nil ->
        :ok

      async ->
        ref = async.ref
        Req.cancel_async_response(resp)
        # Flush any remaining messages
        receive do
          {^ref, _} -> :ok
        after
          0 -> :ok
        end
    end
  end

  @doc """
  Resumes an interrupted download.

  ## Options

    * `:repo_id` - Repository ID
    * `:filename` - Name of the file to download
    * `:repo_type` - Type of repository. Defaults to `:model`.
    * `:revision` - Git revision. Defaults to `"main"`.
    * `:token` - Authentication token.

  ## Examples

      {:ok, path} = HfHub.Download.resume_download(
        repo_id: "bert-base-uncased",
        filename: "pytorch_model.bin"
      )
  """
  @spec resume_download(keyword()) :: {:ok, Path.t()} | {:error, term()}
  def resume_download(opts) do
    repo_id = Keyword.fetch!(opts, :repo_id)
    filename = Keyword.fetch!(opts, :filename)
    repo_type = Keyword.get(opts, :repo_type, :model)
    revision = Keyword.get(opts, :revision, "main")
    token = Keyword.get(opts, :token)

    cache_path = HfHub.FS.file_path(repo_id, repo_type, filename, revision)

    case File.stat(cache_path) do
      {:ok, %File.Stat{size: existing_size}} when existing_size > 0 ->
        # Resume from existing file
        url = build_download_url(repo_id, repo_type, filename, revision)
        do_resume_download(url, cache_path, existing_size, token)

      {:ok, %File.Stat{size: 0}} ->
        # Empty file, start fresh
        hf_hub_download(opts)

      {:error, :enoent} ->
        # No existing file, start fresh
        hf_hub_download(opts)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_resume_download(url, cache_path, existing_size, token) do
    headers = build_stream_headers(token)
    range_header = {"range", "bytes=#{existing_size}-"}
    headers = [range_header | headers]

    with :ok <- HfHub.FS.ensure_cache_dir(),
         :ok <- File.mkdir_p(Path.dirname(cache_path)),
         {:ok, result} <- do_append_download(url, headers, cache_path) do
      {:ok, result}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp do_append_download(url, headers, cache_path) do
    case Req.get(url, headers: headers) do
      {:ok, %Req.Response{status: 206, body: body}} ->
        File.write!(cache_path, body, [:append, :binary])
        {:ok, :resumed}

      {:ok, %Req.Response{status: 200, body: _body}} ->
        # Server doesn't support range requests, file is complete
        {:ok, :complete}

      {:ok, %Req.Response{status: 416}} ->
        # Range not satisfiable - file is already complete
        {:ok, :complete}

      {:ok, %Req.Response{status: 404}} ->
        {:error, :not_found}

      {:ok, %Req.Response{status: 401}} ->
        {:error, :unauthorized}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
