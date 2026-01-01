# Git Operations API

## Overview

Git operations provide branch, tag, and commit management for HuggingFace Hub repositories.

## Python Reference

### Source File
`huggingface_hub/src/huggingface_hub/hf_api.py`

### Functions

#### create_branch

```python
def create_branch(
    repo_id: str,
    branch: str,
    *,
    token: Optional[str] = None,
    repo_type: Optional[str] = None,
    revision: Optional[str] = None,  # Source revision
    exist_ok: bool = False,
) -> BranchInfo
```

**API Endpoint**: `POST /api/{type}s/{repo_id}/branch/{branch}`

**Request Body**:
```json
{
  "startingPoint": "main"
}
```

---

#### delete_branch

```python
def delete_branch(
    repo_id: str,
    branch: str,
    *,
    token: Optional[str] = None,
    repo_type: Optional[str] = None,
) -> None
```

**API Endpoint**: `DELETE /api/{type}s/{repo_id}/branch/{branch}`

---

#### create_tag

```python
def create_tag(
    repo_id: str,
    tag: str,
    *,
    token: Optional[str] = None,
    repo_type: Optional[str] = None,
    revision: Optional[str] = None,
    tag_message: Optional[str] = None,
    exist_ok: bool = False,
) -> TagInfo
```

**API Endpoint**: `POST /api/{type}s/{repo_id}/tag/{tag}`

**Request Body**:
```json
{
  "ref": "refs/heads/main",
  "message": "Release v1.0"
}
```

---

#### delete_tag

```python
def delete_tag(
    repo_id: str,
    tag: str,
    *,
    token: Optional[str] = None,
    repo_type: Optional[str] = None,
) -> None
```

**API Endpoint**: `DELETE /api/{type}s/{repo_id}/tag/{tag}`

---

#### list_repo_refs

```python
def list_repo_refs(
    repo_id: str,
    *,
    repo_type: Optional[str] = None,
    token: Optional[str] = None,
    include_pull_requests: bool = False,
) -> GitRefs
```

**API Endpoint**: `GET /api/{type}s/{repo_id}/refs`

**Response**:
```json
{
  "branches": [
    {"name": "main", "ref": "refs/heads/main", "targetCommit": "abc123"}
  ],
  "tags": [
    {"name": "v1.0", "ref": "refs/tags/v1.0", "targetCommit": "def456"}
  ],
  "converts": [],
  "pullRequests": []
}
```

---

#### list_repo_commits

```python
def list_repo_commits(
    repo_id: str,
    *,
    repo_type: Optional[str] = None,
    token: Optional[str] = None,
    revision: Optional[str] = None,
) -> Iterable[GitCommitInfo]
```

**API Endpoint**: `GET /api/{type}s/{repo_id}/commits/{revision}`

**Response**:
```json
[
  {
    "id": "abc123def456...",
    "title": "Initial commit",
    "message": "Full commit message",
    "authors": [{"name": "User", "email": "user@example.com"}],
    "date": "2024-01-15T10:30:00Z"
  }
]
```

---

#### super_squash_history

```python
def super_squash_history(
    repo_id: str,
    *,
    token: Optional[str] = None,
    repo_type: Optional[str] = None,
    branch: Optional[str] = None,
    commit_message: Optional[str] = None,
) -> None
```

**API Endpoint**: `POST /api/{type}s/{repo_id}/super-squash`

Squashes all commits into a single commit. Used to reduce repository size.

---

## Elixir Implementation Spec

### Module: `HfHub.Git`

