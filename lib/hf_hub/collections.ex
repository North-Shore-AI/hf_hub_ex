defmodule HfHub.Collections do
  @moduledoc """
  Collections API for organizing models, datasets, and spaces on HuggingFace Hub.

  Collections enable users to curate lists of repositories and papers.

  ## Examples

      # List all collections
      {:ok, collections} = HfHub.Collections.list()

      # List collections by owner
      {:ok, collections} = HfHub.Collections.list(owner: "huggingface")

      # Get a specific collection
      {:ok, collection} = HfHub.Collections.get("user/my-llm-collection-123abc")

      # Create a new collection
      {:ok, collection} = HfHub.Collections.create("My LLM Collection",
        description: "Best open-source LLMs", token: "hf_xxx")

      # Add an item to a collection
      {:ok, item} = HfHub.Collections.add_item("user/collection-123",
        "bert-base-uncased", :model, note: "Best BERT model")
  """

  alias HfHub.{Auth, HTTP}
  alias HfHub.Collections.{Collection, CollectionItem}

  @type item_type :: :model | :dataset | :space | :paper
  @type sort :: :last_modified | :trending | :upvotes

  @doc """
  Lists collections with optional filters.

  ## Options

    * `:owner` - Filter by owner username
    * `:item` - Filter by item (e.g., "bert-base-uncased")
    * `:sort` - Sort by `:last_modified`, `:trending`, or `:upvotes`
    * `:token` - Authentication token

  ## Examples

      {:ok, collections} = HfHub.Collections.list()
      {:ok, collections} = HfHub.Collections.list(owner: "huggingface")
      {:ok, collections} = HfHub.Collections.list(sort: :trending)
  """
  @spec list(keyword()) :: {:ok, [Collection.t()]} | {:error, term()}
  def list(opts \\ []) do
    token = opts[:token]

    params =
      %{}
      |> maybe_put(:owner, opts[:owner])
      |> maybe_put(:item, opts[:item])
      |> maybe_put(:sort, sort_to_string(opts[:sort]))
      |> Enum.to_list()

    case HTTP.get("/api/collections", token: token, params: params) do
      {:ok, %{"collections" => collections}} ->
        {:ok, Enum.map(collections, &Collection.from_response/1)}

      {:ok, collections} when is_list(collections) ->
        {:ok, Enum.map(collections, &Collection.from_response/1)}

      error ->
        error
    end
  end

  @doc """
  Gets a collection by slug.

  ## Options

    * `:token` - Authentication token

  ## Examples

      {:ok, collection} = HfHub.Collections.get("user/my-llm-collection-123abc")
  """
  @spec get(String.t(), keyword()) :: {:ok, Collection.t()} | {:error, term()}
  def get(slug, opts \\ []) do
    token = opts[:token]

    case HTTP.get("/api/collections/#{encode(slug)}", token: token) do
      {:ok, response} -> {:ok, Collection.from_response(response)}
      error -> error
    end
  end

  @doc """
  Creates a new collection.

  ## Options

    * `:namespace` - Organization namespace (default: current user)
    * `:description` - Collection description
    * `:private` - Make collection private (default: false)
    * `:exists_ok` - Don't error if collection exists (default: false)
    * `:token` - Authentication token (required)

  ## Examples

      {:ok, collection} = HfHub.Collections.create("My LLM Collection",
        description: "Best open-source LLMs", token: "hf_xxx")

      {:ok, collection} = HfHub.Collections.create("Private Collection",
        private: true, namespace: "my-org", token: "hf_xxx")
  """
  @spec create(String.t(), keyword()) :: {:ok, Collection.t()} | {:error, term()}
  def create(title, opts \\ []) do
    token = opts[:token] || get_token()
    exists_ok = Keyword.get(opts, :exists_ok, false)

    body =
      %{"title" => title, "private" => opts[:private] || false}
      |> maybe_put("namespace", opts[:namespace])
      |> maybe_put("description", opts[:description])

    case HTTP.post("/api/collections", body, token: token) do
      {:ok, response} ->
        {:ok, Collection.from_response(response)}

      {:error, {:conflict, _}} when exists_ok ->
        get_by_title(title, opts)

      error ->
        error
    end
  end

  @doc """
  Updates collection metadata.

  ## Options

    * `:title` - New title
    * `:description` - New description
    * `:private` - Change visibility
    * `:position` - Reorder position
    * `:theme` - Collection theme
    * `:token` - Authentication token (required)

  ## Examples

      {:ok, collection} = HfHub.Collections.update("user/my-collection-123",
        title: "Updated Title", description: "New description")
  """
  @spec update(String.t(), keyword()) :: {:ok, Collection.t()} | {:error, term()}
  def update(slug, opts \\ []) do
    token = opts[:token] || get_token()

    body =
      %{}
      |> maybe_put("title", opts[:title])
      |> maybe_put("description", opts[:description])
      |> maybe_put("private", opts[:private])
      |> maybe_put("position", opts[:position])
      |> maybe_put("theme", opts[:theme])

    case HTTP.patch("/api/collections/#{encode(slug)}", body, token: token) do
      {:ok, response} -> {:ok, Collection.from_response(response)}
      error -> error
    end
  end

  @doc """
  Deletes a collection.

  ## Options

    * `:missing_ok` - Don't error if collection doesn't exist (default: false)
    * `:token` - Authentication token (required)

  ## Examples

      :ok = HfHub.Collections.delete("user/my-collection-123")
      :ok = HfHub.Collections.delete("user/maybe-exists", missing_ok: true)
  """
  @spec delete(String.t(), keyword()) :: :ok | {:error, term()}
  def delete(slug, opts \\ []) do
    token = opts[:token] || get_token()
    missing_ok = Keyword.get(opts, :missing_ok, false)

    case HTTP.delete("/api/collections/#{encode(slug)}", token: token) do
      :ok -> :ok
      {:ok, _} -> :ok
      {:error, :not_found} when missing_ok -> :ok
      error -> error
    end
  end

  @doc """
  Adds an item to a collection.

  ## Arguments

    * `slug` - Collection slug
    * `item_id` - Item identifier (e.g., "bert-base-uncased")
    * `item_type` - Type of item (`:model`, `:dataset`, `:space`, or `:paper`)

  ## Options

    * `:note` - Optional note about the item
    * `:exists_ok` - Don't error if item already in collection (default: false)
    * `:token` - Authentication token (required)

  ## Examples

      {:ok, item} = HfHub.Collections.add_item("user/collection-123",
        "bert-base-uncased", :model, note: "Best BERT model")

      {:ok, item} = HfHub.Collections.add_item("user/collection-123",
        "squad", :dataset)
  """
  @spec add_item(String.t(), String.t(), item_type(), keyword()) ::
          {:ok, CollectionItem.t()} | {:error, term()}
  def add_item(slug, item_id, item_type, opts \\ []) do
    token = opts[:token] || get_token()
    exists_ok = Keyword.get(opts, :exists_ok, false)

    body =
      %{"itemId" => item_id, "itemType" => Atom.to_string(item_type)}
      |> maybe_put("note", opts[:note])

    case HTTP.post("/api/collections/#{encode(slug)}/items", body, token: token) do
      {:ok, response} ->
        {:ok, CollectionItem.from_response(response)}

      {:error, {:conflict, _}} when exists_ok ->
        {:ok, nil}

      error ->
        error
    end
  end

  @doc """
  Updates a collection item.

  ## Options

    * `:note` - New note for the item
    * `:position` - New position in the collection
    * `:token` - Authentication token (required)

  ## Examples

      {:ok, item} = HfHub.Collections.update_item("user/collection-123", "item-object-id",
        note: "Updated note", position: 0)
  """
  @spec update_item(String.t(), String.t(), keyword()) ::
          {:ok, CollectionItem.t()} | {:error, term()}
  def update_item(slug, item_object_id, opts \\ []) do
    token = opts[:token] || get_token()

    body =
      %{}
      |> maybe_put("note", opts[:note])
      |> maybe_put("position", opts[:position])

    path = "/api/collections/#{encode(slug)}/items/#{item_object_id}"

    case HTTP.patch(path, body, token: token) do
      {:ok, response} -> {:ok, CollectionItem.from_response(response)}
      error -> error
    end
  end

  @doc """
  Removes an item from a collection.

  ## Options

    * `:missing_ok` - Don't error if item doesn't exist (default: false)
    * `:token` - Authentication token (required)

  ## Examples

      :ok = HfHub.Collections.delete_item("user/collection-123", "item-object-id")
  """
  @spec delete_item(String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def delete_item(slug, item_object_id, opts \\ []) do
    token = opts[:token] || get_token()
    missing_ok = Keyword.get(opts, :missing_ok, false)

    path = "/api/collections/#{encode(slug)}/items/#{item_object_id}"

    case HTTP.delete(path, token: token) do
      :ok -> :ok
      {:ok, _} -> :ok
      {:error, :not_found} when missing_ok -> :ok
      error -> error
    end
  end

  # Private helpers

  defp encode(s), do: URI.encode(s, &URI.char_unreserved?/1)

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp sort_to_string(nil), do: nil
  defp sort_to_string(:last_modified), do: "lastModified"
  defp sort_to_string(:trending), do: "trending"
  defp sort_to_string(:upvotes), do: "upvotes"

  defp get_token do
    case Auth.get_token() do
      {:ok, token} -> token
      _ -> nil
    end
  end

  defp get_by_title(title, opts) do
    with {:ok, collections} <- list(Keyword.take(opts, [:token, :owner])) do
      case Enum.find(collections, &(&1.title == title)) do
        nil -> {:error, :not_found}
        collection -> {:ok, collection}
      end
    end
  end
end
