# Prompt 03: Commit Operations Foundation

## Context

You are implementing the commit operations foundation for the `hf_hub_ex` Elixir library. This provides the data structures and base functionality for file uploads. The actual upload logic will be in subsequent prompts.

**Prerequisites**: Prompts 01-02 must be completed first.

## Required Reading

**Read these files first:**
```
lib/hf_hub/http.ex           # HTTP client with write methods
lib/hf_hub/lfs.ex            # LFS UploadInfo (already exists)
lib/hf_hub/api.ex            # API patterns
lib/hf_hub/errors.ex         # Error types
```

**Reference documentation:**
```
docs/20251231/upload-api/docs.md         # Full upload API specification
docs/20251231/gap-analysis/docs.md       # Gap analysis
```

**Python reference:**
```
huggingface_hub/src/huggingface_hub/_commit_api.py
```

## Task

Create commit operation data structures and the commit info response type.

## Implementation Requirements

### 1. Create `lib/hf_hub/commit/operation.ex`

```elixir
defmodule HfHub.Commit.Operation do
  @moduledoc """
  Commit operation types for file manipulation.

  Operations represent changes to be made in a single commit:
  - `Add` - Upload or update a file
  - `Delete` - Remove a file or folder
  - `Copy` - Copy an existing LFS file (efficient, no re-upload)

  ## Examples

      # Add a file from disk
      add_op = HfHub.Commit.Operation.add("model.bin", "/path/to/model.bin")

      # Add from binary content
      add_op = HfHub.Commit.Operation.add("config.json", ~s({"hidden_size": 768}))

      # Delete a file
      del_op = HfHub.Commit.Operation.delete("old_model.bin")

      # Delete a folder
      del_op = HfHub.Commit.Operation.delete("old_weights/", is_folder: true)

      # Copy an LFS file
      copy_op = HfHub.Commit.Operation.copy("v1/model.bin", "v2/model.bin")
  """

  alias HfHub.LFS.UploadInfo

  @type t :: add() | delete() | copy()
  @type add :: %__MODULE__.Add{}
  @type delete :: %__MODULE__.Delete{}
  @type copy :: %__MODULE__.Copy{}

  defmodule Add do
    @moduledoc "Operation to add or update a file."

    defstruct [
      :path_in_repo,
      :content,
      :upload_info,
      upload_mode: nil,
      is_uploaded: false,
      is_committed: false
    ]

    @type content_source :: binary() | Path.t()
    @type upload_mode :: :regular | :lfs | nil

    @type t :: %__MODULE__{
      path_in_repo: String.t(),
      content: content_source(),
      upload_info: HfHub.LFS.UploadInfo.t() | nil,
      upload_mode: upload_mode(),
      is_uploaded: boolean(),
      is_committed: boolean()
    }
  end

  defmodule Delete do
    @moduledoc "Operation to delete a file or folder."

    defstruct [:path_in_repo, is_folder: false]

    @type t :: %__MODULE__{
      path_in_repo: String.t(),
      is_folder: boolean()
    }
  end

  defmodule Copy do
    @moduledoc "Operation to copy an existing LFS file."

    defstruct [:src_path, :dst_path, :src_revision]

    @type t :: %__MODULE__{
      src_path: String.t(),
      dst_path: String.t(),
      src_revision: String.t() | nil
    }
  end

  @doc """
  Creates an add operation from a file path or binary content.

  Automatically computes UploadInfo (SHA256, size, sample) for the content.

  ## Options

  - `:upload_info` - Pre-computed upload info (skips computation)

  ## Examples

      # From file path
      op = Operation.add("model.safetensors", "/path/to/model.safetensors")

      # From binary
      op = Operation.add("config.json", Jason.encode!(%{hidden_size: 768}))
  """
  @spec add(String.t(), binary() | Path.t(), keyword()) :: Add.t()
  def add(path_in_repo, content, opts \\ []) do
    validate_path!(path_in_repo)

    upload_info = opts[:upload_info] || compute_upload_info(content)

    %Add{
      path_in_repo: normalize_path(path_in_repo),
      content: content,
      upload_info: upload_info
    }
  end

  @doc """
  Creates a delete operation.

  ## Options

  - `:is_folder` - Set to true to delete a folder and contents

  ## Examples

      Operation.delete("old_model.bin")
      Operation.delete("old_weights/", is_folder: true)
  """
  @spec delete(String.t(), keyword()) :: Delete.t()
  def delete(path_in_repo, opts \\ []) do
    validate_path!(path_in_repo)

    %Delete{
      path_in_repo: normalize_path(path_in_repo),
      is_folder: opts[:is_folder] || false
    }
  end

  @doc """
  Creates a copy operation for an existing LFS file.

  Copy operations are efficient because they don't re-upload the file content.
  The file must already exist in the repository (or at src_revision).

  ## Options

  - `:src_revision` - Source revision (default: current HEAD)

  ## Examples

      Operation.copy("v1/model.bin", "v2/model.bin")
      Operation.copy("model.bin", "archive/model.bin", src_revision: "v1.0")
  """
  @spec copy(String.t(), String.t(), keyword()) :: Copy.t()
  def copy(src_path, dst_path, opts \\ []) do
    validate_path!(src_path)
    validate_path!(dst_path)

    %Copy{
      src_path: normalize_path(src_path),
      dst_path: normalize_path(dst_path),
      src_revision: opts[:src_revision]
    }
  end

  @doc """
  Checks if content is from a file path vs binary data.
  """
  @spec file_path?(Add.t()) :: boolean()
  def file_path?(%Add{content: content}) when is_binary(content) do
    File.exists?(content) && File.regular?(content)
  end

  @doc """
  Gets the content as binary (reads file if path).
  """
  @spec get_content(Add.t()) :: {:ok, binary()} | {:error, term()}
  def get_content(%Add{content: content}) do
    if file_path?(%Add{content: content}) do
      File.read(content)
    else
      {:ok, content}
    end
  end

  @doc """
  Gets base64-encoded content (for regular uploads).
  """
  @spec base64_content(Add.t()) :: {:ok, String.t()} | {:error, term()}
  def base64_content(add_op) do
    with {:ok, content} <- get_content(add_op) do
      {:ok, Base.encode64(content)}
    end
  end

  # Private functions

  defp validate_path!(path) do
    cond do
      String.starts_with?(path, "/") ->
        raise ArgumentError, "path_in_repo cannot start with '/': #{path}"

      String.contains?(path, "..") ->
        raise ArgumentError, "path_in_repo cannot contain '..': #{path}"

      String.contains?(path, "//") ->
        raise ArgumentError, "path_in_repo cannot contain '//': #{path}"

      true ->
        :ok
    end
  end

  defp normalize_path(path) do
    path
    |> String.trim_leading("./")
    |> String.replace(~r/\/+/, "/")
  end

  defp compute_upload_info(content) when is_binary(content) do
    if File.exists?(content) && File.regular?(content) do
      UploadInfo.from_path(content)
    else
      UploadInfo.from_binary(content)
    end
  end
end
```

