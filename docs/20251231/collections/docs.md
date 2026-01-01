# Collections API

## Overview

Collections enable users to organize and curate lists of models, datasets, and spaces on HuggingFace Hub.

## Python Reference

### Source File
`huggingface_hub/src/huggingface_hub/hf_api.py`

### Functions

#### list_collections

```python
def list_collections(
    *,
    owner: Optional[str] = None,
    item: Optional[str] = None,
    sort: Optional[Literal["lastModified", "trending", "upvotes"]] = None,
    token: Optional[str] = None,
) -> Iterable[Collection]
```

**API Endpoint**: `GET /api/collections`

---

#### get_collection

```python
def get_collection(
    collection_slug: str,
    *,
    token: Optional[str] = None,
) -> Collection
```

**API Endpoint**: `GET /api/collections/{slug}`

---

#### create_collection

```python
def create_collection(
    title: str,
    *,
    namespace: Optional[str] = None,
    description: Optional[str] = None,
    private: bool = False,
    exists_ok: bool = False,
    token: Optional[str] = None,
) -> Collection
```

**API Endpoint**: `POST /api/collections`

---

#### update_collection_metadata

```python
def update_collection_metadata(
    collection_slug: str,
    *,
    title: Optional[str] = None,
    description: Optional[str] = None,
    private: Optional[bool] = None,
    position: Optional[int] = None,
    theme: Optional[str] = None,
    token: Optional[str] = None,
) -> Collection
```

**API Endpoint**: `PATCH /api/collections/{slug}`

---

#### delete_collection

```python
def delete_collection(
    collection_slug: str,
    *,
    missing_ok: bool = False,
    token: Optional[str] = None,
) -> None
```

**API Endpoint**: `DELETE /api/collections/{slug}`

---

#### add_collection_item

```python
def add_collection_item(
    collection_slug: str,
    item_id: str,
    item_type: Literal["model", "dataset", "space", "paper"],
    *,
    note: Optional[str] = None,
    exists_ok: bool = False,
    token: Optional[str] = None,
) -> CollectionItem
```

**API Endpoint**: `POST /api/collections/{slug}/items`

---

#### update_collection_item

```python
def update_collection_item(
    collection_slug: str,
    item_object_id: str,
    *,
    note: Optional[str] = None,
    position: Optional[int] = None,
    token: Optional[str] = None,
) -> CollectionItem
```

**API Endpoint**: `PATCH /api/collections/{slug}/items/{id}`

---

#### delete_collection_item

```python
def delete_collection_item(
    collection_slug: str,
    item_object_id: str,
    *,
    missing_ok: bool = False,
    token: Optional[str] = None,
) -> None
```

**API Endpoint**: `DELETE /api/collections/{slug}/items/{id}`

---

## Elixir Implementation Spec

### Module: `HfHub.Collections`

```elixir
defmodule HfHub.Collections do
  @moduledoc """
  Collections API for organizing models, datasets, and spaces.
  """

  alias HfHub.Collections.{Collection, CollectionItem}

  @type item_type :: :model | :dataset | :space | :paper
  @type sort :: :last_modified | :trending | :upvotes

  @doc """
  Lists collections with optional filters.

  ## Options

  - `:owner` - Filter by owner username
  - `:item` - Filter by item (e.g., "bert-base-uncased")
  - `:sort` - Sort by :last_modified, :trending, or :upvotes
  - `:token` - Authentication token
  """
  @spec list(keyword()) :: {:ok, Enumerable.t(Collection.t())} | {:error, term()}
  def list(opts \\ [])

  @doc """
  Gets a collection by slug.

  ## Examples

      {:ok, collection} = HfHub.Collections.get("user/my-llm-collection-123abc")
  """
  @spec get(String.t(), keyword()) :: {:ok, Collection.t()} | {:error, term()}
  def get(slug, opts \\ [])

  @doc """
  Creates a new collection.

  ## Options

  - `:namespace` - Organization namespace (default: current user)
  - `:description` - Collection description
  - `:private` - Private collection (default: false)
  - `:exists_ok` - Don't error if exists (default: false)

  ## Examples

      {:ok, collection} = HfHub.Collections.create("My LLM Collection",
        description: "Best open-source LLMs")
  """
  @spec create(String.t(), keyword()) :: {:ok, Collection.t()} | {:error, term()}
  def create(title, opts \\ [])

  @doc """
  Updates collection metadata.

  ## Options

  - `:title` - New title
  - `:description` - New description
  - `:private` - Change visibility
  - `:position` - Reorder position
  - `:theme` - Collection theme
  """
  @spec update(String.t(), keyword()) :: {:ok, Collection.t()} | {:error, term()}
  def update(slug, opts \\ [])

  @doc """
  Deletes a collection.
  """
  @spec delete(String.t(), keyword()) :: :ok | {:error, term()}
  def delete(slug, opts \\ [])

  @doc """
  Adds an item to a collection.

  ## Examples

      {:ok, item} = HfHub.Collections.add_item("user/collection-123",
        "bert-base-uncased", :model, note: "Best BERT model")
  """
  @spec add_item(String.t(), String.t(), item_type(), keyword()) ::
    {:ok, CollectionItem.t()} | {:error, term()}
  def add_item(slug, item_id, item_type, opts \\ [])

  @doc """
  Updates a collection item.
  """
  @spec update_item(String.t(), String.t(), keyword()) ::
    {:ok, CollectionItem.t()} | {:error, term()}
  def update_item(slug, item_object_id, opts \\ [])

  @doc """
  Removes an item from a collection.
  """
  @spec delete_item(String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def delete_item(slug, item_object_id, opts \\ [])
end
```

### Data Structures

```elixir
defmodule HfHub.Collections.Collection do
  defstruct [
    :slug,
    :title,
    :description,
    :owner,
    :private,
    :items,
    :upvotes,
    :created_at,
    :updated_at,
    :theme,
    :position
  ]

  @type t :: %__MODULE__{
    slug: String.t(),
    title: String.t(),
    description: String.t() | nil,
    owner: String.t(),
    private: boolean(),
    items: [HfHub.Collections.CollectionItem.t()],
    upvotes: non_neg_integer(),
    created_at: DateTime.t(),
    updated_at: DateTime.t(),
    theme: String.t() | nil,
    position: non_neg_integer()
  }
end

defmodule HfHub.Collections.CollectionItem do
  defstruct [:id, :item_id, :item_type, :note, :position, :added_at]

  @type t :: %__MODULE__{
    id: String.t(),
    item_id: String.t(),
    item_type: :model | :dataset | :space | :paper,
    note: String.t() | nil,
    position: non_neg_integer(),
    added_at: DateTime.t()
  }
end
```

---

## Test Scenarios

1. List all collections
2. List filtered by owner
3. List filtered by item
4. List sorted by trending
5. Get collection details
6. Create public collection
7. Create private collection
8. Update title and description
9. Change visibility
10. Delete collection
11. Delete with missing_ok
12. Add model to collection
13. Add dataset to collection
14. Add with note
15. Update item note
16. Reorder item
17. Remove item
18. Error: add duplicate item
19. Error: access private collection
