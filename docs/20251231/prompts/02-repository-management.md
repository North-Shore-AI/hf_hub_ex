# Prompt 02: Repository Management API

## IMPORTANT: Check for Existing Work First

**Before starting implementation**, search the codebase for existing work on this task:
1. Check if `lib/hf_hub/repo.ex` already exists
2. Check if `lib/hf_hub/repo/` directory exists with any structs
3. Check if `test/hf_hub/repo_test.exs` exists
4. Run `git status` to see uncommitted files that may contain partial work

If existing implementations are found:
- Review and complete any partial work rather than starting from scratch
- Run existing tests with `mix test test/hf_hub/repo_test.exs` to see what passes/fails
- Focus on fixing/completing what's missing rather than rewriting

## Context

You are implementing repository management (CRUD) operations for the `hf_hub_ex` Elixir library. This enables creating, deleting, updating, and moving repositories on HuggingFace Hub.

**Prerequisites**: Prompt 01 (HTTP write methods) must be completed first.

## Required Reading

**Read these files first:**
```
lib/hf_hub/http.ex           # HTTP client (now with POST/PUT/DELETE)
lib/hf_hub/api.ex            # Existing API patterns
lib/hf_hub/auth.ex           # Token handling
lib/hf_hub/errors.ex         # Error types
lib/hf_hub/config.ex         # Endpoint configuration
test/hf_hub/api_test.exs     # Existing API test patterns
```

**Reference documentation:**
```
docs/20251231/repo-management/docs.md    # Full API specification
docs/20251231/gap-analysis/docs.md       # Gap analysis overview
```

## Task

Create `HfHub.Repo` module for repository management operations.

## Implementation Requirements

### 1. Create `lib/hf_hub/repo.ex`

```elixir
defmodule HfHub.Repo do
  @moduledoc """
  Repository management operations for HuggingFace Hub.

  Provides create, delete, update, and move operations for repositories
  (models, datasets, and spaces).

  ## Examples

      # Create a new model repository
      {:ok, url} = HfHub.Repo.create("my-org/my-model", private: true)

      # Create a space with Gradio
      {:ok, url} = HfHub.Repo.create("my-space",
        repo_type: :space,
        space_sdk: "gradio"
      )

      # Delete a repository
      :ok = HfHub.Repo.delete("my-org/old-model")

      # Update settings
      :ok = HfHub.Repo.update_settings("my-model", private: true, gated: :auto)

      # Move/rename a repository
      {:ok, url} = HfHub.Repo.move("old-name", "new-org/new-name")
  """

  alias HfHub.{HTTP, Auth, Config}

  @type repo_type :: :model | :dataset | :space
  @type gated :: :auto | :manual | false
  @type space_sdk :: String.t()  # "gradio" | "streamlit" | "docker" | "static"
  @type space_hardware :: String.t()  # "cpu-basic" | "cpu-upgrade" | etc.

  # Implement all functions from docs/20251231/repo-management/docs.md
end
```

### 2. Create `lib/hf_hub/repo/repo_url.ex`

```elixir
defmodule HfHub.Repo.RepoUrl do
  @moduledoc """
  Repository URL returned from create/move operations.
  """

  @derive Jason.Encoder
  defstruct [:url, :repo_id, :repo_type]

  @type t :: %__MODULE__{
    url: String.t(),
    repo_id: String.t(),
    repo_type: :model | :dataset | :space
  }

  def from_response(response, repo_type) do
    # Parse API response into RepoUrl struct
  end
end
```

### 3. API Endpoints

| Function | Method | Endpoint |
|----------|--------|----------|
| `create/2` | POST | `/api/repos/create` |
| `delete/2` | DELETE | `/api/repos/{type}s/{repo_id}` |
| `update_settings/2` | PUT | `/api/{type}s/{repo_id}/settings` |
| `move/3` | POST | `/api/repos/move` |
| `exists?/2` | HEAD | `/{type}s/{repo_id}` |
| `file_exists?/3` | HEAD | `/{type}s/{repo_id}/resolve/{rev}/{file}` |
| `revision_exists?/3` | GET | (use repo_info with revision) |

### 4. Implementation Details

**create/2:**
```elixir
def create(repo_id, opts \\ []) do
  token = opts[:token] || Auth.get_token()
  repo_type = opts[:repo_type] || :model

  {name, organization} = parse_repo_id(repo_id)

  body = %{
    name: name,
    organization: organization,
    type: repo_type_to_string(repo_type),
    private: opts[:private] || false
  }
  |> maybe_add_space_opts(opts)

  case HTTP.post("/api/repos/create", body, token: token) do
    {:ok, response} -> {:ok, RepoUrl.from_response(response, repo_type)}
    {:error, {:conflict, _}} when opts[:exist_ok] -> {:ok, build_url(repo_id, repo_type)}
    {:error, _} = error -> error
  end
end
```

