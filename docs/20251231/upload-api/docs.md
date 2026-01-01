# Upload API (Commit Operations)

## Overview

The Upload API enables pushing files to HuggingFace Hub repositories through a commit-based system. It supports regular file uploads (base64-encoded) and Large File Storage (LFS) for files over 10MB.

## Python Reference

### Source Files
- `huggingface_hub/src/huggingface_hub/_commit_api.py`
- `huggingface_hub/src/huggingface_hub/lfs.py`
- `huggingface_hub/src/huggingface_hub/_upload_large_folder.py`

### Commit Operations

#### CommitOperationAdd

```python
@dataclass
class CommitOperationAdd:
    path_in_repo: str
    path_or_fileobj: Union[str, Path, bytes, BinaryIO]
    upload_info: UploadInfo  # sha256, size, sample (first 512 bytes)

    # Internal state
    _upload_mode: Optional[UploadMode]  # "lfs" or "regular"
    _remote_oid: Optional[str]  # For existing LFS files
    _is_uploaded: bool
    _is_committed: bool
```

#### CommitOperationDelete

```python
@dataclass
class CommitOperationDelete:
    path_in_repo: str
    is_folder: Union[bool, Literal["auto"]] = "auto"
```

#### CommitOperationCopy

```python
@dataclass
class CommitOperationCopy:
    src_path_in_repo: str
    path_in_repo: str
    src_revision: Optional[str] = None
```

### UploadInfo

```python
class UploadInfo:
    sha256: bytes          # SHA256 hash of content
    size: int              # File size in bytes
    sample: bytes          # First 512 bytes for content detection

    @classmethod
    def from_path(cls, path: str) -> "UploadInfo"

    @classmethod
    def from_bytes(cls, data: bytes) -> "UploadInfo"

    @classmethod
    def from_fileobj(cls, fileobj: BinaryIO) -> "UploadInfo"
```

### API Functions

#### upload_file

```python
def upload_file(
    path_or_fileobj: Union[str, Path, bytes, BinaryIO],
    path_in_repo: str,
    repo_id: str,
    *,
    token: Optional[str] = None,
    repo_type: Optional[str] = None,
    revision: Optional[str] = None,
    commit_message: Optional[str] = None,
    commit_description: Optional[str] = None,
    create_pr: bool = False,
    parent_commit: Optional[str] = None,
) -> CommitInfo
```

#### upload_folder

```python
def upload_folder(
    folder_path: Union[str, Path],
    repo_id: str,
    *,
    token: Optional[str] = None,
    repo_type: Optional[str] = None,
    revision: Optional[str] = None,
    commit_message: Optional[str] = None,
    commit_description: Optional[str] = None,
    create_pr: bool = False,
    parent_commit: Optional[str] = None,
    allow_patterns: Optional[Union[List[str], str]] = None,
    ignore_patterns: Optional[Union[List[str], str]] = None,
    delete_patterns: Optional[Union[List[str], str]] = None,
    multi_commits: bool = False,
    multi_commits_verbose: bool = False,
) -> Union[CommitInfo, str]
```

#### create_commit

```python
def create_commit(
    repo_id: str,
    operations: Iterable[Union[CommitOperationAdd, CommitOperationDelete, CommitOperationCopy]],
    *,
    commit_message: str,
    commit_description: Optional[str] = None,
    token: Optional[str] = None,
    repo_type: Optional[str] = None,
    revision: Optional[str] = None,
    create_pr: bool = False,
    parent_commit: Optional[str] = None,
    run_as_future: bool = False,
) -> Union[CommitInfo, Future[CommitInfo]]
```

### LFS Upload Protocol

#### post_lfs_batch_info

```python
def post_lfs_batch_info(
    upload_infos: Iterable[UploadInfo],
    token: Optional[str],
    repo_type: str,
    repo_id: str,
    revision: Optional[str] = None,
) -> Tuple[List[dict], List[dict], Optional[str]]
# Returns: (upload_actions, errors, transfer_adapter)
```

**Endpoint**: `POST /{repo_id}.git/info/lfs/objects/batch`

**Request**:
```json
{
  "operation": "upload",
  "transfers": ["basic", "multipart"],
  "objects": [
    {"oid": "sha256hex", "size": 12345}
  ],
  "hash_algo": "sha256"
}
```

**Response**:
```json
{
  "transfer": "basic",
  "objects": [
    {
      "oid": "sha256hex",
      "size": 12345,
      "actions": {
        "upload": {
          "href": "https://...",
          "header": {"Authorization": "..."}
        }
      }
    }
  ]
}
```

