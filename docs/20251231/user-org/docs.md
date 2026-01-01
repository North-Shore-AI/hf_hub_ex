# User & Organization API

## Overview

The User and Organization API provides profile information, followers, and activity data.

## Python Reference

### Source File
`huggingface_hub/src/huggingface_hub/hf_api.py`

### Functions

#### get_user_overview

```python
def get_user_overview(
    username: str,
    *,
    token: Optional[str] = None,
) -> User
```

**API Endpoint**: `GET /api/users/{username}`

---

#### get_organization_overview

```python
def get_organization_overview(
    organization: str,
    *,
    token: Optional[str] = None,
) -> Organization
```

**API Endpoint**: `GET /api/organizations/{organization}`

---

#### list_user_followers

```python
def list_user_followers(
    username: str,
    *,
    token: Optional[str] = None,
) -> Iterable[User]
```

**API Endpoint**: `GET /api/users/{username}/followers`

---

#### list_user_following

```python
def list_user_following(
    username: str,
    *,
    token: Optional[str] = None,
) -> Iterable[User]
```

**API Endpoint**: `GET /api/users/{username}/following`

---

#### list_organization_members

```python
def list_organization_members(
    organization: str,
    *,
    token: Optional[str] = None,
) -> Iterable[User]
```

**API Endpoint**: `GET /api/organizations/{organization}/members`

---

#### like

```python
def like(
    repo_id: str,
    *,
    repo_type: Optional[str] = None,
    token: Optional[str] = None,
) -> None
```

**API Endpoint**: `POST /api/{type}s/{repo_id}/like`

---

#### unlike

```python
def unlike(
    repo_id: str,
    *,
    repo_type: Optional[str] = None,
    token: Optional[str] = None,
) -> None
```

**API Endpoint**: `DELETE /api/{type}s/{repo_id}/like`

---

#### list_liked_repos

```python
def list_liked_repos(
    username: Optional[str] = None,
    *,
    token: Optional[str] = None,
) -> Iterable[str]
```

**API Endpoint**: `GET /api/users/{username}/likes`

---

#### list_repo_likers

```python
def list_repo_likers(
    repo_id: str,
    *,
    repo_type: Optional[str] = None,
    token: Optional[str] = None,
) -> Iterable[User]
```

**API Endpoint**: `GET /api/{type}s/{repo_id}/likers`

---

## Elixir Implementation Spec

### Module: `HfHub.Users`

```elixir
defmodule HfHub.Users do
  @moduledoc """
  User profile and activity API.
  """

  alias HfHub.Users.{User, Organization}

  @doc """
  Gets a user's public profile.
  """
  @spec get(String.t(), keyword()) :: {:ok, User.t()} | {:error, term()}
  def get(username, opts \\ [])

  @doc """
  Lists users who follow a user.
  """
  @spec list_followers(String.t(), keyword()) ::
    {:ok, Enumerable.t(User.t())} | {:error, term()}
  def list_followers(username, opts \\ [])

  @doc """
  Lists users a user is following.
  """
  @spec list_following(String.t(), keyword()) ::
    {:ok, Enumerable.t(User.t())} | {:error, term()}
  def list_following(username, opts \\ [])

  @doc """
  Lists repositories liked by a user.
  """
  @spec list_liked_repos(String.t(), keyword()) ::
    {:ok, Enumerable.t(String.t())} | {:error, term()}
  def list_liked_repos(username, opts \\ [])

  @doc """
  Likes a repository.
  """
  @spec like(String.t(), keyword()) :: :ok | {:error, term()}
  def like(repo_id, opts \\ [])

  @doc """
  Unlikes a repository.
  """
  @spec unlike(String.t(), keyword()) :: :ok | {:error, term()}
  def unlike(repo_id, opts \\ [])

  @doc """
  Lists users who liked a repository.
  """
  @spec list_likers(String.t(), keyword()) ::
    {:ok, Enumerable.t(User.t())} | {:error, term()}
  def list_likers(repo_id, opts \\ [])
end
```

### Module: `HfHub.Organizations`

```elixir
defmodule HfHub.Organizations do
  @moduledoc """
  Organization profile API.
  """

  alias HfHub.Users.{User, Organization}

  @doc """
  Gets an organization's public profile.
  """
  @spec get(String.t(), keyword()) :: {:ok, Organization.t()} | {:error, term()}
  def get(org_name, opts \\ [])

  @doc """
  Lists members of an organization.
  """
  @spec list_members(String.t(), keyword()) ::
    {:ok, Enumerable.t(User.t())} | {:error, term()}
  def list_members(org_name, opts \\ [])
end
```

### Data Structures

```elixir
defmodule HfHub.Users.User do
  defstruct [
    :username,
    :fullname,
    :avatar_url,
    :details,
    :is_following,
    :num_followers,
    :num_following,
    :num_models,
    :num_datasets,
    :num_spaces,
    :num_likes
  ]

  @type t :: %__MODULE__{
    username: String.t(),
    fullname: String.t() | nil,
    avatar_url: String.t() | nil,
    details: String.t() | nil,
    is_following: boolean() | nil,
    num_followers: non_neg_integer(),
    num_following: non_neg_integer(),
    num_models: non_neg_integer(),
    num_datasets: non_neg_integer(),
    num_spaces: non_neg_integer(),
    num_likes: non_neg_integer()
  }
end

defmodule HfHub.Users.Organization do
  defstruct [
    :name,
    :fullname,
    :avatar_url,
    :details,
    :num_members,
    :num_models,
    :num_datasets,
    :num_spaces
  ]

  @type t :: %__MODULE__{
    name: String.t(),
    fullname: String.t() | nil,
    avatar_url: String.t() | nil,
    details: String.t() | nil,
    num_members: non_neg_integer(),
    num_models: non_neg_integer(),
    num_datasets: non_neg_integer(),
    num_spaces: non_neg_integer()
  }
end
```

---

## Test Scenarios

1. Get user profile
2. Get organization profile
3. List user followers
4. List user following
5. List organization members
6. Like repository
7. Unlike repository
8. Like already-liked repo (idempotent)
9. List liked repos
10. List repo likers
11. Error: non-existent user
12. Error: private org without access
