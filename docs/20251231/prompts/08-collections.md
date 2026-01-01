# Prompt 08: Collections API

## Context

You are implementing the Collections API for `hf_hub_ex`. Collections enable organizing and curating lists of models, datasets, and spaces.

**Prerequisites**: Prompts 01-02 must be completed.

## Required Reading

```
lib/hf_hub/http.ex
docs/20251231/collections/docs.md
```

## Task

Create `HfHub.Collections` module.

## Implementation

### Create `lib/hf_hub/collections.ex`

```elixir
defmodule HfHub.Collections do
  @moduledoc """
  Collections API for organizing models, datasets, and spaces.
  """

  alias HfHub.{HTTP, Auth}
  alias HfHub.Collections.{Collection, CollectionItem}

  @type item_type :: :model | :dataset | :space | :paper
  @type sort :: :last_modified | :trending | :upvotes

  @spec list(keyword()) :: {:ok, [Collection.t()]} | {:error, term()}
  def list(opts \\ []) do
    token = opts[:token]

    params = %{}
    |> maybe_put(:owner, opts[:owner])
    |> maybe_put(:item, opts[:item])
    |> maybe_put(:sort, opts[:sort] && sort_to_string(opts[:sort]))

    case HTTP.get("/api/collections", token: token, params: params) do
      {:ok, %{"collections" => collections}} ->
        {:ok, Enum.map(collections, &Collection.from_response/1)}
      {:ok, collections} when is_list(collections) ->
        {:ok, Enum.map(collections, &Collection.from_response/1)}
      error -> error
    end
  end

  @spec get(String.t(), keyword()) :: {:ok, Collection.t()} | {:error, term()}
  def get(slug, opts \\ []) do
    token = opts[:token]

    case HTTP.get("/api/collections/#{encode(slug)}", token: token) do
      {:ok, response} -> {:ok, Collection.from_response(response)}
      error -> error
    end
  end

  @spec create(String.t(), keyword()) :: {:ok, Collection.t()} | {:error, term()}
  def create(title, opts \\ []) do
    token = opts[:token] || Auth.get_token()

    body = %{
      "title" => title,
      "namespace" => opts[:namespace],
      "description" => opts[:description],
      "private" => opts[:private] || false
    } |> Enum.reject(fn {_, v} -> is_nil(v) end) |> Map.new()

    case HTTP.post("/api/collections", body, token: token) do
      {:ok, response} -> {:ok, Collection.from_response(response)}
      {:error, {:conflict, _}} when opts[:exists_ok] -> get_by_title(title, opts)
      error -> error
    end
  end

  @spec update(String.t(), keyword()) :: {:ok, Collection.t()} | {:error, term()}
  def update(slug, opts \\ []) do
    token = opts[:token] || Auth.get_token()

    body = %{}
    |> maybe_put(:title, opts[:title])
    |> maybe_put(:description, opts[:description])
    |> maybe_put(:private, opts[:private])
    |> maybe_put(:position, opts[:position])
    |> maybe_put(:theme, opts[:theme])

    case HTTP.patch("/api/collections/#{encode(slug)}", body, token: token) do
      {:ok, response} -> {:ok, Collection.from_response(response)}
      error -> error
    end
  end

  @spec delete(String.t(), keyword()) :: :ok | {:error, term()}
  def delete(slug, opts \\ []) do
    token = opts[:token] || Auth.get_token()

    case HTTP.delete("/api/collections/#{encode(slug)}", token: token) do
      :ok -> :ok
      {:error, :not_found} when opts[:missing_ok] -> :ok
      error -> error
    end
  end

  @spec add_item(String.t(), String.t(), item_type(), keyword()) ::
    {:ok, CollectionItem.t()} | {:error, term()}
  def add_item(slug, item_id, item_type, opts \\ []) do
    token = opts[:token] || Auth.get_token()

    body = %{
      "itemId" => item_id,
      "itemType" => Atom.to_string(item_type),
      "note" => opts[:note]
    } |> Enum.reject(fn {_, v} -> is_nil(v) end) |> Map.new()

    case HTTP.post("/api/collections/#{encode(slug)}/items", body, token: token) do
      {:ok, response} -> {:ok, CollectionItem.from_response(response)}
      {:error, {:conflict, _}} when opts[:exists_ok] -> {:ok, nil}
      error -> error
    end
  end

  @spec update_item(String.t(), String.t(), keyword()) ::
    {:ok, CollectionItem.t()} | {:error, term()}
  def update_item(slug, item_object_id, opts \\ []) do
    token = opts[:token] || Auth.get_token()

    body = %{}
    |> maybe_put(:note, opts[:note])
    |> maybe_put(:position, opts[:position])

    path = "/api/collections/#{encode(slug)}/items/#{item_object_id}"

    case HTTP.patch(path, body, token: token) do
      {:ok, response} -> {:ok, CollectionItem.from_response(response)}
      error -> error
    end
  end

  @spec delete_item(String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def delete_item(slug, item_object_id, opts \\ []) do
    token = opts[:token] || Auth.get_token()

    path = "/api/collections/#{encode(slug)}/items/#{item_object_id}"

    case HTTP.delete(path, token: token) do
      :ok -> :ok
      {:error, :not_found} when opts[:missing_ok] -> :ok
      error -> error
    end
  end

  # Helpers
  defp encode(s), do: URI.encode(s, &URI.char_unreserved?/1)
  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
  defp sort_to_string(:last_modified), do: "lastModified"
  defp sort_to_string(:trending), do: "trending"
  defp sort_to_string(:upvotes), do: "upvotes"

  defp get_by_title(title, opts) do
    # Try to find collection by title
    with {:ok, collections} <- list(Keyword.take(opts, [:token, :owner])) do
      case Enum.find(collections, &(&1.title == title)) do
        nil -> {:error, :not_found}
        collection -> {:ok, collection}
      end
    end
  end
end
```

### Create Data Structures

`lib/hf_hub/collections/collection.ex`:
```elixir
defmodule HfHub.Collections.Collection do
  defstruct [:slug, :title, :description, :owner, :private, :items,
             :upvotes, :created_at, :updated_at, :theme, :position]

  def from_response(response) do
    %__MODULE__{
      slug: response["slug"],
      title: response["title"],
      description: response["description"],
      owner: response["owner"],
      private: response["private"],
      items: Enum.map(response["items"] || [], &CollectionItem.from_response/1),
      upvotes: response["upvotes"],
      created_at: parse_datetime(response["createdAt"]),
      updated_at: parse_datetime(response["updatedAt"])
    }
  end

  defp parse_datetime(nil), do: nil
  defp parse_datetime(str), do: DateTime.from_iso8601(str) |> elem(1)
end
```

## Test Requirements

Test all CRUD operations with Bypass.

## Changelog Entry

```markdown
### Added
- `HfHub.Collections` module
  - `list/1`, `get/2`, `create/2`, `update/2`, `delete/2`
  - `add_item/4`, `update_item/3`, `delete_item/3`
```

## Completion Checklist

- [ ] `HfHub.Collections` module created
- [ ] Data structures created
- [ ] All operations implemented
- [ ] Tests pass
- [ ] Quality checks pass
- [ ] CHANGELOG updated