#### lfs_upload

```python
def lfs_upload(
    upload_info: UploadInfo,
    upload_action: dict,
    verify_action: Optional[dict] = None,
) -> None
```

**Single Part Upload**: PUT to href with raw file content
**Multipart Upload**:
1. PUT parts to numbered URLs
2. POST completion with ETags

---

## Elixir Implementation Spec

### Module: `HfHub.Commit`

```elixir
defmodule HfHub.Commit do
  @moduledoc """
  Commit operations for uploading files to HuggingFace Hub.

  Supports regular uploads (base64) and LFS (Git Large File Storage)
  for files over 10MB.
  """

  alias HfHub.Commit.{Operation, CommitInfo}

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

  ## Operations

  - `Operation.add/2` - Add or update a file
  - `Operation.delete/2` - Delete a file or folder
  - `Operation.copy/3` - Copy an existing LFS file

  ## Examples

      {:ok, info} = HfHub.Commit.create("my-model", [
        Operation.add("model.safetensors", "/path/to/model.safetensors"),
        Operation.add("config.json", ~s({"hidden_size": 768})),
        Operation.delete("old_model.bin")
      ], commit_message: "Update model")
  """
  @spec create(String.t(), [Operation.t()], commit_opts()) ::
    {:ok, CommitInfo.t()} | {:error, term()}
  def create(repo_id, operations, opts \\ [])

  @doc """
  Uploads a single file to a repository.

  Convenience wrapper around `create/3` for single file uploads.

  ## Examples

      {:ok, info} = HfHub.Commit.upload_file(
        "/path/to/model.bin",
        "model.bin",
        "my-org/my-model",
        commit_message: "Add model weights"
      )

      # From binary data
      {:ok, info} = HfHub.Commit.upload_file(
        config_json,
        "config.json",
        "my-model"
      )
  """
  @spec upload_file(binary() | Path.t(), String.t(), String.t(), commit_opts()) ::
    {:ok, CommitInfo.t()} | {:error, term()}
  def upload_file(path_or_data, path_in_repo, repo_id, opts \\ [])

  @doc """
  Uploads an entire folder to a repository.

  ## Options

  - `:allow_patterns` - Only include files matching patterns
  - `:ignore_patterns` - Exclude files matching patterns
  - `:delete_patterns` - Delete remote files matching patterns

  ## Examples

      {:ok, info} = HfHub.Commit.upload_folder(
        "/path/to/model_dir",
        "my-org/my-model",
        commit_message: "Upload model",
        ignore_patterns: ["*.pyc", "__pycache__"]
      )
  """
  @spec upload_folder(Path.t(), String.t(), commit_opts()) ::
    {:ok, CommitInfo.t()} | {:error, term()}
  def upload_folder(folder_path, repo_id, opts \\ [])

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

  @doc """
  Deletes a folder and all its contents from a repository.
  """
  @spec delete_folder(String.t(), String.t(), commit_opts()) ::
    {:ok, CommitInfo.t()} | {:error, term()}
  def delete_folder(path_in_repo, repo_id, opts \\ [])
end
```

### Module: `HfHub.Commit.Operation`

```elixir
defmodule HfHub.Commit.Operation do
  @moduledoc """
  Commit operation types for file manipulation.
  """

  @type t :: add() | delete() | copy()

  @type add :: %__MODULE__.Add{
    path_in_repo: String.t(),
    content: binary() | Path.t(),
    upload_info: HfHub.LFS.UploadInfo.t()
  }

  @type delete :: %__MODULE__.Delete{
    path_in_repo: String.t(),
    is_folder: boolean()
  }

  @type copy :: %__MODULE__.Copy{
    src_path: String.t(),
    dst_path: String.t(),
    src_revision: String.t() | nil
  }

  defmodule Add do
    defstruct [:path_in_repo, :content, :upload_info, :upload_mode, :is_uploaded]
  end

  defmodule Delete do
    defstruct [:path_in_repo, is_folder: false]
  end

  defmodule Copy do
    defstruct [:src_path, :dst_path, :src_revision]
  end

  @doc """
  Creates an add operation from a file path or binary content.

  ## Examples

      Operation.add("config.json", "/path/to/config.json")
      Operation.add("config.json", ~s({"hidden_size": 768}))
  """
  @spec add(String.t(), binary() | Path.t()) :: add()
  def add(path_in_repo, content)

  @doc """
  Creates a delete operation.

  ## Examples

      Operation.delete("old_file.bin")
      Operation.delete("old_folder", is_folder: true)
  """
  @spec delete(String.t(), keyword()) :: delete()
  def delete(path_in_repo, opts \\ [])

  @doc """
  Creates a copy operation for an existing LFS file.

  ## Examples

      Operation.copy("v1/model.bin", "v2/model.bin")
      Operation.copy("model.bin", "backup/model.bin", src_revision: "v1.0")
  """
  @spec copy(String.t(), String.t(), keyword()) :: copy()
  def copy(src_path, dst_path, opts \\ [])
end
```

