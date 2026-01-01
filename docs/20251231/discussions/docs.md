# Discussions & Pull Requests API

## Overview

The Discussions API enables community interaction on HuggingFace Hub repositories, including discussions, pull requests, and comments.

## Python Reference

### Source File
`huggingface_hub/src/huggingface_hub/hf_api.py`

### Functions

#### get_repo_discussions

```python
def get_repo_discussions(
    repo_id: str,
    *,
    repo_type: Optional[str] = None,
    token: Optional[str] = None,
    author: Optional[str] = None,
    status: Optional[Literal["open", "closed", "merged", "draft", "all"]] = None,
) -> Iterable[Discussion]
```

**API Endpoint**: `GET /api/{type}s/{repo_id}/discussions`

---

#### get_discussion_details

```python
def get_discussion_details(
    repo_id: str,
    discussion_num: int,
    *,
    repo_type: Optional[str] = None,
    token: Optional[str] = None,
) -> DiscussionWithDetails
```

**API Endpoint**: `GET /api/{type}s/{repo_id}/discussions/{num}`

---

#### create_discussion

```python
def create_discussion(
    repo_id: str,
    title: str,
    *,
    token: Optional[str] = None,
    description: Optional[str] = None,
    repo_type: Optional[str] = None,
    pull_request: bool = False,
) -> DiscussionWithDetails
```

**API Endpoint**: `POST /api/{type}s/{repo_id}/discussions`

**Request Body**:
```json
{
  "title": "Discussion title",
  "description": "Optional description",
  "pullRequest": false
}
```

---

#### create_pull_request

```python
def create_pull_request(
    repo_id: str,
    title: str,
    *,
    token: Optional[str] = None,
    description: Optional[str] = None,
    repo_type: Optional[str] = None,
) -> DiscussionWithDetails
```

Convenience wrapper for `create_discussion` with `pull_request=True`.

---

#### comment_discussion

```python
def comment_discussion(
    repo_id: str,
    discussion_num: int,
    comment: str,
    *,
    token: Optional[str] = None,
    repo_type: Optional[str] = None,
) -> DiscussionComment
```

**API Endpoint**: `POST /api/{type}s/{repo_id}/discussions/{num}/comment`

---

#### edit_discussion_comment

```python
def edit_discussion_comment(
    repo_id: str,
    discussion_num: int,
    comment_id: str,
    new_content: str,
    *,
    token: Optional[str] = None,
    repo_type: Optional[str] = None,
) -> DiscussionComment
```

**API Endpoint**: `PUT /api/{type}s/{repo_id}/discussions/{num}/comment/{id}`

---

#### hide_discussion_comment

```python
def hide_discussion_comment(
    repo_id: str,
    discussion_num: int,
    comment_id: str,
    *,
    token: Optional[str] = None,
    repo_type: Optional[str] = None,
) -> DiscussionComment
```

**API Endpoint**: `PUT /api/{type}s/{repo_id}/discussions/{num}/comment/{id}/hide`

---

#### change_discussion_status

```python
def change_discussion_status(
    repo_id: str,
    discussion_num: int,
    new_status: Literal["open", "closed"],
    *,
    token: Optional[str] = None,
    repo_type: Optional[str] = None,
    comment: Optional[str] = None,
) -> Discussion
```

**API Endpoint**: `PUT /api/{type}s/{repo_id}/discussions/{num}/status`

---

#### rename_discussion

```python
def rename_discussion(
    repo_id: str,
    discussion_num: int,
    new_title: str,
    *,
    token: Optional[str] = None,
    repo_type: Optional[str] = None,
) -> DiscussionTitleChange
```

**API Endpoint**: `PUT /api/{type}s/{repo_id}/discussions/{num}/title`

---

#### merge_pull_request

```python
def merge_pull_request(
    repo_id: str,
    discussion_num: int,
    *,
    token: Optional[str] = None,
    repo_type: Optional[str] = None,
    comment: Optional[str] = None,
) -> Discussion
```

**API Endpoint**: `POST /api/{type}s/{repo_id}/discussions/{num}/merge`

---

## Elixir Implementation Spec

### Module: `HfHub.Discussions`

