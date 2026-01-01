# Access Requests API

## Overview

Access Requests manage user access to gated repositories that require approval.

## Python Reference

### Source File
`huggingface_hub/src/huggingface_hub/hf_api.py`

### Functions

#### list_pending_access_requests

```python
def list_pending_access_requests(
    repo_id: str,
    *,
    repo_type: Optional[str] = None,
    token: Optional[str] = None,
) -> List[AccessRequest]
```

**API Endpoint**: `GET /api/{type}s/{repo_id}/user-access-request/pending`

---

#### list_accepted_access_requests

```python
def list_accepted_access_requests(
    repo_id: str,
    *,
    repo_type: Optional[str] = None,
    token: Optional[str] = None,
) -> List[AccessRequest]
```

**API Endpoint**: `GET /api/{type}s/{repo_id}/user-access-request/accepted`

---

#### list_rejected_access_requests

```python
def list_rejected_access_requests(
    repo_id: str,
    *,
    repo_type: Optional[str] = None,
    token: Optional[str] = None,
) -> List[AccessRequest]
```

**API Endpoint**: `GET /api/{type}s/{repo_id}/user-access-request/rejected`

---

#### accept_access_request

```python
def accept_access_request(
    repo_id: str,
    user: str,
    *,
    repo_type: Optional[str] = None,
    token: Optional[str] = None,
) -> None
```

**API Endpoint**: `POST /api/{type}s/{repo_id}/user-access-request/handle`

---

#### reject_access_request

```python
def reject_access_request(
    repo_id: str,
    user: str,
    *,
    repo_type: Optional[str] = None,
    token: Optional[str] = None,
) -> None
```

**API Endpoint**: `POST /api/{type}s/{repo_id}/user-access-request/handle`

---

#### cancel_access_request

```python
def cancel_access_request(
    repo_id: str,
    user: str,
    *,
    repo_type: Optional[str] = None,
    token: Optional[str] = None,
) -> None
```

**API Endpoint**: `DELETE /api/{type}s/{repo_id}/user-access-request/handle`

---

#### grant_access

```python
def grant_access(
    repo_id: str,
    user: str,
    *,
    repo_type: Optional[str] = None,
    token: Optional[str] = None,
) -> None
```

**API Endpoint**: `POST /api/{type}s/{repo_id}/user-access-request/grant`

Grants access without a prior request.

---

## Elixir Implementation Spec

### Module: `HfHub.AccessRequests`

```elixir
defmodule HfHub.AccessRequests do
  @moduledoc """
  Access request management for gated repositories.
  """

  alias HfHub.AccessRequests.AccessRequest

  @type status :: :pending | :accepted | :rejected

  @doc """
  Lists pending access requests for a repository.
  """
  @spec list_pending(String.t(), keyword()) ::
    {:ok, [AccessRequest.t()]} | {:error, term()}
  def list_pending(repo_id, opts \\ [])

  @doc """
  Lists accepted access requests for a repository.
  """
  @spec list_accepted(String.t(), keyword()) ::
    {:ok, [AccessRequest.t()]} | {:error, term()}
  def list_accepted(repo_id, opts \\ [])

  @doc """
  Lists rejected access requests for a repository.
  """
  @spec list_rejected(String.t(), keyword()) ::
    {:ok, [AccessRequest.t()]} | {:error, term()}
  def list_rejected(repo_id, opts \\ [])

  @doc """
  Accepts a pending access request.

  ## Examples

      :ok = HfHub.AccessRequests.accept("my-model", "username")
  """
  @spec accept(String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def accept(repo_id, user, opts \\ [])

  @doc """
  Rejects a pending access request.
  """
  @spec reject(String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def reject(repo_id, user, opts \\ [])

  @doc """
  Cancels/revokes an access request or grant.
  """
  @spec cancel(String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def cancel(repo_id, user, opts \\ [])

  @doc """
  Grants access directly without a request.

  Use for proactive access grants.
  """
  @spec grant(String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def grant(repo_id, user, opts \\ [])
end
```

### Data Structures

```elixir
defmodule HfHub.AccessRequests.AccessRequest do
  defstruct [:user, :fullname, :email, :status, :timestamp, :fields]

  @type t :: %__MODULE__{
    user: String.t(),
    fullname: String.t() | nil,
    email: String.t() | nil,
    status: :pending | :accepted | :rejected,
    timestamp: DateTime.t(),
    fields: map()
  }
end
```

---

## Test Scenarios

1. List pending requests
2. List accepted requests
3. List rejected requests
4. Empty request lists
5. Accept pending request
6. Reject pending request
7. Cancel accepted access
8. Grant access directly
9. Error: accept non-existent request
10. Error: non-gated repo
11. Error: unauthorized
