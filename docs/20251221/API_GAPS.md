# Detailed API Gap Analysis for Tinker Parity

**Date:** 2025-12-21
**Python Reference:** `./huggingface_hub/src/huggingface_hub/hf_api.py`

---

## 1. list_repo_tree vs list_files

### Current Implementation

**File:** `lib/hf_hub/api.ex` (lines 334-349)

```elixir
def list_files(repo_id, opts \\ []) do
  # Calls repo_info_internal which returns dataset_info
  # Extracts "siblings" field - FLAT list only
  files = Map.get(info, "siblings", []) |> parse_siblings()
  {:ok, files}
end
```

### Limitations

1. **No directory traversal** - Returns only top-level files
2. **No folder objects** - Can't distinguish files from folders
3. **No path_in_repo** - Can't list contents of subdirectory
4. **No recursive option** - Can't get full tree in one call
5. **No expand option** - Can't get last_commit metadata

### Python Reference

```python
# huggingface_hub/hf_api.py:3023-3152
def list_repo_tree(
    repo_id: str,
    path_in_repo: Optional[str] = None,  # Can list subdirectory
    *,
    recursive: bool = False,              # Can get full tree
    expand: bool = False,                 # Can get metadata
    revision: Optional[str] = None,
    repo_type: Optional[str] = None,
    token: Union[str, bool, None] = None,
) -> Iterable[Union[RepoFile, RepoFolder]]:  # Returns folders too!
```

### Required Elixir Implementation

```elixir
defmodule HfHub.Api do
  @type repo_file :: %{
    type: :file,
    path: String.t(),
    size: non_neg_integer(),
    blob_id: String.t(),
    lfs: lfs_info() | nil,
    last_commit: commit_info() | nil,
    security: security_info() | nil
  }

  @type repo_folder :: %{
    type: :folder,
    path: String.t(),
    tree_id: String.t(),
    last_commit: commit_info() | nil
  }

  @spec list_repo_tree(HfHub.repo_id(), keyword()) ::
    {:ok, [repo_file() | repo_folder()]} | {:error, term()}
  def list_repo_tree(repo_id, opts \\ []) do
    repo_type = Keyword.get(opts, :repo_type, :model)
    revision = Keyword.get(opts, :revision, "main")
    path_in_repo = Keyword.get(opts, :path_in_repo)
    recursive = Keyword.get(opts, :recursive, false)
    expand = Keyword.get(opts, :expand, false)
    token = Keyword.get(opts, :token)

    encoded_path = if path_in_repo do
      "/" <> URI.encode(path_in_repo, &URI.char_unreserved?/1)
    else
      ""
    end

    path = "/api/#{repo_type}s/#{repo_id}/tree/#{revision}#{encoded_path}"
    params = [recursive: recursive, expand: expand]

    case HfHub.HTTP.get_paginated(path, token: token, params: params) do
      {:ok, items} ->
        entries = Enum.map(items, &parse_tree_entry/1)
        {:ok, entries}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_tree_entry(%{"type" => "file"} = item) do
    %{
      type: :file,
      path: Map.fetch!(item, "path"),
      size: Map.fetch!(item, "size"),
      blob_id: Map.fetch!(item, "oid"),
      lfs: parse_lfs(Map.get(item, "lfs")),
      last_commit: parse_last_commit(Map.get(item, "lastCommit")),
      security: parse_security(Map.get(item, "security"))
    }
  end

  defp parse_tree_entry(%{"type" => "directory"} = item) do
    %{
      type: :folder,
      path: Map.fetch!(item, "path"),
      tree_id: Map.fetch!(item, "oid"),
      last_commit: parse_last_commit(Map.get(item, "lastCommit"))
    }
  end
end
```

### Endpoint Details

- **URL:** `GET /api/datasets/{repo_id}/tree/{revision}/{path_in_repo}`
- **Query Params:**
  - `recursive=true|false` - Get full tree or just immediate children
  - `expand=true|false` - Include last_commit and security metadata
- **Pagination:** Returns 1000 items per page (50 if expand=true)
- **Response:** JSON array of tree items

---

## 2. Split Enumeration Gap

### Problem

No way to discover available splits (train/test/validation) for a dataset config.

### Python Ecosystem Solution

```python
from datasets import get_dataset_split_names

splits = get_dataset_split_names("openai/gsm8k", config_name="main")
# Returns: ['train', 'test']
```

### Implementation Strategy

```elixir
defmodule HfHub.Api do
  @spec dataset_splits(HfHub.repo_id(), keyword()) ::
    {:ok, [String.t()]} | {:error, term()}
  def dataset_splits(repo_id, opts \\ []) do
    config = Keyword.get(opts, :config, "default")
    token = Keyword.get(opts, :token)

    # Strategy 1: Try dataset_infos.json
    case get_splits_from_infos_json(repo_id, config, token) do
      {:ok, splits} when splits != [] -> {:ok, splits}
      _ ->
        # Strategy 2: Try README.md YAML
        case get_splits_from_readme(repo_id, config, token) do
          {:ok, splits} when splits != [] -> {:ok, splits}
          _ ->
            # Strategy 3: Infer from tree
            infer_splits_from_tree(repo_id, config, token)
        end
    end
  end

  defp infer_splits_from_tree(repo_id, config, token) do
    with {:ok, tree} <- list_repo_tree(repo_id,
                                       recursive: true,
                                       repo_type: :dataset,
                                       token: token) do
      files = Enum.filter(tree, &(&1.type == :file))
      splits = extract_split_names_from_files(files, config)
      {:ok, Enum.sort(splits)}
    end
  end

  # Pattern matching for common dataset layouts
  defp extract_split_from_path(path, _config) do
    cond do
      # Pattern: data/train-00000.parquet
      String.match?(path, ~r|^data/([^-/]+)-\d+|) ->
        [_, split] = Regex.run(~r|^data/([^-/]+)-\d+|, path)
        split
      # Pattern: train/data-00000.parquet
      String.match?(path, ~r|^([^/]+)/data-\d+|) ->
        [_, split] = Regex.run(~r|^([^/]+)/data-\d+|, path)
        split
      # Pattern: config_name/split/data.parquet
      String.match?(path, ~r|^[^/]+/([^/]+)/|) ->
        path |> Path.split() |> Enum.at(1)
      true ->
        nil
    end
  end
end
```