### Module: `HfHub.Commit.LfsUpload`

```elixir
defmodule HfHub.Commit.LfsUpload do
  @moduledoc """
  Git LFS upload protocol implementation.
  """

  alias HfHub.LFS.UploadInfo

  @type batch_response :: %{
    transfer: String.t(),
    objects: [%{
      oid: String.t(),
      size: non_neg_integer(),
      actions: %{
        upload: %{href: String.t(), header: map()},
        verify: %{href: String.t(), header: map()} | nil
      }
    }]
  }

  @doc """
  Requests upload instructions for LFS objects.

  Returns upload URLs and headers for each object that needs uploading.
  Objects already on server will not have upload actions.
  """
  @spec batch_info(String.t(), [UploadInfo.t()], keyword()) ::
    {:ok, batch_response()} | {:error, term()}
  def batch_info(repo_id, upload_infos, opts \\ [])

  @doc """
  Uploads a single LFS object using the provided action.

  Handles both single-part and multipart uploads based on server response.
  """
  @spec upload(UploadInfo.t(), map(), keyword()) :: :ok | {:error, term()}
  def upload(upload_info, action, opts \\ [])

  @doc """
  Uploads multiple LFS objects concurrently.

  ## Options

  - `:max_concurrency` - Maximum parallel uploads (default: 4)
  """
  @spec upload_batch([{UploadInfo.t(), map()}], keyword()) ::
    :ok | {:error, term()}
  def upload_batch(uploads, opts \\ [])
end
```

### Module: `HfHub.Commit.CommitInfo`

```elixir
defmodule HfHub.Commit.CommitInfo do
  @moduledoc """
  Information about a completed commit.
  """

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
end
```

---

## API Flow

### Regular Upload Flow (< 10MB)

```
1. Compute UploadInfo (sha256, size, sample)
2. POST /api/{type}s/{repo}/commit/{revision}
   Body: {
     "operations": [{
       "key": "path/in/repo.txt",
       "value": {
         "content": "base64-encoded-content",
         "encoding": "base64"
       }
     }],
     "commit": {
       "message": "Commit message",
       "description": "Optional description"
     }
   }
3. Return CommitInfo
```

### LFS Upload Flow (>= 10MB)

```
1. Compute UploadInfo for all files
2. POST /{repo}.git/info/lfs/objects/batch
   → Get upload URLs for each object
3. For each object with upload action:
   - Single part: PUT content to href
   - Multipart: PUT parts, POST completion
4. POST /api/{type}s/{repo}/commit/{revision}
   Body: {
     "operations": [{
       "key": "path/in/repo.bin",
       "value": {
         "lfs": {
           "oid": "sha256hex",
           "size": 123456789
         }
       }
     }],
     "commit": {...}
   }
5. Return CommitInfo
```

---

## Size Thresholds

| Size | Upload Mode | Details |
|------|-------------|---------|
| < 10MB | Regular | Base64 encoded in commit body |
| >= 10MB | LFS | Upload via LFS batch API |
| >= 50MB | LFS Multipart | Chunked upload |

---

## Test Scenarios

### Regular Uploads
1. Upload small text file (< 10MB)
2. Upload from binary content
3. Upload from file path
4. Upload with custom commit message
5. Upload to specific revision
6. Upload creating a PR

### LFS Uploads
1. Upload large file (> 10MB)
2. Upload very large file with multipart
3. Skip upload for existing LFS object
4. Verify upload with verify action
5. Handle upload failure and retry

### Folder Uploads
1. Upload entire folder
2. Upload with allow_patterns
3. Upload with ignore_patterns
4. Upload with delete_patterns
5. Handle nested directories

### Delete Operations
1. Delete single file
2. Delete folder
3. Delete multiple files in one commit

### Copy Operations
1. Copy file within same revision
2. Copy file from different revision

### Error Handling
1. Invalid path_in_repo (traversal)
2. File too large for regular upload
3. LFS batch request failure
4. LFS upload failure
5. Commit validation failure
6. Authentication failure