### 2. Create `lib/hf_hub/commit/commit_info.ex`

```elixir
defmodule HfHub.Commit.CommitInfo do
  @moduledoc """
  Information about a completed commit.

  Returned after successfully committing changes to a repository.
  """

  @derive Jason.Encoder
  defstruct [
    :commit_url,
    :commit_message,
    :commit_description,
    :oid,
    :pr_url,
    :pr_num,
    :pr_revision,
    :repo_url
  ]

  @type t :: %__MODULE__{
    commit_url: String.t(),
    commit_message: String.t(),
    commit_description: String.t() | nil,
    oid: String.t(),
    pr_url: String.t() | nil,
    pr_num: non_neg_integer() | nil,
    pr_revision: String.t() | nil,
    repo_url: String.t()
  }

  @doc """
  Creates CommitInfo from API response.
  """
  @spec from_response(map()) :: t()
  def from_response(response) do
    %__MODULE__{
      commit_url: response["commitUrl"],
      commit_message: response["commitMessage"],
      commit_description: response["commitDescription"],
      oid: response["commitOid"],
      pr_url: get_in(response, ["pullRequest", "url"]),
      pr_num: get_in(response, ["pullRequest", "num"]),
      pr_revision: get_in(response, ["pullRequest", "revision"]),
      repo_url: response["repoUrl"]
    }
  end
end
```