### Common Split Naming Patterns

1. `data/train-*.parquet` → "train"
2. `data/test-*.parquet` → "test"
3. `data/validation-*.parquet` → "validation"
4. `train/*.parquet` → "train" (directory-based)
5. `{config}/train/*.parquet` → "train" (config subdirectory)

---

## 3. Dataset Card Parsing - Config Discovery

### Current Implementation

```elixir
# lib/hf_hub/api.ex:269-281
def dataset_configs(repo_id, opts \\ []) do
  case HfHub.HTTP.get("/api/datasets/#{repo_id}", token: token) do
    {:ok, data} ->
      card_data = Map.get(data, "cardData")
      {:ok, extract_config_names(card_data)}  # Returns [] if nil
  end
end

def extract_config_names(nil), do: []
```

### Problems

1. Many datasets don't have cardData field
2. Returns empty list instead of inferring from tree
3. No fallback mechanism

### Enhanced Implementation with Fallback

```elixir
def dataset_configs(repo_id, opts \\ []) do
  token = Keyword.get(opts, :token)

  case get_configs_from_card_data(repo_id, token) do
    {:ok, configs} when configs != [] -> {:ok, configs}
    _ ->
      case get_configs_from_infos_json(repo_id, token) do
        {:ok, configs} when configs != [] -> {:ok, configs}
        _ -> infer_configs_from_tree(repo_id, token)
      end
  end
end

defp infer_configs_from_tree(repo_id, token) do
  with {:ok, tree} <- list_repo_tree(repo_id,
                                     recursive: true,
                                     repo_type: :dataset,
                                     token: token) do
    configs = tree
    |> Enum.filter(&is_config_directory?/1)
    |> Enum.map(fn folder -> Path.basename(folder.path) end)
    |> Enum.uniq()

    case configs do
      [] -> {:ok, ["default"]}
      configs -> {:ok, configs}
    end
  end
end
```

---

## 4. DataFiles Resolution - The Core Problem

### What CrucibleDatasets Needs

```elixir
# Given:
repo_id = "openai/gsm8k"
config = "main"
split = "train"

# Need to return:
files = ["data/train-00000-of-00001.parquet"]

# For multi-shard datasets:
repo_id = "HuggingFaceM4/OpenThoughts-114k"
files = [
  "data/train-00000-of-00042.parquet",
  "data/train-00001-of-00042.parquet",
  # ... 40 more files
]
```

### Implementation

```elixir
defmodule HfHub.DatasetFiles do
  @moduledoc """
  Resolves dataset configuration and split to actual file paths.
  """

  @spec resolve(repo_id, config, split, keyword()) ::
    {:ok, [String.t()]} | {:error, term()}
  def resolve(repo_id, config, split, opts \\ []) do
    token = Keyword.get(opts, :token)

    with {:ok, tree} <- HfHub.Api.list_repo_tree(repo_id,
                                                  recursive: true,
                                                  repo_type: :dataset,
                                                  token: token) do
      files = tree
      |> Enum.filter(&(&1.type == :file))
      |> Enum.filter(&matches_config_split?(&1, config, split))
      |> Enum.map(& &1.path)
      |> Enum.sort()

      case files do
        [] -> {:error, :no_files_found}
        files -> {:ok, files}
      end
    end
  end

  defp matches_config_split?(file, config, split) do
    path = file.path

    cond do
      # Pattern 1: data/{split}-*.parquet
      String.match?(path, ~r|^data/#{split}-\d+.*\.parquet$|) -> true
      # Pattern 2: {config}/data/{split}-*.parquet
      String.match?(path, ~r|^#{config}/data/#{split}-\d+.*\.parquet$|) -> true
      # Pattern 3: {config}/{split}/*.parquet
      String.match?(path, ~r|^#{config}/#{split}/.*\.parquet$|) -> true
      # Pattern 4: {split}/*.parquet (no config subdir)
      config == "default" and String.match?(path, ~r|^#{split}/.*\.parquet$|) -> true
      # Pattern 5: data/{config}-{split}-*.parquet
      String.match?(path, ~r|^data/#{config}-#{split}-\d+.*\.parquet$|) -> true
      true -> false
    end
  end
end
```

---

## Summary: Critical API Gaps

| Gap | Current State | Required | Priority | Effort |
|-----|---------------|----------|----------|--------|
| list_repo_tree | Flat siblings only | Recursive tree with folders | CRITICAL | 6h |
| dataset_splits | Missing | Enumerate train/test/val | CRITICAL | 4h |
| DatasetFiles.resolve | Missing | Map config+split to files | CRITICAL | 8h |
| Config fallback | cardData only | Tree inference | HIGH | 5h |
| Split inference | Missing | Pattern-based extraction | HIGH | 4h |

**Total Estimated Effort for API Gaps:** 27 hours (~3.5 days)

---

**Document Status:** Complete
**Last Updated:** 2025-12-21
