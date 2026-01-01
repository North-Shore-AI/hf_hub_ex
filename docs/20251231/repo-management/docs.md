# Repository Management API

## Overview

Repository management provides CRUD operations for HuggingFace Hub repositories (models, datasets, spaces).

## Python Reference

### Source File
`huggingface_hub/src/huggingface_hub/hf_api.py`

### Functions

#### create_repo

```python
def create_repo(
    repo_id: str,
    *,
    token: Union[str, bool, None] = None,
    private: bool = False,
    repo_type: Optional[str] = None,
    exist_ok: bool = False,
    space_sdk: Optional[str] = None,
    space_hardware: Optional[SpaceHardware] = None,
    space_storage: Optional[SpaceStorage] = None,
    space_sleep_time: Optional[int] = None,
    space_secrets: Optional[List[Dict[str, str]]] = None,
    space_variables: Optional[List[Dict[str, str]]] = None,
) -> RepoUrl
```

**API Endpoint**: `POST /api/repos/create`

**Request Body**:
```json
{
  "name": "repo-name",
  "organization": "optional-org",
  "private": false,
  "type": "model",
  "sdk": "gradio",
  "hardware": "cpu-basic"
}
```

**Response**: `RepoUrl` containing URL and repo metadata

---

#### delete_repo

```python
def delete_repo(
    repo_id: str,
    *,
    token: Union[str, bool, None] = None,
    repo_type: Optional[str] = None,
    missing_ok: bool = False,
) -> None
```

**API Endpoint**: `DELETE /api/repos/{repo_type}s/{repo_id}`

**Response**: 200 OK (no body)

---

#### update_repo_settings

```python
def update_repo_settings(
    repo_id: str,
    *,
    private: Optional[bool] = None,
    gated: Optional[Literal["auto", "manual", False]] = None,
    token: Union[str, bool, None] = None,
    repo_type: Optional[str] = None,
) -> None
```

**API Endpoint**: `PUT /api/{repo_type}s/{repo_id}/settings`

**Request Body**:
```json
{
  "private": true,
  "gated": "auto"
}
```

---

#### move_repo

```python
def move_repo(
    from_id: str,
    to_id: str,
    *,
    repo_type: Optional[str] = None,
    token: Union[str, bool, None] = None,
) -> RepoUrl
```

**API Endpoint**: `POST /api/repos/move`

**Request Body**:
```json
{
  "fromRepo": "old-owner/old-name",
  "toRepo": "new-owner/new-name",
  "type": "model"
}
```

---

#### repo_exists

```python
def repo_exists(
    repo_id: str,
    *,
    repo_type: Optional[str] = None,
    token: Union[str, bool, None] = None,
) -> bool
```

**Implementation**: HEAD request to repo endpoint, check 200 vs 404

---

#### file_exists

```python
def file_exists(
    repo_id: str,
    filename: str,
    *,
    repo_type: Optional[str] = None,
    revision: Optional[str] = None,
    token: Union[str, bool, None] = None,
) -> bool
```

**Implementation**: HEAD request to file URL, check 200 vs 404

---

#### revision_exists

```python
def revision_exists(
    repo_id: str,
    revision: str,
    *,
    repo_type: Optional[str] = None,
    token: Union[str, bool, None] = None,
) -> bool
```

**Implementation**: GET repo info with specific revision, check success

---

## Elixir Implementation Spec

### Module: `HfHub.Repo`

