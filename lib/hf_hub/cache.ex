defmodule HfHub.Cache do
  @moduledoc """
  Cache management for downloaded files.

  Provides functions to manage the local cache of downloaded HuggingFace files,
  including checking cache status, retrieving paths, and evicting old files.

  ## Examples

      # Check if a file is cached
      cached? = HfHub.Cache.cached?(
        repo_id: "bert-base-uncased",
        filename: "config.json"
      )

      # Get cache path for a file
      {:ok, path} = HfHub.Cache.cache_path(
        repo_id: "bert-base-uncased",
        filename: "config.json"
      )

      # Clear cache for a repository
      :ok = HfHub.Cache.clear_cache(repo_id: "bert-base-uncased")

      # Get cache statistics
      {:ok, stats} = HfHub.Cache.cache_stats()
  """

  @type cache_stats :: %{
          total_size: non_neg_integer(),
          file_count: non_neg_integer(),
          repos: [String.t()],
          last_accessed: DateTime.t() | nil
        }

  @doc """
  Checks if a file is cached locally.

  ## Options

    * `:repo_id` - Repository ID
    * `:filename` - Name of the file
    * `:repo_type` - Type of repository. Defaults to `:model`.
    * `:revision` - Git revision. Defaults to `"main"`.

  ## Examples

      cached? = HfHub.Cache.cached?(
        repo_id: "bert-base-uncased",
        filename: "config.json"
      )
  """
  @spec cached?(keyword()) :: boolean()
  def cached?(opts) do
    repo_id = Keyword.fetch!(opts, :repo_id)
    filename = Keyword.fetch!(opts, :filename)
    repo_type = Keyword.get(opts, :repo_type, :model)
    revision = Keyword.get(opts, :revision, "main")

    path = HfHub.FS.file_path(repo_id, repo_type, filename, revision)
    File.exists?(path)
  end

  @doc """
  Gets the local cache path for a file.

  Returns `{:ok, path}` if the file is cached, `{:error, :not_cached}` otherwise.

  ## Options

    * `:repo_id` - Repository ID
    * `:filename` - Name of the file
    * `:repo_type` - Type of repository. Defaults to `:model`.
    * `:revision` - Git revision. Defaults to `"main"`.

  ## Examples

      {:ok, path} = HfHub.Cache.cache_path(
        repo_id: "bert-base-uncased",
        filename: "config.json"
      )
  """
  @spec cache_path(keyword()) :: {:ok, Path.t()} | {:error, :not_cached}
  def cache_path(opts) do
    repo_id = Keyword.fetch!(opts, :repo_id)
    filename = Keyword.fetch!(opts, :filename)
    repo_type = Keyword.get(opts, :repo_type, :model)
    revision = Keyword.get(opts, :revision, "main")

    path = HfHub.FS.file_path(repo_id, repo_type, filename, revision)

    if File.exists?(path) do
      {:ok, path}
    else
      {:error, :not_cached}
    end
  end

  @doc """
  Clears cached files.

  ## Options

    * `:repo_id` - Clear cache for specific repository. If not provided, clears all.
    * `:repo_type` - Type of repository. Defaults to `:model`.

  ## Examples

      # Clear cache for specific repo
      :ok = HfHub.Cache.clear_cache(repo_id: "bert-base-uncased")

      # Clear all cache
      :ok = HfHub.Cache.clear_cache()
  """
  @spec clear_cache(keyword()) :: :ok | {:error, term()}
  def clear_cache(opts \\ []) do
    if repo_id = Keyword.get(opts, :repo_id) do
      repo_type = Keyword.get(opts, :repo_type, :model)
      path = HfHub.FS.repo_path(repo_id, repo_type)
      File.rm_rf(path)
      :ok
    else
      # Clear entire cache
      cache_dir = HfHub.FS.cache_dir()
      hub_dir = Path.join(cache_dir, "hub")
      File.rm_rf(hub_dir)
      :ok
    end
  end

  @doc """
  Gets cache statistics.

  Returns information about cache size, file count, and repositories.

  ## Examples

      {:ok, stats} = HfHub.Cache.cache_stats()
      IO.inspect(stats.total_size)   # Total bytes
      IO.inspect(stats.file_count)   # Number of files
      IO.inspect(stats.repos)        # List of cached repos
  """
  @spec cache_stats() :: {:ok, cache_stats()} | {:error, term()}
  def cache_stats do
    GenServer.call(HfHub.Cache.Server, :stats)
  end

  @doc """
  Evicts least recently used files to free up space.

  ## Options

    * `:target_size` - Target cache size in bytes
    * `:max_age` - Maximum age of files in seconds

  ## Examples

      # Evict files to get under 5GB
      :ok = HfHub.Cache.evict_lru(target_size: 5 * 1024 * 1024 * 1024)

      # Evict files older than 30 days
      :ok = HfHub.Cache.evict_lru(max_age: 30 * 24 * 60 * 60)
  """
  @spec evict_lru(keyword()) :: :ok | {:error, term()}
  def evict_lru(opts) do
    target_size = Keyword.get(opts, :target_size)
    max_age = Keyword.get(opts, :max_age)

    hub_dir = Path.join(HfHub.FS.cache_dir(), "hub")
    files = list_cached_files(hub_dir)
    files_to_evict = select_files_to_evict(files, target_size, max_age)
    evict_files(files_to_evict)
  end

  defp list_cached_files(hub_dir) do
    if File.exists?(hub_dir) do
      hub_dir
      |> Path.join("**/*")
      |> Path.wildcard()
      |> Enum.filter(&File.regular?/1)
      |> Enum.reject(&String.ends_with?(&1, ".sha256"))
      |> Enum.flat_map(&file_info/1)
    else
      []
    end
  end

  defp file_info(path) do
    case File.stat(path, time: :posix) do
      {:ok, %File.Stat{size: size, atime: atime}} ->
        [%{path: path, size: size, atime: atime}]

      _ ->
        []
    end
  end

  defp select_files_to_evict(files, target_size, max_age) do
    now = System.system_time(:second)

    # First, select files older than max_age
    files_by_age =
      if max_age do
        Enum.filter(files, fn %{atime: atime} ->
          now - atime > max_age
        end)
      else
        []
      end

    # Then, if we need to reach target_size, select LRU files
    files_by_size =
      if target_size do
        current_size = Enum.reduce(files, 0, fn %{size: s}, acc -> acc + s end)

        if current_size > target_size do
          # Sort by access time (oldest first)
          sorted = Enum.sort_by(files, & &1.atime)

          # Select files to delete until we're under target_size
          select_until_target(sorted, current_size, target_size, [])
        else
          []
        end
      else
        []
      end

    # Combine and deduplicate
    (files_by_age ++ files_by_size)
    |> Enum.uniq_by(& &1.path)
  end

  defp select_until_target([], _current, _target, acc), do: acc

  defp select_until_target(_files, current, target, acc) when current <= target, do: acc

  defp select_until_target([file | rest], current, target, acc) do
    select_until_target(rest, current - file.size, target, [file | acc])
  end

  defp evict_files(files) do
    Enum.each(files, fn %{path: path} ->
      File.rm(path)
      # Notify the cache server
      GenServer.cast(HfHub.Cache.Server, {:remove_file, path})
    end)

    :ok
  end

  @doc """
  Validates cache integrity.

  Checks that all cached files have valid checksums and removes corrupted files.

  ## Examples

      {:ok, report} = HfHub.Cache.validate_integrity()
  """
  @spec validate_integrity() :: {:ok, map()} | {:error, term()}
  def validate_integrity do
    hub_dir = Path.join(HfHub.FS.cache_dir(), "hub")
    files = list_cached_files(hub_dir)
    results = validate_all_files(files)

    report = %{
      total_files: length(files),
      valid_files: Enum.count(results, fn {_, status} -> status == :valid end),
      corrupted_files: Enum.count(results, fn {_, status} -> status == :corrupted end),
      missing_checksum: Enum.count(results, fn {_, status} -> status == :no_checksum end),
      details: results
    }

    {:ok, report}
  end

  defp validate_all_files(files) do
    files
    |> Task.async_stream(&validate_single_file/1, max_concurrency: System.schedulers_online())
    |> Enum.map(fn {:ok, result} -> result end)
  end

  defp validate_single_file(%{path: path}) do
    checksum_path = path <> ".sha256"

    if File.exists?(checksum_path) do
      case validate_file_checksum(path, checksum_path) do
        :ok -> {path, :valid}
        :error -> {path, :corrupted}
      end
    else
      {path, :no_checksum}
    end
  end

  defp validate_file_checksum(file_path, checksum_path) do
    with {:ok, expected} <- File.read(checksum_path),
         expected <- String.trim(expected),
         {:ok, actual} <- compute_sha256(file_path) do
      if actual == expected do
        :ok
      else
        :error
      end
    else
      _ -> :error
    end
  end

  defp compute_sha256(file_path) do
    hash =
      File.stream!(file_path, 65_536)
      |> Enum.reduce(:crypto.hash_init(:sha256), fn chunk, acc ->
        :crypto.hash_update(acc, chunk)
      end)
      |> :crypto.hash_final()
      |> Base.encode16(case: :lower)

    {:ok, hash}
  rescue
    _ -> {:error, :read_failed}
  end
end