```elixir
defmodule HfHub.Git do
  @moduledoc """
  Git operations for HuggingFace Hub repositories.

  Provides branch, tag, and commit management.
  """

  alias HfHub.Git.{BranchInfo, TagInfo, GitRefs, CommitInfo}

  @type repo_type :: :model | :dataset | :space

  # Branch Operations

  @doc """
  Creates a new branch in a repository.

  ## Options

  - `:token` - Authentication token
  - `:repo_type` - Repository type (default: :model)
  - `:revision` - Source revision to branch from (default: "main")
  - `:exist_ok` - Don't error if branch exists (default: false)

  ## Examples

      {:ok, info} = HfHub.Git.create_branch("my-model", "feature-branch")
      {:ok, info} = HfHub.Git.create_branch("my-model", "hotfix", revision: "v1.0")
  """
  @spec create_branch(String.t(), String.t(), keyword()) ::
    {:ok, BranchInfo.t()} | {:error, term()}
  def create_branch(repo_id, branch, opts \\ [])

  @doc """
  Deletes a branch from a repository.

  ## Examples

      :ok = HfHub.Git.delete_branch("my-model", "old-branch")
  """
  @spec delete_branch(String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def delete_branch(repo_id, branch, opts \\ [])

  # Tag Operations

  @doc """
  Creates a new tag in a repository.

  ## Options

  - `:token` - Authentication token
  - `:repo_type` - Repository type (default: :model)
  - `:revision` - Revision to tag (default: "main")
  - `:message` - Optional tag message (annotated tag)
  - `:exist_ok` - Don't error if tag exists (default: false)

  ## Examples

      {:ok, info} = HfHub.Git.create_tag("my-model", "v1.0")
      {:ok, info} = HfHub.Git.create_tag("my-model", "v2.0",
        revision: "abc123", message: "Release v2.0")
  """
  @spec create_tag(String.t(), String.t(), keyword()) ::
    {:ok, TagInfo.t()} | {:error, term()}
  def create_tag(repo_id, tag, opts \\ [])

  @doc """
  Deletes a tag from a repository.

  ## Examples

      :ok = HfHub.Git.delete_tag("my-model", "old-tag")
  """
  @spec delete_tag(String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def delete_tag(repo_id, tag, opts \\ [])

  # Ref Listing

  @doc """
  Lists all refs (branches, tags) in a repository.

  ## Options

  - `:token` - Authentication token
  - `:repo_type` - Repository type (default: :model)
  - `:include_pull_requests` - Include PR refs (default: false)

  ## Examples

      {:ok, refs} = HfHub.Git.list_refs("bert-base-uncased")
      refs.branches  # [%BranchInfo{name: "main", ...}]
      refs.tags      # [%TagInfo{name: "v1.0", ...}]
  """
  @spec list_refs(String.t(), keyword()) :: {:ok, GitRefs.t()} | {:error, term()}
  def list_refs(repo_id, opts \\ [])

  # Commit History

  @doc """
  Lists commits in a repository.

  ## Options

  - `:token` - Authentication token
  - `:repo_type` - Repository type (default: :model)
  - `:revision` - Branch/tag/commit to list from (default: "main")

  ## Examples

      {:ok, commits} = HfHub.Git.list_commits("bert-base-uncased")
      Enum.take(commits, 10)  # First 10 commits
  """
  @spec list_commits(String.t(), keyword()) ::
    {:ok, Enumerable.t(CommitInfo.t())} | {:error, term()}
  def list_commits(repo_id, opts \\ [])

  # History Management

  @doc """
  Squashes all commits into a single commit.

  WARNING: This is a destructive operation. Use with caution.

  ## Options

  - `:token` - Authentication token (required)
  - `:repo_type` - Repository type (default: :model)
  - `:branch` - Branch to squash (default: "main")
  - `:message` - Commit message for squashed commit

  ## Examples

      :ok = HfHub.Git.super_squash("my-model", message: "Squashed history")
  """
  @spec super_squash(String.t(), keyword()) :: :ok | {:error, term()}
  def super_squash(repo_id, opts \\ [])
end
```

### Data Structures

```elixir
defmodule HfHub.Git.BranchInfo do
  defstruct [:name, :ref, :target_commit]

  @type t :: %__MODULE__{
    name: String.t(),
    ref: String.t(),
    target_commit: String.t()
  }
end

defmodule HfHub.Git.TagInfo do
  defstruct [:name, :ref, :target_commit, :message]

  @type t :: %__MODULE__{
    name: String.t(),
    ref: String.t(),
    target_commit: String.t(),
    message: String.t() | nil
  }
end

defmodule HfHub.Git.GitRefs do
  defstruct [:branches, :tags, :converts, :pull_requests]

  @type t :: %__MODULE__{
    branches: [HfHub.Git.BranchInfo.t()],
    tags: [HfHub.Git.TagInfo.t()],
    converts: [map()],
    pull_requests: [map()]
  }
end

defmodule HfHub.Git.CommitInfo do
  defstruct [:id, :title, :message, :authors, :date]

  @type author :: %{name: String.t(), email: String.t()}

  @type t :: %__MODULE__{
    id: String.t(),
    title: String.t(),
    message: String.t(),
    authors: [author()],
    date: DateTime.t()
  }
end
```

---

## API Endpoints Reference

| Operation | Method | Endpoint |
|-----------|--------|----------|
| Create branch | POST | `/api/{type}s/{repo}/branch/{branch}` |
| Delete branch | DELETE | `/api/{type}s/{repo}/branch/{branch}` |
| Create tag | POST | `/api/{type}s/{repo}/tag/{tag}` |
| Delete tag | DELETE | `/api/{type}s/{repo}/tag/{tag}` |
| List refs | GET | `/api/{type}s/{repo}/refs` |
| List commits | GET | `/api/{type}s/{repo}/commits/{revision}` |
| Super squash | POST | `/api/{type}s/{repo}/super-squash` |

---

## Test Scenarios

### Branch Operations
1. Create branch from main
2. Create branch from specific commit
3. Create branch with exist_ok
4. Delete existing branch
5. Error: create branch without token
6. Error: delete protected branch (main)

### Tag Operations
1. Create lightweight tag
2. Create annotated tag with message
3. Create tag from specific revision
4. Delete tag
5. Error: create tag without token

### Ref Listing
1. List refs for public repo
2. List refs with pull requests
3. List refs for private repo with token
4. Empty repo (no refs)

### Commit History
1. List commits from main
2. List commits from specific branch
3. List commits from tag
4. Paginate through many commits

### Super Squash
1. Squash repository history
2. Squash with custom message
3. Error: squash without write permission