```elixir
defmodule HfHub.Discussions do
  @moduledoc """
  Discussions and Pull Requests API for HuggingFace Hub.
  """

  alias HfHub.Discussions.{Discussion, DiscussionDetails, Comment}

  @type status :: :open | :closed | :merged | :draft | :all
  @type repo_type :: :model | :dataset | :space

  @doc """
  Lists discussions for a repository.

  ## Options

  - `:token` - Authentication token
  - `:repo_type` - Repository type (default: :model)
  - `:author` - Filter by author username
  - `:status` - Filter by status (:open, :closed, :merged, :draft, :all)

  ## Examples

      {:ok, discussions} = HfHub.Discussions.list("bert-base-uncased")
      {:ok, open} = HfHub.Discussions.list("my-model", status: :open)
  """
  @spec list(String.t(), keyword()) ::
    {:ok, Enumerable.t(Discussion.t())} | {:error, term()}
  def list(repo_id, opts \\ [])

  @doc """
  Gets details for a specific discussion.

  Includes full content and all comments/events.

  ## Examples

      {:ok, details} = HfHub.Discussions.get("my-model", 42)
      details.events  # List of comments, status changes, etc.
  """
  @spec get(String.t(), non_neg_integer(), keyword()) ::
    {:ok, DiscussionDetails.t()} | {:error, term()}
  def get(repo_id, discussion_num, opts \\ [])

  @doc """
  Creates a new discussion.

  ## Options

  - `:token` - Authentication token (required)
  - `:description` - Discussion body/description
  - `:repo_type` - Repository type (default: :model)

  ## Examples

      {:ok, disc} = HfHub.Discussions.create("my-model", "Feature request",
        description: "Please add support for...")
  """
  @spec create(String.t(), String.t(), keyword()) ::
    {:ok, DiscussionDetails.t()} | {:error, term()}
  def create(repo_id, title, opts \\ [])

  @doc """
  Creates a new pull request.

  ## Examples

      {:ok, pr} = HfHub.Discussions.create_pr("my-model", "Add new feature",
        description: "This PR adds...")
  """
  @spec create_pr(String.t(), String.t(), keyword()) ::
    {:ok, DiscussionDetails.t()} | {:error, term()}
  def create_pr(repo_id, title, opts \\ [])

  @doc """
  Adds a comment to a discussion.

  ## Examples

      {:ok, comment} = HfHub.Discussions.comment("my-model", 42, "Thanks for reporting!")
  """
  @spec comment(String.t(), non_neg_integer(), String.t(), keyword()) ::
    {:ok, Comment.t()} | {:error, term()}
  def comment(repo_id, discussion_num, content, opts \\ [])

  @doc """
  Edits an existing comment.
  """
  @spec edit_comment(String.t(), non_neg_integer(), String.t(), String.t(), keyword()) ::
    {:ok, Comment.t()} | {:error, term()}
  def edit_comment(repo_id, discussion_num, comment_id, new_content, opts \\ [])

  @doc """
  Hides a comment from view.
  """
  @spec hide_comment(String.t(), non_neg_integer(), String.t(), keyword()) ::
    {:ok, Comment.t()} | {:error, term()}
  def hide_comment(repo_id, discussion_num, comment_id, opts \\ [])

  @doc """
  Changes the status of a discussion (open/close).

  ## Options

  - `:comment` - Optional comment explaining status change

  ## Examples

      {:ok, disc} = HfHub.Discussions.close("my-model", 42, comment: "Fixed in v2.0")
      {:ok, disc} = HfHub.Discussions.reopen("my-model", 42)
  """
  @spec change_status(String.t(), non_neg_integer(), status(), keyword()) ::
    {:ok, Discussion.t()} | {:error, term()}
  def change_status(repo_id, discussion_num, new_status, opts \\ [])

  def close(repo_id, discussion_num, opts \\ [])
  def reopen(repo_id, discussion_num, opts \\ [])

  @doc """
  Renames a discussion.
  """
  @spec rename(String.t(), non_neg_integer(), String.t(), keyword()) ::
    {:ok, Discussion.t()} | {:error, term()}
  def rename(repo_id, discussion_num, new_title, opts \\ [])

  @doc """
  Merges a pull request.

  ## Options

  - `:comment` - Optional merge comment

  ## Examples

      {:ok, pr} = HfHub.Discussions.merge_pr("my-model", 42)
  """
  @spec merge_pr(String.t(), non_neg_integer(), keyword()) ::
    {:ok, Discussion.t()} | {:error, term()}
  def merge_pr(repo_id, discussion_num, opts \\ [])
end
```

### Data Structures

```elixir
defmodule HfHub.Discussions.Discussion do
  defstruct [
    :num,
    :title,
    :author,
    :status,
    :is_pull_request,
    :created_at,
    :updated_at,
    :num_comments
  ]

  @type t :: %__MODULE__{
    num: non_neg_integer(),
    title: String.t(),
    author: String.t(),
    status: :open | :closed | :merged | :draft,
    is_pull_request: boolean(),
    created_at: DateTime.t(),
    updated_at: DateTime.t(),
    num_comments: non_neg_integer()
  }
end

defmodule HfHub.Discussions.DiscussionDetails do
  defstruct [
    :num,
    :title,
    :author,
    :status,
    :is_pull_request,
    :created_at,
    :updated_at,
    :events,
    :target_branch,
    :head_sha
  ]

  @type event ::
    HfHub.Discussions.Comment.t()
    | HfHub.Discussions.StatusChange.t()
    | HfHub.Discussions.TitleChange.t()

  @type t :: %__MODULE__{
    num: non_neg_integer(),
    title: String.t(),
    author: String.t(),
    status: :open | :closed | :merged | :draft,
    is_pull_request: boolean(),
    created_at: DateTime.t(),
    updated_at: DateTime.t(),
    events: [event()],
    target_branch: String.t() | nil,
    head_sha: String.t() | nil
  }
end

defmodule HfHub.Discussions.Comment do
  defstruct [:id, :author, :content, :hidden, :created_at, :updated_at]

  @type t :: %__MODULE__{
    id: String.t(),
    author: String.t(),
    content: String.t(),
    hidden: boolean(),
    created_at: DateTime.t(),
    updated_at: DateTime.t()
  }
end

defmodule HfHub.Discussions.StatusChange do
  defstruct [:id, :author, :status, :comment, :created_at]

  @type t :: %__MODULE__{
    id: String.t(),
    author: String.t(),
    status: :open | :closed | :merged,
    comment: String.t() | nil,
    created_at: DateTime.t()
  }
end

defmodule HfHub.Discussions.TitleChange do
  defstruct [:id, :author, :old_title, :new_title, :created_at]

  @type t :: %__MODULE__{
    id: String.t(),
    author: String.t(),
    old_title: String.t(),
    new_title: String.t(),
    created_at: DateTime.t()
  }
end
```

---

## Test Scenarios

1. List all discussions
2. List filtered by status
3. List filtered by author
4. Get discussion details
5. Create new discussion
6. Create pull request
7. Add comment
8. Edit comment
9. Hide comment
10. Close discussion with comment
11. Reopen discussion
12. Rename discussion
13. Merge pull request
14. Error: merge non-PR discussion
15. Error: create without token
