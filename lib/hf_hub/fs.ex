defmodule HfHub.FS do
  @moduledoc """
  Filesystem utilities for HuggingFace cache management.

  Provides low-level functions for managing the local cache directory structure,
  file paths, and locking mechanisms.

  ## Examples

      # Ensure cache directory exists
      :ok = HfHub.FS.ensure_cache_dir()

      # Get repository path
      path = HfHub.FS.repo_path("bert-base-uncased", :model)

      # Get file path in repository
      path = HfHub.FS.file_path("bert-base-uncased", :model, "config.json")

      # Acquire file lock for concurrent downloads
      {:ok, lock} = HfHub.FS.lock_file("bert-base-uncased", "pytorch_model.bin")
      # ... download file ...
      :ok = HfHub.FS.unlock_file(lock)
  """

  @doc """
  Ensures the cache directory exists.

  Creates the cache directory and any necessary subdirectories if they don't exist.

  ## Examples

      :ok = HfHub.FS.ensure_cache_dir()
  """
  @spec ensure_cache_dir() :: :ok | {:error, term()}
  def ensure_cache_dir do
    dir = cache_dir()

    case File.mkdir_p(dir) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Gets the local path for a repository.

  ## Arguments

    * `repo_id` - Repository ID
    * `repo_type` - Type of repository (`:model`, `:dataset`, or `:space`)

  ## Examples

      path = HfHub.FS.repo_path("bert-base-uncased", :model)
      # => "/home/user/.cache/huggingface/hub/models--bert-base-uncased"
  """
  @spec repo_path(HfHub.repo_id(), HfHub.repo_type()) :: Path.t()
  def repo_path(repo_id, repo_type) do
    # Convert repo_id slashes to double dashes for filesystem safety
    # e.g., "openai/gpt-2" becomes "models--openai--gpt-2"
    repo_dir = String.replace(repo_id, "/", "--")
    type_prefix = Atom.to_string(repo_type) <> "s"

    Path.join([cache_dir(), "hub", "#{type_prefix}--#{repo_dir}"])
  end

  @doc """
  Gets the local path for a file in a repository.

  ## Arguments

    * `repo_id` - Repository ID
    * `repo_type` - Type of repository
    * `filename` - Name of the file
    * `revision` - Git revision (defaults to "main")

  ## Examples

      path = HfHub.FS.file_path("bert-base-uncased", :model, "config.json")
      # => "/home/user/.cache/huggingface/hub/models--bert-base-uncased/snapshots/main/config.json"
  """
  @spec file_path(HfHub.repo_id(), HfHub.repo_type(), HfHub.filename(), HfHub.revision()) ::
          Path.t()
  def file_path(repo_id, repo_type, filename, revision \\ "main") do
    repo = repo_path(repo_id, repo_type)
    Path.join([repo, "snapshots", revision, filename])
  end

  @doc """
  Acquires a lock on a file for concurrent download protection.

  Returns `{:ok, lock}` where `lock` is a reference that can be used to unlock the file.

  ## Arguments

    * `repo_id` - Repository ID
    * `filename` - Name of the file

  ## Examples

      {:ok, lock} = HfHub.FS.lock_file("bert-base-uncased", "pytorch_model.bin")
      # ... perform download ...
      :ok = HfHub.FS.unlock_file(lock)
  """
  @spec lock_file(HfHub.repo_id(), HfHub.filename()) :: {:ok, reference()} | {:error, term()}
  def lock_file(repo_id, filename) do
    lock_path = Path.join([cache_dir(), "locks", "#{repo_id}--#{filename}.lock"])
    lock_dir = Path.dirname(lock_path)

    with :ok <- File.mkdir_p(lock_dir),
         {:ok, file} <- File.open(lock_path, [:write, :exclusive]) do
      # Create a reference to track this lock
      lock_ref = make_ref()
      # Store the file handle and path in the process dictionary
      Process.put({:lock, lock_ref}, {file, lock_path})
      {:ok, lock_ref}
    else
      {:error, :eexist} ->
        # Lock file already exists, retry after a short delay
        Process.sleep(100)
        lock_file(repo_id, filename)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Releases a file lock.

  ## Arguments

    * `lock` - Lock reference from `lock_file/2`

  ## Examples

      {:ok, lock} = HfHub.FS.lock_file("bert-base-uncased", "config.json")
      :ok = HfHub.FS.unlock_file(lock)
  """
  @spec unlock_file(reference()) :: :ok | {:error, term()}
  def unlock_file(lock) do
    case Process.get({:lock, lock}) do
      {file, lock_path} ->
        File.close(file)
        File.rm(lock_path)
        Process.delete({:lock, lock})
        :ok

      nil ->
        {:error, :invalid_lock}
    end
  end

  @doc """
  Gets the configured cache directory.

  ## Examples

      dir = HfHub.FS.cache_dir()
      # => "/home/user/.cache/huggingface"
  """
  @spec cache_dir() :: Path.t()
  def cache_dir do
    Application.get_env(:hf_hub, :cache_dir, default_cache_dir())
  end

  defp default_cache_dir do
    Path.expand("~/.cache/huggingface")
  end
end
