# Prompt 13: User/Organization API & Model Cards

## Context

You are implementing User/Organization profile APIs and Model/Dataset Card parsing for `hf_hub_ex`.

**Prerequisites**: Prompts 01-02 must be completed.

## Required Reading

```
lib/hf_hub/http.ex
lib/hf_hub/api.ex
docs/20251231/user-org/docs.md
docs/20251231/model-cards/docs.md
```

## Task

Create `HfHub.Users`, `HfHub.Organizations`, and `HfHub.Cards` modules.

## Implementation

### Part 1: Create `lib/hf_hub/users.ex`

```elixir
defmodule HfHub.Users do
  @moduledoc """
  User profile and activity API.
  """

  alias HfHub.{HTTP, Auth}
  alias HfHub.Users.User

  @spec get(String.t(), keyword()) :: {:ok, User.t()} | {:error, term()}
  def get(username, opts \\ []) do
    token = opts[:token]

    case HTTP.get("/api/users/#{encode(username)}", token: token) do
      {:ok, response} -> {:ok, User.from_response(response)}
      error -> error
    end
  end

  @spec list_followers(String.t(), keyword()) ::
    {:ok, [User.t()]} | {:error, term()}
  def list_followers(username, opts \\ []) do
    token = opts[:token]

    case HTTP.get("/api/users/#{encode(username)}/followers", token: token) do
      {:ok, users} when is_list(users) ->
        {:ok, Enum.map(users, &User.from_response/1)}
      error -> error
    end
  end

  @spec list_following(String.t(), keyword()) ::
    {:ok, [User.t()]} | {:error, term()}
  def list_following(username, opts \\ []) do
    token = opts[:token]

    case HTTP.get("/api/users/#{encode(username)}/following", token: token) do
      {:ok, users} when is_list(users) ->
        {:ok, Enum.map(users, &User.from_response/1)}
      error -> error
    end
  end

  @spec list_liked_repos(String.t(), keyword()) ::
    {:ok, [String.t()]} | {:error, term()}
  def list_liked_repos(username, opts \\ []) do
    token = opts[:token]

    case HTTP.get("/api/users/#{encode(username)}/likes", token: token) do
      {:ok, %{"likes" => likes}} -> {:ok, likes}
      {:ok, likes} when is_list(likes) -> {:ok, likes}
      error -> error
    end
  end

  @spec like(String.t(), keyword()) :: :ok | {:error, term()}
  def like(repo_id, opts \\ []) do
    token = opts[:token] || Auth.get_token()
    repo_type = opts[:repo_type] || :model

    path = "/api/#{type_prefix(repo_type)}/#{encode(repo_id)}/like"
    HTTP.post_action(path, nil, token: token)
  end

  @spec unlike(String.t(), keyword()) :: :ok | {:error, term()}
  def unlike(repo_id, opts \\ []) do
    token = opts[:token] || Auth.get_token()
    repo_type = opts[:repo_type] || :model

    path = "/api/#{type_prefix(repo_type)}/#{encode(repo_id)}/like"
    HTTP.delete(path, token: token)
  end

  @spec list_likers(String.t(), keyword()) ::
    {:ok, [User.t()]} | {:error, term()}
  def list_likers(repo_id, opts \\ []) do
    token = opts[:token]
    repo_type = opts[:repo_type] || :model

    path = "/api/#{type_prefix(repo_type)}/#{encode(repo_id)}/likers"

    case HTTP.get(path, token: token) do
      {:ok, users} when is_list(users) ->
        {:ok, Enum.map(users, &User.from_response/1)}
      error -> error
    end
  end

  defp type_prefix(:model), do: "models"
  defp type_prefix(:dataset), do: "datasets"
  defp type_prefix(:space), do: "spaces"

  defp encode(s), do: URI.encode(s, &URI.char_unreserved?/1)
end
```

### Part 2: Create `lib/hf_hub/organizations.ex`