### 3. Create `lib/hf_hub/commit.ex` (Skeleton)

```elixir
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
        commit_message: "Add model weights"
      )

      # Create a commit with multiple operations
      {:ok, info} = HfHub.Commit.create("my-model", [
        Operation.add("model.safetensors", "/path/to/model"),
        Operation.add("config.json", config_content),
        Operation.delete("old_model.bin")
      ], commit_message: "Update model")
  """

  alias HfHub.Commit.{Operation, CommitInfo}
  alias HfHub.{HTTP, Auth}

  @lfs_threshold 10 * 1024 * 1024  # 10MB

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
      ], commit_message: "Update config")
  """
  @spec create(String.t(), [Operation.t()], commit_opts()) ::
    {:ok, CommitInfo.t()} | {:error, term()}
  def create(repo_id, operations, opts \\ [])

  # Implementation will be in Prompt 04

  @doc """
  Uploads a single file to a repository.

  Convenience wrapper around `create/3` for single-file uploads.

  ## Examples

      # From file path
      {:ok, info} = HfHub.Commit.upload_file(
        "/path/to/model.bin",
        "model.bin",
        "my-model"
      )

      # From binary content
      {:ok, info} = HfHub.Commit.upload_file(
        config_json,
        "config.json",
        "my-model",
        commit_message: "Update config"
      )
  """
  @spec upload_file(binary() | Path.t(), String.t(), String.t(), commit_opts()) ::
    {:ok, CommitInfo.t()} | {:error, term()}
  def upload_file(path_or_data, path_in_repo, repo_id, opts \\ [])

  # Implementation will be in Prompt 04

  @doc """
  Deletes a file from a repository.

  ## Examples

      {:ok, info} = HfHub.Commit.delete_file(
        "old_model.bin",
        "my-model",
        commit_message: "Remove old weights"
      )
  """
  @spec delete_file(String.t(), String.t(), commit_opts()) ::
    {:ok, CommitInfo.t()} | {:error, term()}
  def delete_file(path_in_repo, repo_id, opts \\ [])

  # Implementation will be in Prompt 04

  @doc """
  Deletes a folder and all its contents from a repository.
  """
  @spec delete_folder(String.t(), String.t(), commit_opts()) ::
    {:ok, CommitInfo.t()} | {:error, term()}
  def delete_folder(path_in_repo, repo_id, opts \\ [])

  # Implementation will be in Prompt 04

  # Helper to determine if file needs LFS
  @doc false
  def needs_lfs?(%Operation.Add{upload_info: info}) do
    info.size >= @lfs_threshold
  end
end
```

## Test Requirements (TDD)

Create `test/hf_hub/commit/operation_test.exs`:

```elixir
defmodule HfHub.Commit.OperationTest do
  use ExUnit.Case, async: true

  alias HfHub.Commit.Operation
  alias HfHub.Commit.Operation.{Add, Delete, Copy}

  describe "add/3" do
    test "creates add operation from binary content" do
      op = Operation.add("config.json", ~s({"key": "value"}))

      assert %Add{path_in_repo: "config.json"} = op
      assert op.upload_info != nil
      assert op.upload_info.size == 15
    end

    test "creates add operation from file path" do
      # Create temp file
      path = Path.join(System.tmp_dir!(), "test_file.txt")
      File.write!(path, "test content")

      op = Operation.add("uploaded.txt", path)

      assert %Add{path_in_repo: "uploaded.txt"} = op
      assert op.upload_info.size == 12

      File.rm!(path)
    end

    test "normalizes path with leading ./" do
      op = Operation.add("./config.json", "content")
      assert op.path_in_repo == "config.json"
    end

    test "raises on path starting with /" do
      assert_raise ArgumentError, ~r/cannot start with/, fn ->
        Operation.add("/absolute/path.txt", "content")
      end
    end

    test "raises on path containing .." do
      assert_raise ArgumentError, ~r/cannot contain/, fn ->
        Operation.add("../escape.txt", "content")
      end
    end
  end

  describe "delete/2" do
    test "creates delete operation for file" do
      op = Operation.delete("old_file.bin")

      assert %Delete{path_in_repo: "old_file.bin", is_folder: false} = op
    end

    test "creates delete operation for folder" do
      op = Operation.delete("old_weights/", is_folder: true)

      assert %Delete{is_folder: true} = op
    end
  end

  describe "copy/3" do
    test "creates copy operation" do
      op = Operation.copy("v1/model.bin", "v2/model.bin")

      assert %Copy{src_path: "v1/model.bin", dst_path: "v2/model.bin"} = op
      assert op.src_revision == nil
    end

    test "creates copy with source revision" do
      op = Operation.copy("model.bin", "archive/model.bin", src_revision: "v1.0")

      assert op.src_revision == "v1.0"
    end
  end

  describe "file_path?/1" do
    test "returns true for existing file" do
      path = Path.join(System.tmp_dir!(), "test_exists.txt")
      File.write!(path, "content")

      op = Operation.add("file.txt", path)
      assert Operation.file_path?(op)

      File.rm!(path)
    end

    test "returns false for binary content" do
      op = Operation.add("file.txt", "raw content")
      refute Operation.file_path?(op)
    end
  end

  describe "base64_content/1" do
    test "encodes binary content" do
      op = Operation.add("file.txt", "hello world")
      assert {:ok, encoded} = Operation.base64_content(op)
      assert Base.decode64!(encoded) == "hello world"
    end
  end
end
```

Create `test/hf_hub/commit/commit_info_test.exs`:

```elixir
defmodule HfHub.Commit.CommitInfoTest do
  use ExUnit.Case, async: true

  alias HfHub.Commit.CommitInfo

  describe "from_response/1" do
    test "parses complete response" do
      response = %{
        "commitUrl" => "https://huggingface.co/user/repo/commit/abc123",
        "commitMessage" => "Update model",
        "commitDescription" => "Added new weights",
        "commitOid" => "abc123def456",
        "repoUrl" => "https://huggingface.co/user/repo"
      }

      info = CommitInfo.from_response(response)

      assert info.commit_url == "https://huggingface.co/user/repo/commit/abc123"
      assert info.commit_message == "Update model"
      assert info.oid == "abc123def456"
      assert info.pr_url == nil
    end

    test "parses response with PR info" do
      response = %{
        "commitUrl" => "https://huggingface.co/user/repo/commit/abc123",
        "commitMessage" => "Update model",
        "commitOid" => "abc123",
        "repoUrl" => "https://huggingface.co/user/repo",
        "pullRequest" => %{
          "url" => "https://huggingface.co/user/repo/discussions/42",
          "num" => 42,
          "revision" => "refs/pr/42"
        }
      }

      info = CommitInfo.from_response(response)

      assert info.pr_url == "https://huggingface.co/user/repo/discussions/42"
      assert info.pr_num == 42
      assert info.pr_revision == "refs/pr/42"
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

Add to `CHANGELOG.md` under `## [0.1.3] - Unreleased`:

```markdown
### Added
- `HfHub.Commit.Operation` module with Add, Delete, Copy operation types
- `HfHub.Commit.CommitInfo` struct for commit responses
- `HfHub.Commit` module skeleton (implementation in next release)
```

## Completion Checklist

- [ ] `HfHub.Commit.Operation` module created
- [ ] `HfHub.Commit.Operation.Add` struct
- [ ] `HfHub.Commit.Operation.Delete` struct
- [ ] `HfHub.Commit.Operation.Copy` struct
- [ ] Path validation implemented
- [ ] `HfHub.Commit.CommitInfo` struct created
- [ ] `HfHub.Commit` skeleton created
- [ ] All tests pass
- [ ] `mix format` passes
- [ ] `mix credo --strict` passes
- [ ] `mix dialyzer` passes
- [ ] CHANGELOG.md updated
