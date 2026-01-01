defmodule HfHub.RepoFiles do
  @moduledoc """
  Repository file listing with ETag information.

  Provides Bumblebee-compatible file listing that returns a map of
  filenames to ETags, suitable for efficient cache validation.

  ## Examples

      # List files from HuggingFace repository
      {:ok, files} = HfHub.RepoFiles.get_repo_files({:hf, "bert-base-uncased"})
      # => %{"config.json" => "\"abc123\"", "pytorch_model.bin" => "\"def456\"", ...}

      # List files from local directory
      {:ok, files} = HfHub.RepoFiles.get_repo_files({:local, "/path/to/model"})
      # => %{"config.json" => nil, "pytorch_model.bin" => nil, ...}
  """

  alias HfHub.Repository

  @doc """
  Gets a map of files and their ETags from a repository.

  For HuggingFace repositories, returns `%{filename => etag}` where etag
  is used for cache validation. For local directories, returns
  `%{filename => nil}`.

  ## Examples

      {:ok, files} = HfHub.RepoFiles.get_repo_files({:hf, "bert-base-uncased"})
      Map.has_key?(files, "config.json")
      # => true
  """
  @spec get_repo_files(Repository.t()) ::
          {:ok, %{String.t() => String.t() | nil}} | {:error, term()}
  def get_repo_files(repository) do
    repository
    |> Repository.normalize!()
    |> do_get_repo_files()
  end

  defp do_get_repo_files({:local, dir}) do
    case File.ls(dir) do
      {:ok, filenames} ->
        repo_files =
          for filename <- filenames,
              path = Path.join(dir, filename),
              File.regular?(path),
              into: %{},
              do: {filename, nil}

        {:ok, repo_files}

      {:error, reason} ->
        {:error, "could not read #{dir}, reason: #{:file.format_error(reason)}"}
    end
  end

  defp do_get_repo_files({:hf, repository_id, opts}) do
    subdir = opts[:subdir]
    url = Repository.file_listing_url({:hf, repository_id, opts})
    cache_scope = Repository.cache_scope(repository_id)

    result =
      HfHub.Hub.cached_download(
        url,
        [cache_scope: cache_scope] ++ Keyword.take(opts, [:cache_dir, :offline, :auth_token])
      )

    with {:ok, path} <- result,
         {:ok, data} <- decode_json(path) do
      repo_files =
        for entry <- data, entry["type"] == "file", into: %{} do
          path = entry["path"]

          name =
            if subdir do
              String.replace_leading(path, subdir <> "/", "")
            else
              path
            end

          etag_content = get_in(entry, ["lfs", "oid"]) || entry["oid"]
          etag = if etag_content, do: <<?", etag_content::binary, ?">>, else: nil
          {name, etag}
        end

      {:ok, repo_files}
    end
  end

  defp decode_json(path) do
    path
    |> File.read!()
    |> Jason.decode()
    |> case do
      {:ok, data} -> {:ok, data}
      _ -> {:error, "failed to parse JSON file: #{path}"}
    end
  end
end