```elixir
defmodule HfHub.Organizations do
  @moduledoc """
  Organization profile API.
  """

  alias HfHub.{HTTP}
  alias HfHub.Users.{User, Organization}

  @spec get(String.t(), keyword()) :: {:ok, Organization.t()} | {:error, term()}
  def get(org_name, opts \\ []) do
    token = opts[:token]

    case HTTP.get("/api/organizations/#{encode(org_name)}", token: token) do
      {:ok, response} -> {:ok, Organization.from_response(response)}
      error -> error
    end
  end

  @spec list_members(String.t(), keyword()) ::
    {:ok, [User.t()]} | {:error, term()}
  def list_members(org_name, opts \\ []) do
    token = opts[:token]

    case HTTP.get("/api/organizations/#{encode(org_name)}/members", token: token) do
      {:ok, members} when is_list(members) ->
        {:ok, Enum.map(members, &User.from_response/1)}
      error -> error
    end
  end

  defp encode(s), do: URI.encode(s, &URI.char_unreserved?/1)
end
```

### Part 3: Create `lib/hf_hub/cards.ex`

```elixir
defmodule HfHub.Cards do
  @moduledoc """
  Model and Dataset card parsing and creation.
  """

  alias HfHub.{HTTP, Download}
  alias HfHub.Cards.{ModelCard, DatasetCard, ModelCardData, DatasetCardData}

  @spec load_model_card(String.t(), keyword()) ::
    {:ok, ModelCard.t()} | {:error, term()}
  def load_model_card(repo_id, opts \\ []) do
    with {:ok, readme_path} <- Download.hf_hub_download(
      Keyword.merge(opts, [repo_id: repo_id, filename: "README.md"])
    ),
         {:ok, content} <- File.read(readme_path) do
      parse_model_card(content)
    end
  end

  @spec load_dataset_card(String.t(), keyword()) ::
    {:ok, DatasetCard.t()} | {:error, term()}
  def load_dataset_card(repo_id, opts \\ []) do
    with {:ok, readme_path} <- Download.hf_hub_download(
      Keyword.merge(opts, [repo_id: repo_id, filename: "README.md", repo_type: :dataset])
    ),
         {:ok, content} <- File.read(readme_path) do
      parse_dataset_card(content)
    end
  end

  @spec parse_model_card(String.t()) :: {:ok, ModelCard.t()} | {:error, term()}
  def parse_model_card(content) do
    with {:ok, {frontmatter, body}} <- extract_frontmatter(content) do
      {:ok, %ModelCard{
        data: ModelCardData.from_map(frontmatter),
        content: body
      }}
    end
  end

  @spec parse_dataset_card(String.t()) :: {:ok, DatasetCard.t()} | {:error, term()}
  def parse_dataset_card(content) do
    with {:ok, {frontmatter, body}} <- extract_frontmatter(content) do
      {:ok, %DatasetCard{
        data: DatasetCardData.from_map(frontmatter),
        content: body
      }}
    end
  end

  @spec create_model_card(map()) :: ModelCard.t()
  def create_model_card(data) do
    %ModelCard{
      data: struct(ModelCardData, data),
      content: ""
    }
  end

  @spec create_dataset_card(map()) :: DatasetCard.t()
  def create_dataset_card(data) do
    %DatasetCard{
      data: struct(DatasetCardData, data),
      content: ""
    }
  end

  @spec render(ModelCard.t() | DatasetCard.t()) :: String.t()
  def render(%{data: data, content: content}) do
    yaml = data
    |> Map.from_struct()
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()
    |> to_yaml()

    """
    ---
    #{yaml}
    ---

    #{content}
    """
  end

  # Frontmatter parsing

  defp extract_frontmatter(content) do
    case Regex.run(~r/\A---\n(.*?)\n---\n?(.*)/s, content) do
      [_, yaml, body] ->
        case YamlElixir.read_from_string(yaml) do
          {:ok, frontmatter} -> {:ok, {frontmatter, String.trim(body)}}
          error -> error
        end

      nil ->
        # No frontmatter
        {:ok, {%{}, String.trim(content)}}
    end
  end

  defp to_yaml(map) when map_size(map) == 0, do: ""
  defp to_yaml(map) do
    map
    |> Enum.map(fn {k, v} -> "#{k}: #{yaml_value(v)}" end)
    |> Enum.join("\n")
  end

  defp yaml_value(v) when is_binary(v), do: inspect(v)
  defp yaml_value(v) when is_list(v), do: "\n" <> Enum.map_join(v, "\n", &"  - #{&1}")
  defp yaml_value(v) when is_boolean(v), do: to_string(v)
  defp yaml_value(v) when is_number(v), do: to_string(v)
  defp yaml_value(v), do: inspect(v)
end
```