```elixir
defmodule HfHub.Repo do
  @moduledoc """
  Repository management operations for HuggingFace Hub.

  Provides create, delete, update, and move operations for repositories.
  """

  @type repo_type :: :model | :dataset | :space
  @type gated :: :auto | :manual | false

  @type create_opts :: [
    token: String.t(),
    private: boolean(),
    repo_type: repo_type(),
    exist_ok: boolean(),
    space_sdk: String.t(),
    space_hardware: String.t(),
    space_storage: String.t(),
    space_sleep_time: non_neg_integer(),
    space_secrets: [%{key: String.t(), value: String.t()}],
    space_variables: [%{key: String.t(), value: String.t()}]
  ]

  @doc """
  Creates a new repository on HuggingFace Hub.

  ## Options

  - `:token` - Authentication token
  - `:private` - Whether repository is private (default: false)
  - `:repo_type` - Repository type: :model, :dataset, or :space (default: :model)
  - `:exist_ok` - Don't error if repo already exists (default: false)
  - `:space_sdk` - Space SDK: "gradio", "streamlit", "docker", "static"
  - `:space_hardware` - Space hardware: "cpu-basic", "cpu-upgrade", etc.

  ## Examples

      {:ok, url} = HfHub.Repo.create("my-org/my-model", private: true)
      {:ok, url} = HfHub.Repo.create("my-space", repo_type: :space, space_sdk: "gradio")
  """
  @spec create(String.t(), create_opts()) :: {:ok, repo_url()} | {:error, term()}
  def create(repo_id, opts \\ [])

  @doc """
  Deletes a repository from HuggingFace Hub.

  ## Options

  - `:token` - Authentication token
  - `:repo_type` - Repository type (default: :model)
  - `:missing_ok` - Don't error if repo doesn't exist (default: false)

  ## Examples

      :ok = HfHub.Repo.delete("my-org/my-model")
      :ok = HfHub.Repo.delete("old-repo", missing_ok: true)
  """
  @spec delete(String.t(), keyword()) :: :ok | {:error, term()}
  def delete(repo_id, opts \\ [])

  @doc """
  Updates repository settings.

  ## Options

  - `:token` - Authentication token
  - `:private` - Set visibility
  - `:gated` - Set gated access: :auto, :manual, or false
  - `:repo_type` - Repository type (default: :model)

  ## Examples

      :ok = HfHub.Repo.update_settings("my-model", private: true, gated: :auto)
  """
  @spec update_settings(String.t(), keyword()) :: :ok | {:error, term()}
  def update_settings(repo_id, opts \\ [])

  @doc """
  Moves/renames a repository.

  ## Options

  - `:token` - Authentication token
  - `:repo_type` - Repository type (default: :model)

  ## Examples

      {:ok, url} = HfHub.Repo.move("old-name", "new-org/new-name")
  """
  @spec move(String.t(), String.t(), keyword()) :: {:ok, repo_url()} | {:error, term()}
  def move(from_id, to_id, opts \\ [])

  @doc """
  Checks if a repository exists.

  ## Examples

      true = HfHub.Repo.exists?("bert-base-uncased")
      false = HfHub.Repo.exists?("nonexistent-model")
  """
  @spec exists?(String.t(), keyword()) :: boolean()
  def exists?(repo_id, opts \\ [])

  @doc """
  Checks if a file exists in a repository.

  ## Examples

      true = HfHub.Repo.file_exists?("bert-base-uncased", "config.json")
  """
  @spec file_exists?(String.t(), String.t(), keyword()) :: boolean()
  def file_exists?(repo_id, filename, opts \\ [])

  @doc """
  Checks if a revision (branch/tag/commit) exists.

  ## Examples

      true = HfHub.Repo.revision_exists?("bert-base-uncased", "main")
  """
  @spec revision_exists?(String.t(), String.t(), keyword()) :: boolean()
  def revision_exists?(repo_id, revision, opts \\ [])
end
```

### Data Structures

```elixir
defmodule HfHub.Repo.RepoUrl do
  @moduledoc """
  Repository URL with metadata from creation response.
  """

  defstruct [:url, :repo_id, :repo_type]

  @type t :: %__MODULE__{
    url: String.t(),
    repo_id: String.t(),
    repo_type: :model | :dataset | :space
  }
end
```

## API Endpoints Reference

| Operation | Method | Endpoint |
|-----------|--------|----------|
| Create repo | POST | `/api/repos/create` |
| Delete repo | DELETE | `/api/repos/{type}s/{repo_id}` |
| Update settings | PUT | `/api/{type}s/{repo_id}/settings` |
| Move repo | POST | `/api/repos/move` |
| Check exists | HEAD | `/{type}s/{repo_id}` |
| Check file | HEAD | `/{type}s/{repo_id}/resolve/{rev}/{file}` |

## Error Handling

| HTTP Status | Error Type | Description |
|-------------|------------|-------------|
| 401 | Unauthorized | Invalid or missing token |
| 403 | Forbidden | No permission to perform action |
| 404 | RepositoryNotFound | Repo doesn't exist |
| 409 | Conflict | Repo already exists (without exist_ok) |
| 422 | Validation | Invalid parameters |

## Test Scenarios

1. Create public model repository
2. Create private dataset repository
3. Create space with Gradio SDK
4. Delete existing repository
5. Delete with missing_ok when not found
6. Update visibility to private
7. Update gated to :auto
8. Move repository to new name
9. Move repository to different org
10. Check existence of valid repo
11. Check existence of invalid repo
12. Check file existence
13. Check revision existence
14. Error: create without token
15. Error: delete without permission
16. Error: create with invalid repo_id format
