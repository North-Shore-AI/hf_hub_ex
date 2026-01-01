# Prompt 06: Git Operations (Branches, Tags, Refs, Commits)

## Context

You are implementing Git operations for `hf_hub_ex`. This provides branch/tag management, ref listing, and commit history access.

**Prerequisites**: Prompts 01-02 (HTTP write methods, repo management) must be completed.

## Required Reading

**Read these files first:**
```
lib/hf_hub/http.ex           # HTTP client
lib/hf_hub/api.ex            # API patterns
lib/hf_hub/errors.ex         # Error types
```

**Reference documentation:**
```
docs/20251231/git-operations/docs.md    # Full API specification
```

## Task

Create `HfHub.Git` module for branch, tag, ref, and commit operations.

## Implementation Requirements

### 1. Create `lib/hf_hub/git.ex`

```elixir
defmodule HfHub.Git do
  @moduledoc """
  Git operations for HuggingFace Hub repositories.

  Provides branch, tag, and commit management.
  """

  alias HfHub.{HTTP, Auth}
  alias HfHub.Git.{BranchInfo, TagInfo, GitRefs, CommitInfo}

  @type repo_type :: :model | :dataset | :space

  # Branch operations

  @spec create_branch(String.t(), String.t(), keyword()) ::
    {:ok, BranchInfo.t()} | {:error, term()}
  def create_branch(repo_id, branch, opts \\ []) do
    token = opts[:token] || Auth.get_token()
    repo_type = opts[:repo_type] || :model
    revision = opts[:revision] || "main"

    body = %{"startingPoint" => revision}
    path = branch_path(repo_id, repo_type, branch)

    case HTTP.post(path, body, token: token) do
      {:ok, response} -> {:ok, BranchInfo.from_response(response)}
      {:error, {:conflict, _}} when opts[:exist_ok] ->
        {:ok, %BranchInfo{name: branch}}
      error -> error
    end
  end

  @spec delete_branch(String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def delete_branch(repo_id, branch, opts \\ []) do
    token = opts[:token] || Auth.get_token()
    repo_type = opts[:repo_type] || :model

    path = branch_path(repo_id, repo_type, branch)
    HTTP.delete(path, token: token)
  end

  # Tag operations

  @spec create_tag(String.t(), String.t(), keyword()) ::
    {:ok, TagInfo.t()} | {:error, term()}
  def create_tag(repo_id, tag, opts \\ []) do
    token = opts[:token] || Auth.get_token()
    repo_type = opts[:repo_type] || :model
    revision = opts[:revision] || "main"

    body = %{
      "ref" => "refs/heads/#{revision}",
      "message" => opts[:message]
    } |> Enum.reject(fn {_, v} -> is_nil(v) end) |> Map.new()

    path = tag_path(repo_id, repo_type, tag)

    case HTTP.post(path, body, token: token) do
      {:ok, response} -> {:ok, TagInfo.from_response(response)}
      {:error, {:conflict, _}} when opts[:exist_ok] ->
        {:ok, %TagInfo{name: tag}}
      error -> error
    end
  end

  @spec delete_tag(String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def delete_tag(repo_id, tag, opts \\ []) do
    token = opts[:token] || Auth.get_token()
    repo_type = opts[:repo_type] || :model

    path = tag_path(repo_id, repo_type, tag)
    HTTP.delete(path, token: token)
  end

  # Ref listing

  @spec list_refs(String.t(), keyword()) :: {:ok, GitRefs.t()} | {:error, term()}
  def list_refs(repo_id, opts \\ []) do
    token = opts[:token]
    repo_type = opts[:repo_type] || :model

    path = refs_path(repo_id, repo_type)
    params = if opts[:include_pull_requests], do: %{}, else: %{}

    case HTTP.get(path, token: token, params: params) do
      {:ok, response} -> {:ok, GitRefs.from_response(response)}
      error -> error
    end
  end

  # Commit history

  @spec list_commits(String.t(), keyword()) ::
    {:ok, [CommitInfo.t()]} | {:error, term()}
  def list_commits(repo_id, opts \\ []) do
    token = opts[:token]
    repo_type = opts[:repo_type] || :model
    revision = opts[:revision] || "main"

    path = commits_path(repo_id, repo_type, revision)

    case HTTP.get(path, token: token) do
      {:ok, commits} when is_list(commits) ->
        {:ok, Enum.map(commits, &CommitInfo.from_response/1)}
      {:ok, %{"commits" => commits}} ->
        {:ok, Enum.map(commits, &CommitInfo.from_response/1)}
      error -> error
    end
  end

  # Super squash (destructive)

  @spec super_squash(String.t(), keyword()) :: :ok | {:error, term()}
  def super_squash(repo_id, opts \\ []) do
    token = opts[:token] || Auth.get_token()
    repo_type = opts[:repo_type] || :model

    body = %{
      "branch" => opts[:branch] || "main",
      "message" => opts[:message]
    } |> Enum.reject(fn {_, v} -> is_nil(v) end) |> Map.new()

    path = squash_path(repo_id, repo_type)
    HTTP.post_action(path, body, token: token)
  end

  # Path helpers

  defp branch_path(repo_id, repo_type, branch) do
    "/api/#{type_prefix(repo_type)}/#{encode(repo_id)}/branch/#{encode(branch)}"
  end

  defp tag_path(repo_id, repo_type, tag) do
    "/api/#{type_prefix(repo_type)}/#{encode(repo_id)}/tag/#{encode(tag)}"
  end

  defp refs_path(repo_id, repo_type) do
    "/api/#{type_prefix(repo_type)}/#{encode(repo_id)}/refs"
  end

  defp commits_path(repo_id, repo_type, revision) do
    "/api/#{type_prefix(repo_type)}/#{encode(repo_id)}/commits/#{encode(revision)}"
  end

  defp squash_path(repo_id, repo_type) do
    "/api/#{type_prefix(repo_type)}/#{encode(repo_id)}/super-squash"
  end

  defp type_prefix(:model), do: "models"
  defp type_prefix(:dataset), do: "datasets"
  defp type_prefix(:space), do: "spaces"

  defp encode(s), do: URI.encode(s, &URI.char_unreserved?/1)
end
```

### 2. Create Data Structures

Create `lib/hf_hub/git/branch_info.ex`, `lib/hf_hub/git/tag_info.ex`, etc.

## Test Requirements

Create `test/hf_hub/git_test.exs` with tests for:
- Create/delete branches
- Create/delete tags (with and without message)
- List refs (branches, tags)
- List commits
- Super squash
- Error handling

## Quality Requirements

After implementation:
1. `mix test` - all tests pass
2. `mix format` - formatted
3. `mix credo --strict` - no warnings
4. `mix dialyzer` - no errors

## Changelog Entry

```markdown
### Added
- `HfHub.Git` module for git operations
  - `create_branch/3`, `delete_branch/3`
  - `create_tag/3`, `delete_tag/3`
  - `list_refs/2`, `list_commits/2`
  - `super_squash/2`
```

## Completion Checklist

- [ ] `HfHub.Git` module created
- [ ] Branch operations working
- [ ] Tag operations working
- [ ] Ref listing working
- [ ] Commit history working
- [ ] Super squash working
- [ ] All tests pass
- [ ] Quality checks pass
- [ ] CHANGELOG updated
- [ ] README updated
