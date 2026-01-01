# Prompt 05: Folder Upload Implementation

## Context

You are implementing folder upload functionality for `hf_hub_ex`. This enables uploading entire directories with pattern filtering and efficient batching.

**Prerequisites**: Prompts 01-04 must be completed first.

## Required Reading

**Read these files first:**
```
lib/hf_hub/commit.ex                    # Commit API
lib/hf_hub/commit/operation.ex          # Operations
lib/hf_hub/commit/lfs_upload.ex         # LFS upload
lib/hf_hub/download.ex                  # Pattern matching reference
```

**Reference documentation:**
```
docs/20251231/upload-api/docs.md
```

**Python reference:**
```
huggingface_hub/src/huggingface_hub/_upload_large_folder.py
huggingface_hub/src/huggingface_hub/utils/_paths.py
```

## Task

Implement `HfHub.Commit.upload_folder/3` with pattern filtering and batch operations.

## Implementation Requirements

### 1. Add to `lib/hf_hub/commit.ex`

```elixir
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
- `:max_workers` - Concurrent LFS uploads (default: 4)

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
       {:ok, operations} <- build_folder_operations(folder_path, files, opts),
       message = opts[:commit_message] || "Upload #{Path.basename(folder_path)}",
       opts = Keyword.put(opts, :commit_message, message) do
    create(repo_id, operations, opts)
  end
end

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

  files = folder_path
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

defp matches_pattern?(file, pattern) do
  # Convert gitignore pattern to regex
  regex = pattern
  |> String.replace(".", "\\.")
  |> String.replace("**", "<<GLOBSTAR>>")
  |> String.replace("*", "[^/]*")
  |> String.replace("<<GLOBSTAR>>", ".*")
  |> String.replace("?", ".")
  |> then(&"^#{&1}$")
  |> Regex.compile!()

  Regex.match?(regex, file)
end

defp build_folder_operations(folder_path, files, opts) do
  delete_patterns = opts[:delete_patterns] || []

  # Build add operations for local files
  add_ops = Enum.map(files, fn relative_path ->
    full_path = Path.join(folder_path, relative_path)
    Operation.add(relative_path, full_path)
  end)

  # Build delete operations for patterns
  delete_ops = if Enum.empty?(delete_patterns) do
    []
  else
    # Note: Would need to fetch remote file list and filter
    # For now, just support explicit delete_patterns as paths
    Enum.flat_map(delete_patterns, fn pattern ->
      if String.contains?(pattern, "*") do
        # Pattern - would need remote listing
        []
      else
        # Explicit path
        [Operation.delete(pattern)]
      end
    end)
  end

  {:ok, add_ops ++ delete_ops}
end
```

### 2. Add Concurrent LFS Upload Support

Update `lib/hf_hub/commit/lfs_upload.ex`:

```elixir
@doc """
Uploads multiple LFS files concurrently.
"""
@spec upload_batch(String.t(), [Operation.Add.t()], String.t(), keyword()) ::
  {:ok, [Operation.Add.t()]} | {:error, term()}
def upload_batch(repo_id, operations, token, opts \\ []) do
  max_workers = opts[:max_workers] || 4
  upload_infos = Enum.map(operations, & &1.upload_info)

  with {:ok, batch_response} <- request_batch_info(repo_id, upload_infos, token, opts) do
    objects = batch_response["objects"] || []

    ops_by_oid = Map.new(operations, fn op ->
      {LFS.oid(op.upload_info), op}
    end)

    # Upload concurrently
    results = objects
    |> Task.async_stream(
      fn obj -> upload_object(obj, ops_by_oid, token) end,
      max_concurrency: max_workers,
      timeout: 300_000  # 5 minute timeout per file
    )
    |> Enum.map(fn
      {:ok, result} -> result
      {:exit, reason} -> {:error, {:upload_crashed, reason}}
    end)

    case Enum.find(results, &match?({:error, _}, &1)) do
      nil ->
        uploaded = Enum.map(operations, fn op -> %{op | is_uploaded: true} end)
        {:ok, uploaded}

      error ->
        error
    end
  end
end

defp upload_object(obj, ops_by_oid, token) do
  oid = obj["oid"]
  actions = obj["actions"] || %{}

  case Map.get(actions, "upload") do
    nil ->
      # Already exists
      :ok

    upload_action ->
      op = Map.fetch!(ops_by_oid, oid)
      verify_action = Map.get(actions, "verify")
      upload_single(op, upload_action, verify_action, token)
  end
end
```

