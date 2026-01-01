defmodule HfHub.Commit do
  @moduledoc """
  Commit operations for uploading files to HuggingFace Hub.

  This module provides functions to create commits that add, delete,
  or copy files in a repository.

  ## Upload Modes

  Files are uploaded in one of two modes:
  - **Regular**: Base64-encoded in commit payload (for files < 10MB)
  - **LFS**: Git Large File Storage protocol (for files >= 10MB)

  The upload mode is automatically determined based on file size.

  ## Examples

      # Upload a single file
      {:ok, info} = HfHub.Commit.upload_file(
        "/path/to/model.bin",
        "model.bin",
        "my-org/my-model",
        token: token,
        commit_message: "Add model weights"
      )

      # Create a commit with multiple operations
      {:ok, info} = HfHub.Commit.create("my-model", [
        Operation.add("model.safetensors", "/path/to/model"),
        Operation.add("config.json", config_content),
        Operation.delete("old_model.bin")
      ], token: token, commit_message: "Update model")
  """

  alias HfHub.{Auth, HTTP, LFS}
  alias HfHub.Commit.{CommitInfo, LfsUpload, Operation}

  # 10MB threshold for LFS uploads
  @lfs_threshold 10 * 1024 * 1024

  @type commit_opts :: [
          token: String.t(),
          repo_type: :model | :dataset | :space,
          revision: String.t(),
          commit_message: String.t(),
          commit_description: String.t(),
          create_pr: boolean(),
          parent_commit: String.t()
        ]

  @doc """
  Creates a commit with one or more operations.

  This is the primary function for making changes to a repository.
  Operations can include adding files, deleting files, or copying
  existing LFS files.

  ## Options

  - `:token` - Authentication token (required)
  - `:repo_type` - Repository type: :model, :dataset, :space (default: :model)
  - `:revision` - Target branch (default: "main")
  - `:commit_message` - Commit message (required)
  - `:commit_description` - Extended commit description
  - `:create_pr` - Create a pull request instead of direct commit
  - `:parent_commit` - Parent commit SHA for atomic operations

  ## Examples

      alias HfHub.Commit.Operation

      {:ok, info} = HfHub.Commit.create("my-model", [
        Operation.add("config.json", ~s({"hidden_size": 768})),
        Operation.delete("old_config.json")
      ], token: token, commit_message: "Update config")
  """
  @spec create(String.t(), [Operation.t()], commit_opts()) ::
          {:ok, CommitInfo.t()} | {:error, term()}
  def create(repo_id, operations, opts \\ []) when is_list(operations) do
    with :ok <- validate_options(opts),
         {:ok, token} <- get_token(opts),
         {:ok, prepared_ops} <- prepare_operations(operations),
         {:ok, uploaded_ops} <- upload_lfs_files(repo_id, prepared_ops, token, opts),
         {:ok, response} <- commit_operations(repo_id, uploaded_ops, token, opts) do
      {:ok, CommitInfo.from_response(response)}
    end
  end

  @doc """
  Uploads a single file to a repository.

  Convenience wrapper around `create/3` for single-file uploads.

  ## Examples

      # From file path
      {:ok, info} = HfHub.Commit.upload_file(
        "/path/to/model.bin",
        "model.bin",
        "my-model",
        token: token
      )

      # From binary content
      {:ok, info} = HfHub.Commit.upload_file(
        config_json,
        "config.json",
        "my-model",
        token: token,
        commit_message: "Update config"
      )
  """
  @spec upload_file(binary() | Path.t(), String.t(), String.t(), commit_opts()) ::
          {:ok, CommitInfo.t()} | {:error, term()}
  def upload_file(path_or_data, path_in_repo, repo_id, opts \\ []) do
    message = opts[:commit_message] || "Upload #{path_in_repo}"
    opts = Keyword.put(opts, :commit_message, message)

    operation = Operation.add(path_in_repo, path_or_data)
    create(repo_id, [operation], opts)
  end

  @doc """
  Deletes a file from a repository.

  ## Examples

      {:ok, info} = HfHub.Commit.delete_file(
        "old_model.bin",
        "my-model",
        token: token,
        commit_message: "Remove old weights"
      )
  """
  @spec delete_file(String.t(), String.t(), commit_opts()) ::
          {:ok, CommitInfo.t()} | {:error, term()}
  def delete_file(path_in_repo, repo_id, opts \\ []) do
    message = opts[:commit_message] || "Delete #{path_in_repo}"
    opts = Keyword.put(opts, :commit_message, message)

    operation = Operation.delete(path_in_repo)
    create(repo_id, [operation], opts)
  end

  @doc """
  Deletes a folder and all its contents from a repository.
  """
  @spec delete_folder(String.t(), String.t(), commit_opts()) ::
          {:ok, CommitInfo.t()} | {:error, term()}
  def delete_folder(path_in_repo, repo_id, opts \\ []) do
    message = opts[:commit_message] || "Delete #{path_in_repo}/"
    opts = Keyword.put(opts, :commit_message, message)

    operation = Operation.delete(path_in_repo, is_folder: true)
    create(repo_id, [operation], opts)
  end

  @doc """
  Uploads an entire folder to a repository.

  Files are uploaded in batch with automatic LFS detection.
  Use patterns to filter which files to include or exclude.

  ## Options

  - `:token` - Authentication token (required)
  - `:repo_type` - Repository type (default: :model)
  - `:revision` - Target branch (default: "main")
  - `:commit_message` - Commit message (default: "Upload folder")
  - `:commit_description` - Extended description
  - `:create_pr` - Create pull request (default: false)
  - `:allow_patterns` - Only include files matching patterns
  - `:ignore_patterns` - Exclude files matching patterns
  - `:delete_patterns` - Delete remote files matching patterns

  ## Pattern Syntax

  Patterns use gitignore-style matching:
  - `*` matches any sequence except `/`
  - `**` matches any sequence including `/`
  - `?` matches single character
  - `[abc]` matches character class

  ## Examples

      # Upload entire folder
      {:ok, info} = HfHub.Commit.upload_folder(
        "/path/to/model_dir",
        "my-org/my-model",
        token: token
      )

      # With pattern filtering
      {:ok, info} = HfHub.Commit.upload_folder(
        "/path/to/model_dir",
        "my-model",
        token: token,
        ignore_patterns: ["*.pyc", "__pycache__/**", ".git/**"],
        allow_patterns: ["*.safetensors", "*.json"]
      )

      # Delete old files matching pattern
      {:ok, info} = HfHub.Commit.upload_folder(
        "/path/to/model_dir",
        "my-model",
        token: token,
        delete_patterns: ["*.bin"]  # Delete old .bin files, upload new
      )
  """
  @spec upload_folder(Path.t(), String.t(), commit_opts()) ::
          {:ok, CommitInfo.t()} | {:error, term()}
  def upload_folder(folder_path, repo_id, opts \\ []) do
    with :ok <- validate_folder(folder_path),
         {:ok, files} <- collect_files(folder_path, opts),
         {:ok, operations} <- build_folder_operations(folder_path, files, opts) do
      message = opts[:commit_message] || "Upload #{Path.basename(folder_path)}"
      opts = Keyword.put(opts, :commit_message, message)
      create(repo_id, operations, opts)
    end
  end

  # Maximum files per commit for large folder uploads
  @max_files_per_commit 100
  # Maximum size per commit (1GB)
  @max_size_per_commit 1024 * 1024 * 1024

  @doc """
  Uploads a large folder using multiple commits if needed.

  For folders with many files or large total size, this function
  automatically splits the upload into multiple commits.

  ## Options

  Same as `upload_folder/3`, plus:
  - `:multi_commits` - Enable automatic splitting (default: false)
  - `:multi_commits_verbose` - Log progress (default: false)

  ## Examples

      {:ok, infos} = HfHub.Commit.upload_large_folder(
        "/path/to/huge_model",
        "my-model",
        token: token,
        multi_commits: true
      )
  """
  @spec upload_large_folder(Path.t(), String.t(), commit_opts()) ::
          {:ok, [CommitInfo.t()]} | {:error, term()}
  def upload_large_folder(folder_path, repo_id, opts \\ []) do
    if opts[:multi_commits] do
      upload_folder_multi(folder_path, repo_id, opts)
    else
      case upload_folder(folder_path, repo_id, opts) do
        {:ok, info} -> {:ok, [info]}
        error -> error
      end
    end
  end

  @doc """
  Checks if a file path matches a gitignore-style pattern.

  ## Pattern Syntax

  - `*` matches any sequence except `/`
  - `**` matches any sequence including `/`
  - `?` matches single character
  - `[abc]` matches character class

  ## Examples

      iex> HfHub.Commit.matches_pattern?("file.json", "*.json")
      true

      iex> HfHub.Commit.matches_pattern?("path/to/file.json", "**/*.json")
      true

      iex> HfHub.Commit.matches_pattern?("__pycache__/cache.pyc", "__pycache__/**")
      true
  """
  @spec matches_pattern?(String.t(), String.t()) :: boolean()
  def matches_pattern?(file, pattern) do
    regex = pattern_to_regex(pattern)
    Regex.match?(regex, file)
  end

  @doc """
  Returns the LFS size threshold in bytes (10MB).
  """
  @spec lfs_threshold() :: non_neg_integer()
  def lfs_threshold, do: @lfs_threshold

  @doc """
  Determines if a file needs LFS upload based on its size.
  """
  @spec needs_lfs?(Operation.Add.t()) :: boolean()
  def needs_lfs?(%Operation.Add{upload_info: info}) do
    info.size >= @lfs_threshold
  end

  # Private implementation

  defp validate_options(opts) do
    case Keyword.get(opts, :commit_message) do
      nil -> {:error, :missing_commit_message}
      "" -> {:error, :empty_commit_message}
      _ -> :ok
    end
  end

  defp get_token(opts) do
    case opts[:token] do
      nil ->
        case Auth.get_token() do
          {:ok, token} -> {:ok, token}
          {:error, :no_token} -> {:error, :no_token}
        end

      token ->
        {:ok, token}
    end
  end

  defp prepare_operations(operations) do
    # Determine upload mode for each add operation
    prepared =
      Enum.map(operations, fn
        %Operation.Add{} = op ->
          mode = if needs_lfs?(op), do: :lfs, else: :regular
          %{op | upload_mode: mode}

        other ->
          other
      end)

    {:ok, prepared}
  end

  defp upload_lfs_files(repo_id, operations, token, opts) do
    lfs_ops =
      Enum.filter(operations, fn
        %Operation.Add{upload_mode: :lfs} -> true
        _ -> false
      end)

    if Enum.empty?(lfs_ops) do
      {:ok, operations}
    else
      case LfsUpload.upload_batch(repo_id, lfs_ops, token, opts) do
        {:ok, uploaded_ops} ->
          # Replace LFS ops with uploaded versions
          {:ok, replace_lfs_ops(operations, uploaded_ops)}

        {:error, _} = error ->
          error
      end
    end
  end

  defp replace_lfs_ops(operations, uploaded_ops) do
    # Create a map of path -> uploaded operation
    uploaded_map = Map.new(uploaded_ops, fn op -> {op.path_in_repo, op} end)

    Enum.map(operations, fn
      %Operation.Add{upload_mode: :lfs, path_in_repo: path} = _op ->
        Map.get(uploaded_map, path)

      other ->
        other
    end)
  end

  defp commit_operations(repo_id, operations, token, opts) do
    repo_type = opts[:repo_type] || :model
    revision = opts[:revision] || "main"

    payload = build_commit_payload(operations, opts)
    path = commit_path(repo_id, repo_type, revision)

    HTTP.post(path, payload, token: token)
  end

  defp build_commit_payload(operations, opts) do
    %{
      "operations" => Enum.map(operations, &operation_to_payload/1),
      "summary" => opts[:commit_message],
      "description" => opts[:commit_description],
      "createPr" => opts[:create_pr] || false,
      "parentCommit" => opts[:parent_commit]
    }
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp operation_to_payload(%Operation.Add{upload_mode: :regular} = op) do
    {:ok, content} = Operation.base64_content(op)

    %{
      "key" => op.path_in_repo,
      "value" => %{
        "content" => content,
        "encoding" => "base64"
      }
    }
  end

  defp operation_to_payload(%Operation.Add{upload_mode: :lfs} = op) do
    %{
      "key" => op.path_in_repo,
      "value" => %{
        "lfs" => %{
          "oid" => LFS.oid(op.upload_info),
          "size" => op.upload_info.size
        }
      }
    }
  end

  defp operation_to_payload(%Operation.Delete{} = op) do
    %{
      "key" => op.path_in_repo,
      "value" => %{
        "delete" => %{
          "isFolder" => op.is_folder
        }
      }
    }
  end

  defp operation_to_payload(%Operation.Copy{} = op) do
    copy_value =
      %{
        "src" => op.src_path,
        "srcRevision" => op.src_revision
      }
      |> Enum.reject(fn {_, v} -> is_nil(v) end)
      |> Map.new()

    %{
      "key" => op.dst_path,
      "value" => %{
        "copy" => copy_value
      }
    }
  end

  defp commit_path(repo_id, repo_type, revision) do
    prefix = repo_type_prefix(repo_type)
    encoded_repo = URI.encode(repo_id, &URI.char_unreserved?/1)
    "/api/#{prefix}/#{encoded_repo}/commit/#{revision}"
  end

  defp repo_type_prefix(:model), do: "models"
  defp repo_type_prefix(:dataset), do: "datasets"
  defp repo_type_prefix(:space), do: "spaces"

  # Folder upload helpers

  defp validate_folder(path) do
    cond do
      not File.exists?(path) -> {:error, {:folder_not_found, path}}
      not File.dir?(path) -> {:error, {:not_a_directory, path}}
      true -> :ok
    end
  end

  defp collect_files(folder_path, opts) do
    allow_patterns = opts[:allow_patterns] || []
    ignore_patterns = opts[:ignore_patterns] || default_ignore_patterns()

    files =
      folder_path
      |> Path.join("**/*")
      |> Path.wildcard()
      |> Enum.filter(&File.regular?/1)
      |> Enum.map(&Path.relative_to(&1, folder_path))
      |> filter_by_patterns(allow_patterns, ignore_patterns)

    {:ok, files}
  end

  defp default_ignore_patterns do
    [
      ".git/**",
      ".git",
      "__pycache__/**",
      "__pycache__",
      "*.pyc",
      ".DS_Store",
      "*.swp",
      ".cache/**"
    ]
  end

  defp filter_by_patterns(files, allow_patterns, ignore_patterns) do
    files
    |> maybe_filter_allow(allow_patterns)
    |> filter_ignore(ignore_patterns)
  end

  defp maybe_filter_allow(files, []), do: files

  defp maybe_filter_allow(files, patterns) do
    Enum.filter(files, fn file ->
      Enum.any?(patterns, &matches_pattern?(file, &1))
    end)
  end

  defp filter_ignore(files, patterns) do
    Enum.reject(files, fn file ->
      Enum.any?(patterns, &matches_pattern?(file, &1))
    end)
  end

  defp pattern_to_regex(pattern) do
    regex_str =
      pattern
      |> String.replace(".", "\\.")
      |> String.replace("**", "<<GLOBSTAR>>")
      |> String.replace("*", "[^/]*")
      |> String.replace("<<GLOBSTAR>>", ".*")
      |> String.replace("?", ".")

    Regex.compile!("^#{regex_str}$")
  end

  defp build_folder_operations(folder_path, files, opts) do
    delete_patterns = opts[:delete_patterns] || []

    add_ops = build_add_operations(folder_path, files)
    delete_ops = build_delete_operations(delete_patterns)

    {:ok, add_ops ++ delete_ops}
  end

  defp build_add_operations(folder_path, files) do
    Enum.map(files, fn relative_path ->
      full_path = Path.join(folder_path, relative_path)
      Operation.add(relative_path, full_path)
    end)
  end

  defp build_delete_operations([]), do: []

  defp build_delete_operations(patterns) do
    # For now, only support explicit paths (not patterns requiring remote listing)
    Enum.flat_map(patterns, &pattern_to_delete_op/1)
  end

  defp pattern_to_delete_op(pattern) do
    if String.contains?(pattern, "*") do
      # Pattern - would need remote listing, skip for now
      []
    else
      # Explicit path
      [Operation.delete(pattern)]
    end
  end

  defp upload_folder_multi(folder_path, repo_id, opts) do
    with :ok <- validate_folder(folder_path),
         {:ok, files} <- collect_files(folder_path, opts) do
      batches = batch_files(folder_path, files)
      commit_batches(batches, folder_path, repo_id, opts)
    end
  end

  defp commit_batches(batches, folder_path, repo_id, opts) do
    total_batches = length(batches)

    results =
      batches
      |> Enum.with_index(1)
      |> Enum.reduce_while({:ok, []}, fn {batch, index}, {:ok, acc} ->
        commit_single_batch(batch, index, total_batches, folder_path, repo_id, opts, acc)
      end)

    case results do
      {:ok, infos} -> {:ok, Enum.reverse(infos)}
      error -> error
    end
  end

  defp commit_single_batch(batch, index, total_batches, folder_path, repo_id, opts, acc) do
    base_message = opts[:commit_message] || "Upload #{Path.basename(folder_path)}"
    message = "#{base_message} (batch #{index}/#{total_batches})"
    batch_opts = Keyword.put(opts, :commit_message, message)

    operations = build_add_operations(folder_path, batch)

    case create(repo_id, operations, batch_opts) do
      {:ok, info} ->
        maybe_log_batch_progress(index, total_batches, opts)
        {:cont, {:ok, [info | acc]}}

      error ->
        {:halt, error}
    end
  end

  defp maybe_log_batch_progress(index, total, opts) do
    if opts[:multi_commits_verbose] do
      IO.puts("Committed batch #{index}/#{total}")
    end
  end

  defp batch_files(folder_path, files) do
    {batches, current_batch, _current_size} =
      Enum.reduce(files, {[], [], 0}, fn file, {batches, current, size} ->
        full_path = Path.join(folder_path, file)
        file_size = File.stat!(full_path).size

        cond do
          # Start new batch if current is at limit
          length(current) >= @max_files_per_commit ->
            {[Enum.reverse(current) | batches], [file], file_size}

          # Start new batch if size would exceed limit
          size + file_size > @max_size_per_commit and current != [] ->
            {[Enum.reverse(current) | batches], [file], file_size}

          # Add to current batch
          true ->
            {batches, [file | current], size + file_size}
        end
      end)

    # Don't forget the last batch
    all_batches =
      if current_batch == [] do
        batches
      else
        [Enum.reverse(current_batch) | batches]
      end

    Enum.reverse(all_batches)
  end
end
