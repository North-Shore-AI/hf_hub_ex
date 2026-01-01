# Prompt 12: Access Requests API

## Context

You are implementing Access Request management for `hf_hub_ex`. This manages user access to gated repositories.

**Prerequisites**: Prompts 01-02 must be completed.

## Required Reading

```
lib/hf_hub/http.ex
docs/20251231/access-requests/docs.md
```

## Task

Create `HfHub.AccessRequests` module.

## Implementation

### Create `lib/hf_hub/access_requests.ex`

```elixir
defmodule HfHub.AccessRequests do
  @moduledoc """
  Access request management for gated repositories.
  """

  alias HfHub.{HTTP, Auth}
  alias HfHub.AccessRequests.AccessRequest

  @type status :: :pending | :accepted | :rejected

  @spec list_pending(String.t(), keyword()) ::
    {:ok, [AccessRequest.t()]} | {:error, term()}
  def list_pending(repo_id, opts \\ []) do
    list_by_status(repo_id, :pending, opts)
  end

  @spec list_accepted(String.t(), keyword()) ::
    {:ok, [AccessRequest.t()]} | {:error, term()}
  def list_accepted(repo_id, opts \\ []) do
    list_by_status(repo_id, :accepted, opts)
  end

  @spec list_rejected(String.t(), keyword()) ::
    {:ok, [AccessRequest.t()]} | {:error, term()}
  def list_rejected(repo_id, opts \\ []) do
    list_by_status(repo_id, :rejected, opts)
  end

  defp list_by_status(repo_id, status, opts) do
    token = opts[:token] || Auth.get_token()
    repo_type = opts[:repo_type] || :model

    path = "/api/#{type_prefix(repo_type)}/#{encode(repo_id)}/user-access-request/#{status}"

    case HTTP.get(path, token: token) do
      {:ok, requests} when is_list(requests) ->
        {:ok, Enum.map(requests, &AccessRequest.from_response(&1, status))}
      {:ok, %{"accessRequests" => requests}} ->
        {:ok, Enum.map(requests, &AccessRequest.from_response(&1, status))}
      error -> error
    end
  end

  @spec accept(String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def accept(repo_id, user, opts \\ []) do
    handle_request(repo_id, user, :accept, opts)
  end

  @spec reject(String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def reject(repo_id, user, opts \\ []) do
    handle_request(repo_id, user, :reject, opts)
  end

  @spec cancel(String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def cancel(repo_id, user, opts \\ []) do
    token = opts[:token] || Auth.get_token()
    repo_type = opts[:repo_type] || :model

    path = "/api/#{type_prefix(repo_type)}/#{encode(repo_id)}/user-access-request/handle"

    HTTP.delete(path <> "?user=#{encode(user)}", token: token)
  end

  @spec grant(String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def grant(repo_id, user, opts \\ []) do
    token = opts[:token] || Auth.get_token()
    repo_type = opts[:repo_type] || :model

    body = %{"user" => user}
    path = "/api/#{type_prefix(repo_type)}/#{encode(repo_id)}/user-access-request/grant"

    HTTP.post_action(path, body, token: token)
  end

  defp handle_request(repo_id, user, action, opts) do
    token = opts[:token] || Auth.get_token()
    repo_type = opts[:repo_type] || :model

    body = %{
      "user" => user,
      "status" => if(action == :accept, do: "accepted", else: "rejected")
    }
    path = "/api/#{type_prefix(repo_type)}/#{encode(repo_id)}/user-access-request/handle"

    HTTP.post_action(path, body, token: token)
  end

  # Helpers
  defp type_prefix(:model), do: "models"
  defp type_prefix(:dataset), do: "datasets"
  defp type_prefix(:space), do: "spaces"

  defp encode(s), do: URI.encode(s, &URI.char_unreserved?/1)
end
```

### Create Data Structure

`lib/hf_hub/access_requests/access_request.ex`:
```elixir
defmodule HfHub.AccessRequests.AccessRequest do
  defstruct [:user, :fullname, :email, :status, :timestamp, :fields]

  def from_response(response, status) do
    %__MODULE__{
      user: response["user"] || response["username"],
      fullname: response["fullname"],
      email: response["email"],
      status: status,
      timestamp: parse_datetime(response["timestamp"]),
      fields: response["fields"] || %{}
    }
  end

  defp parse_datetime(nil), do: nil
  defp parse_datetime(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end
end
```

## Changelog Entry

```markdown
### Added
- `HfHub.AccessRequests` module
  - `list_pending/2`, `list_accepted/2`, `list_rejected/2`
  - `accept/3`, `reject/3`, `cancel/3`, `grant/3`
```

## Completion Checklist

- [ ] `HfHub.AccessRequests` module created
- [ ] Data structure created
- [ ] All operations implemented
- [ ] Tests pass
- [ ] Quality checks pass
- [ ] CHANGELOG updated