### 3. Add Large Folder Support (Batched Commits)

```elixir
# In lib/hf_hub/commit.ex

@max_files_per_commit 100
@max_size_per_commit 1024 * 1024 * 1024  # 1GB

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

defp upload_folder_multi(folder_path, repo_id, opts) do
  with :ok <- validate_folder(folder_path),
       {:ok, files} <- collect_files(folder_path, opts) do
    batches = batch_files(folder_path, files)

    results = Enum.with_index(batches, 1)
    |> Enum.reduce_while({:ok, []}, fn {batch, index}, {:ok, acc} ->
      message = "#{opts[:commit_message] || "Upload"} (batch #{index}/#{length(batches)})"
      batch_opts = Keyword.put(opts, :commit_message, message)

      operations = Enum.map(batch, fn relative_path ->
        full_path = Path.join(folder_path, relative_path)
        Operation.add(relative_path, full_path)
      end)

      case create(repo_id, operations, batch_opts) do
        {:ok, info} ->
          if opts[:multi_commits_verbose] do
            IO.puts("Committed batch #{index}/#{length(batches)}")
          end
          {:cont, {:ok, [info | acc]}}

        error ->
          {:halt, error}
      end
    end)

    case results do
      {:ok, infos} -> {:ok, Enum.reverse(infos)}
      error -> error
    end
  end
end

defp batch_files(folder_path, files) do
  {batches, current_batch, current_size} =
    Enum.reduce(files, {[], [], 0}, fn file, {batches, current, size} ->
      full_path = Path.join(folder_path, file)
      file_size = File.stat!(full_path).size

      cond do
        # Start new batch if current is at limit
        length(current) >= @max_files_per_commit ->
          {[current | batches], [file], file_size}

        # Start new batch if size would exceed limit
        size + file_size > @max_size_per_commit and current != [] ->
          {[current | batches], [file], file_size}

        # Add to current batch
        true ->
          {batches, [file | current], size + file_size}
      end
    end)

  # Don't forget the last batch
  if current_batch == [] do
    Enum.reverse(batches)
  else
    Enum.reverse([current_batch | batches])
  end
end
```

## Test Requirements (TDD)

Create `test/hf_hub/commit/folder_upload_test.exs`:

```elixir
defmodule HfHub.Commit.FolderUploadTest do
  use ExUnit.Case, async: true

  alias HfHub.Commit

  setup do
    # Create temp directory with test files
    dir = Path.join(System.tmp_dir!(), "hf_hub_test_#{:rand.uniform(1000000)}")
    File.mkdir_p!(dir)

    File.write!(Path.join(dir, "config.json"), ~s({"key": "value"}))
    File.write!(Path.join(dir, "model.bin"), String.duplicate("x", 100))

    File.mkdir_p!(Path.join(dir, "subdir"))
    File.write!(Path.join(dir, "subdir/data.txt"), "data")

    File.mkdir_p!(Path.join(dir, "__pycache__"))
    File.write!(Path.join(dir, "__pycache__/cache.pyc"), "cache")

    bypass = Bypass.open()
    Application.put_env(:hf_hub, :endpoint, "http://localhost:#{bypass.port}")

    on_exit(fn ->
      File.rm_rf!(dir)
    end)

    {:ok, dir: dir, bypass: bypass}
  end

  describe "upload_folder/3" do
    test "uploads all files in folder", %{dir: dir, bypass: bypass} do
      Bypass.expect(bypass, "POST", "/api/models/user/repo/commit/main", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        payload = Jason.decode!(body)

        # Should have 3 files (excluding __pycache__)
        assert length(payload["operations"]) == 3

        paths = Enum.map(payload["operations"], & &1["key"])
        assert "config.json" in paths
        assert "model.bin" in paths
        assert "subdir/data.txt" in paths
        refute "__pycache__/cache.pyc" in paths

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{
          "commitUrl" => "url",
          "commitOid" => "abc",
          "commitMessage" => "msg",
          "repoUrl" => "url"
        }))
      end)

      {:ok, _} = Commit.upload_folder(dir, "user/repo", token: "hf_test")
    end

    test "respects allow_patterns", %{dir: dir, bypass: bypass} do
      Bypass.expect(bypass, "POST", "/api/models/user/repo/commit/main", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        payload = Jason.decode!(body)

        # Only .json files
        assert length(payload["operations"]) == 1
        assert hd(payload["operations"])["key"] == "config.json"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{
          "commitUrl" => "url",
          "commitOid" => "abc",
          "commitMessage" => "msg",
          "repoUrl" => "url"
        }))
      end)

      {:ok, _} = Commit.upload_folder(dir, "user/repo",
        token: "hf_test",
        allow_patterns: ["*.json"]
      )
    end

    test "respects ignore_patterns", %{dir: dir, bypass: bypass} do
      Bypass.expect(bypass, "POST", "/api/models/user/repo/commit/main", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        payload = Jason.decode!(body)

        paths = Enum.map(payload["operations"], & &1["key"])
        refute Enum.any?(paths, &String.ends_with?(&1, ".bin"))

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{
          "commitUrl" => "url",
          "commitOid" => "abc",
          "commitMessage" => "msg",
          "repoUrl" => "url"
        }))
      end)

      {:ok, _} = Commit.upload_folder(dir, "user/repo",
        token: "hf_test",
        ignore_patterns: ["*.bin"]
      )
    end

    test "returns error for non-existent folder" do
      {:error, {:folder_not_found, _}} = Commit.upload_folder(
        "/nonexistent/path",
        "user/repo",
        token: "hf_test"
      )
    end
  end

  describe "pattern matching" do
    test "matches glob patterns" do
      assert Commit.matches_pattern?("file.json", "*.json")
      assert Commit.matches_pattern?("path/to/file.json", "**/*.json")
      assert Commit.matches_pattern?("__pycache__/file.pyc", "__pycache__/**")
      refute Commit.matches_pattern?("file.txt", "*.json")
    end
  end
end
```

## Quality Requirements

After implementation:
1. Run `mix test` - all tests must pass
2. Run `mix format` - code must be formatted
3. Run `mix credo --strict` - no warnings
4. Run `mix dialyzer` - no errors

## Changelog Entry

Update `CHANGELOG.md`:

```markdown
### Added
- `HfHub.Commit.upload_folder/3` - Upload entire directories
- `HfHub.Commit.upload_large_folder/3` - Upload large directories with batching
- Pattern filtering support (allow_patterns, ignore_patterns)
- Concurrent LFS uploads with configurable workers
```

## README Update

Add to README.md:

```markdown
### Folder Upload

```elixir
# Upload entire folder
{:ok, info} = HfHub.Commit.upload_folder(
  "/path/to/model_dir",
  "my-org/my-model",
  token: token,
  commit_message: "Upload model"
)

# With pattern filtering
{:ok, info} = HfHub.Commit.upload_folder(
  "/path/to/model_dir",
  "my-model",
  token: token,
  ignore_patterns: ["*.pyc", "__pycache__/**"],
  allow_patterns: ["*.safetensors", "*.json"]
)

# Large folder with automatic batching
{:ok, infos} = HfHub.Commit.upload_large_folder(
  "/path/to/huge_model",
  "my-model",
  token: token,
  multi_commits: true
)
```
```

## Completion Checklist

- [ ] `upload_folder/3` implemented
- [ ] Pattern filtering (allow/ignore) works
- [ ] Default ignore patterns applied
- [ ] Subdirectory traversal works
- [ ] `upload_large_folder/3` implemented
- [ ] Batch splitting for large uploads
- [ ] Concurrent LFS uploads
- [ ] All tests pass
- [ ] `mix format` passes
- [ ] `mix credo --strict` passes
- [ ] `mix dialyzer` passes
- [ ] CHANGELOG.md updated
- [ ] README.md updated
