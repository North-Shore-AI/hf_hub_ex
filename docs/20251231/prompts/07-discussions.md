# Prompt 07: Discussions & Pull Requests API

## Context

You are implementing the Discussions API for `hf_hub_ex`. This enables community interaction including discussions, pull requests, and comments.

**Prerequisites**: Prompts 01-02 must be completed.

## Required Reading

**Read these files:**
```
lib/hf_hub/http.ex
lib/hf_hub/api.ex
```

**Reference documentation:**
```
docs/20251231/discussions/docs.md
```

## Task

Create `HfHub.Discussions` module for community features.

## Implementation

### Create `lib/hf_hub/discussions.ex`

```elixir
defmodule HfHub.Discussions do
  @moduledoc """
  Discussions and Pull Requests API.
  """

  alias HfHub.{HTTP, Auth}
  alias HfHub.Discussions.{Discussion, DiscussionDetails, Comment}

  @type status :: :open | :closed | :merged | :draft | :all

  @spec list(String.t(), keyword()) ::
    {:ok, [Discussion.t()]} | {:error, term()}
  def list(repo_id, opts \\ []) do
    token = opts[:token]
    repo_type = opts[:repo_type] || :model

    params = %{}
    |> maybe_put(:author, opts[:author])
    |> maybe_put(:status, opts[:status])

    path = "/api/#{type_prefix(repo_type)}/#{encode(repo_id)}/discussions"

    case HTTP.get(path, token: token, params: params) do
      {:ok, %{"discussions" => discussions}} ->
        {:ok, Enum.map(discussions, &Discussion.from_response/1)}
      error -> error
    end
  end

  @spec get(String.t(), non_neg_integer(), keyword()) ::
    {:ok, DiscussionDetails.t()} | {:error, term()}
  def get(repo_id, discussion_num, opts \\ []) do
    token = opts[:token]
    repo_type = opts[:repo_type] || :model

    path = "/api/#{type_prefix(repo_type)}/#{encode(repo_id)}/discussions/#{discussion_num}"

    case HTTP.get(path, token: token) do
      {:ok, response} -> {:ok, DiscussionDetails.from_response(response)}
      error -> error
    end
  end

  @spec create(String.t(), String.t(), keyword()) ::
    {:ok, DiscussionDetails.t()} | {:error, term()}
  def create(repo_id, title, opts \\ []) do
    token = opts[:token] || Auth.get_token()
    repo_type = opts[:repo_type] || :model

    body = %{
      "title" => title,
      "description" => opts[:description],
      "pullRequest" => false
    }

    path = "/api/#{type_prefix(repo_type)}/#{encode(repo_id)}/discussions"

    case HTTP.post(path, body, token: token) do
      {:ok, response} -> {:ok, DiscussionDetails.from_response(response)}
      error -> error
    end
  end

  @spec create_pr(String.t(), String.t(), keyword()) ::
    {:ok, DiscussionDetails.t()} | {:error, term()}
  def create_pr(repo_id, title, opts \\ []) do
    create(repo_id, title, Keyword.put(opts, :pull_request, true))
  end

  @spec comment(String.t(), non_neg_integer(), String.t(), keyword()) ::
    {:ok, Comment.t()} | {:error, term()}
  def comment(repo_id, discussion_num, content, opts \\ []) do
    token = opts[:token] || Auth.get_token()
    repo_type = opts[:repo_type] || :model

    body = %{"comment" => content}
    path = "/api/#{type_prefix(repo_type)}/#{encode(repo_id)}/discussions/#{discussion_num}/comment"

    case HTTP.post(path, body, token: token) do
      {:ok, response} -> {:ok, Comment.from_response(response)}
      error -> error
    end
  end

  @spec close(String.t(), non_neg_integer(), keyword()) ::
    {:ok, Discussion.t()} | {:error, term()}
  def close(repo_id, discussion_num, opts \\ []) do
    change_status(repo_id, discussion_num, :closed, opts)
  end

  @spec reopen(String.t(), non_neg_integer(), keyword()) ::
    {:ok, Discussion.t()} | {:error, term()}
  def reopen(repo_id, discussion_num, opts \\ []) do
    change_status(repo_id, discussion_num, :open, opts)
  end

  @spec change_status(String.t(), non_neg_integer(), status(), keyword()) ::
    {:ok, Discussion.t()} | {:error, term()}
  def change_status(repo_id, discussion_num, new_status, opts \\ []) do
    token = opts[:token] || Auth.get_token()
    repo_type = opts[:repo_type] || :model

    body = %{
      "status" => Atom.to_string(new_status),
      "comment" => opts[:comment]
    } |> Enum.reject(fn {_, v} -> is_nil(v) end) |> Map.new()

    path = "/api/#{type_prefix(repo_type)}/#{encode(repo_id)}/discussions/#{discussion_num}/status"

    case HTTP.put(path, body, token: token) do
      {:ok, response} -> {:ok, Discussion.from_response(response)}
      error -> error
    end
  end

  @spec merge_pr(String.t(), non_neg_integer(), keyword()) ::
    {:ok, Discussion.t()} | {:error, term()}
  def merge_pr(repo_id, discussion_num, opts \\ []) do
    token = opts[:token] || Auth.get_token()
    repo_type = opts[:repo_type] || :model

    body = %{"comment" => opts[:comment]}
    |> Enum.reject(fn {_, v} -> is_nil(v) end) |> Map.new()

    path = "/api/#{type_prefix(repo_type)}/#{encode(repo_id)}/discussions/#{discussion_num}/merge"

    case HTTP.post(path, body, token: token) do
      {:ok, response} -> {:ok, Discussion.from_response(response)}
      error -> error
    end
  end

  @spec rename(String.t(), non_neg_integer(), String.t(), keyword()) ::
    {:ok, Discussion.t()} | {:error, term()}
  def rename(repo_id, discussion_num, new_title, opts \\ []) do
    token = opts[:token] || Auth.get_token()
    repo_type = opts[:repo_type] || :model

    body = %{"title" => new_title}
    path = "/api/#{type_prefix(repo_type)}/#{encode(repo_id)}/discussions/#{discussion_num}/title"

    case HTTP.put(path, body, token: token) do
      {:ok, response} -> {:ok, Discussion.from_response(response)}
      error -> error
    end
  end

  # Helpers
  defp type_prefix(:model), do: "models"
  defp type_prefix(:dataset), do: "datasets"
  defp type_prefix(:space), do: "spaces"

  defp encode(s), do: URI.encode(s, &URI.char_unreserved?/1)

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
```

### Create Data Structures

Create structs in `lib/hf_hub/discussions/`:
- `Discussion`
- `DiscussionDetails`
- `Comment`
- `StatusChange`
- `TitleChange`

## Test Requirements

Test all functions with Bypass mocking.

## Changelog Entry

```markdown
### Added
- `HfHub.Discussions` module
  - `list/2`, `get/3`, `create/3`, `create_pr/3`
  - `comment/4`, `close/3`, `reopen/3`
  - `change_status/4`, `merge_pr/3`, `rename/4`
```

## Completion Checklist

- [ ] `HfHub.Discussions` module created
- [ ] All data structures created
- [ ] All functions implemented
- [ ] Tests pass
- [ ] Quality checks pass
- [ ] CHANGELOG updated