**delete/2:**
```elixir
def delete(repo_id, opts \\ []) do
  token = opts[:token] || Auth.get_token()
  repo_type = opts[:repo_type] || :model
  prefix = repo_type_prefix(repo_type)

  case HTTP.delete("/api/repos/#{prefix}/#{encode_repo_id(repo_id)}", token: token) do
    :ok -> :ok
    {:error, :not_found} when opts[:missing_ok] -> :ok
    {:error, _} = error -> error
  end
end
```

### 5. Helper Functions

```elixir
defp parse_repo_id(repo_id) do
  case String.split(repo_id, "/", parts: 2) do
    [name] -> {name, nil}
    [org, name] -> {name, org}
  end
end

defp repo_type_prefix(:model), do: "models"
defp repo_type_prefix(:dataset), do: "datasets"
defp repo_type_prefix(:space), do: "spaces"

defp repo_type_to_string(:model), do: "model"
defp repo_type_to_string(:dataset), do: "dataset"
defp repo_type_to_string(:space), do: "space"

defp encode_repo_id(repo_id) do
  URI.encode(repo_id, &URI.char_unreserved?/1)
end
```

## Test Requirements (TDD)

Create `test/hf_hub/repo_test.exs`:

```elixir
defmodule HfHub.RepoTest do
  use ExUnit.Case, async: true

  describe "create/2" do
    test "creates a public model repository" do
      # Use Bypass to mock API
    end

    test "creates a private repository" do
    end

    test "creates a space with SDK" do
    end

    test "returns existing repo with exist_ok: true" do
    end

    test "returns error without token" do
    end

    test "returns conflict error without exist_ok" do
    end
  end

  describe "delete/2" do
    test "deletes existing repository" do
    end

    test "returns :ok with missing_ok when not found" do
    end

    test "returns error when not found without missing_ok" do
    end
  end

  describe "update_settings/2" do
    test "updates visibility to private" do
    end

    test "updates gated setting" do
    end
  end

  describe "move/3" do
    test "moves repository to new name" do
    end

    test "moves repository to different org" do
    end
  end

  describe "exists?/2" do
    test "returns true for existing repo" do
    end

    test "returns false for non-existent repo" do
    end
  end

  describe "file_exists?/3" do
    test "returns true for existing file" do
    end

    test "returns false for non-existent file" do
    end
  end

  describe "revision_exists?/3" do
    test "returns true for existing revision" do
    end

    test "returns false for non-existent revision" do
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
- `HfHub.Repo` module for repository management
  - `create/2` - Create new repositories (models, datasets, spaces)
  - `delete/2` - Delete repositories
  - `update_settings/2` - Update repository settings (visibility, gated)
  - `move/3` - Move/rename repositories
  - `exists?/2` - Check if repository exists
  - `file_exists?/3` - Check if file exists in repository
  - `revision_exists?/3` - Check if revision exists
- `HfHub.Repo.RepoUrl` struct for repository URL responses
```

## README Update

Add to README.md in the "Features" section:

```markdown
### Repository Management

```elixir
# Create a new repository
{:ok, url} = HfHub.Repo.create("my-org/my-model", private: true)

# Create a Space with Gradio
{:ok, url} = HfHub.Repo.create("my-space", repo_type: :space, space_sdk: "gradio")

# Delete a repository
:ok = HfHub.Repo.delete("my-org/old-model")

# Update settings
:ok = HfHub.Repo.update_settings("my-model", private: true, gated: :auto)

# Move/rename
{:ok, url} = HfHub.Repo.move("old-name", "new-org/new-name")

# Check existence
true = HfHub.Repo.exists?("bert-base-uncased")
```
```

## Completion Checklist

- [ ] `HfHub.Repo` module created
- [ ] `HfHub.Repo.RepoUrl` struct created
- [ ] `create/2` implemented with tests
- [ ] `delete/2` implemented with tests
- [ ] `update_settings/2` implemented with tests
- [ ] `move/3` implemented with tests
- [ ] `exists?/2` implemented with tests
- [ ] `file_exists?/3` implemented with tests
- [ ] `revision_exists?/3` implemented with tests
- [ ] `mix test` passes
- [ ] `mix format` passes
- [ ] `mix credo --strict` passes
- [ ] `mix dialyzer` passes
- [ ] CHANGELOG.md updated
- [ ] README.md updated