### Create Data Structures

Create structs in `lib/hf_hub/users/` and `lib/hf_hub/cards/`:

`lib/hf_hub/users/user.ex`:
```elixir
defmodule HfHub.Users.User do
  defstruct [:username, :fullname, :avatar_url, :details, :is_following,
             :num_followers, :num_following, :num_models, :num_datasets,
             :num_spaces, :num_likes]

  def from_response(response) do
    %__MODULE__{
      username: response["user"] || response["username"],
      fullname: response["fullname"],
      avatar_url: response["avatarUrl"],
      # ... map other fields
    }
  end
end
```

`lib/hf_hub/cards/model_card.ex`:
```elixir
defmodule HfHub.Cards.ModelCard do
  defstruct [:data, :content]
end

defmodule HfHub.Cards.ModelCardData do
  defstruct [:language, :license, :license_name, :library_name, :tags,
             :datasets, :metrics, :model_name, :base_model, :pipeline_tag,
             :widget, :inference, :extra]

  def from_map(map) do
    %__MODULE__{
      language: map["language"],
      license: map["license"],
      license_name: map["license_name"],
      library_name: map["library_name"],
      tags: map["tags"],
      datasets: map["datasets"],
      metrics: map["metrics"],
      model_name: map["model_name"] || map["model-name"],
      base_model: map["base_model"],
      pipeline_tag: map["pipeline_tag"],
      widget: map["widget"],
      inference: map["inference"],
      extra: Map.drop(map, ~w[language license license_name library_name
        tags datasets metrics model_name model-name base_model pipeline_tag
        widget inference])
    }
  end
end
```

## Dependencies

Add to `mix.exs`:
```elixir
{:yaml_elixir, "~> 2.9"}
```

## Changelog Entry

```markdown
### Added
- `HfHub.Users` module
  - `get/2`, `list_followers/2`, `list_following/2`
  - `list_liked_repos/2`, `like/2`, `unlike/2`, `list_likers/2`
- `HfHub.Organizations` module
  - `get/2`, `list_members/2`
- `HfHub.Cards` module
  - `load_model_card/2`, `load_dataset_card/2`
  - `parse_model_card/1`, `parse_dataset_card/1`
  - `create_model_card/1`, `create_dataset_card/1`
  - `render/1`
```

## README Update

Add to README.md:

```markdown
### User & Organization Profiles

```elixir
# Get user profile
{:ok, user} = HfHub.Users.get("username")

# Like/unlike repos
:ok = HfHub.Users.like("bert-base-uncased")
:ok = HfHub.Users.unlike("bert-base-uncased")

# Organization info
{:ok, org} = HfHub.Organizations.get("huggingface")
{:ok, members} = HfHub.Organizations.list_members("huggingface")
```

### Model & Dataset Cards

```elixir
# Load and parse cards
{:ok, card} = HfHub.Cards.load_model_card("bert-base-uncased")
card.data.license  # "apache-2.0"

# Create and render cards
card = HfHub.Cards.create_model_card(%{
  language: "en",
  license: "mit",
  tags: ["text-classification"]
})
markdown = HfHub.Cards.render(card)
```
```

## Completion Checklist

- [ ] `HfHub.Users` module created
- [ ] `HfHub.Organizations` module created
- [ ] `HfHub.Cards` module created
- [ ] All data structures created
- [ ] YAML frontmatter parsing works
- [ ] yaml_elixir dependency added
- [ ] All operations implemented
- [ ] Tests pass
- [ ] Quality checks pass
- [ ] CHANGELOG updated
- [ ] README updated

## Final Verification

After completing this prompt, the full feature set is implemented. Run:

```bash
mix deps.get
mix test
mix format
mix credo --strict
mix dialyzer
```

All should pass with no errors or warnings.
