# hf_hub_ex Remaining Work for Tinker Parity

**Date:** 2025-12-21
**Python Reference:** `./huggingface_hub/` (huggingface_hub Python library)
**Priority Legend:** CRITICAL (blocks loaders), HIGH (needed for streaming), MEDIUM (nice to have)

---

## Executive Summary

| Category | Priority | Effort | Status |
|----------|----------|--------|--------|
| list_repo_tree API | CRITICAL | 6h | Not started |
| dataset_splits API | CRITICAL | 4h | Not started |
| DatasetFiles module | CRITICAL | 8h | Not started |
| Archive extraction | CRITICAL | 10h | Not started |
| Config fallback parsing | HIGH | 5h | Not started |
| Progress/resume download | HIGH | 4h | Partial |
| **Total** | - | **37h (~5 days)** | - |

---

## CRITICAL - API Gaps (Blocks Dataset Loading)

### 1. list_repo_tree/2 - Recursive Repository Tree Listing

**Status:** Missing
**Priority:** CRITICAL
**Blocks:** Split discovery, config enumeration, DataFiles resolution

**Current State:**
- `HfHub.Api.list_files/2` exists but only returns flat siblings list from dataset_info
- Does not traverse subdirectories
- Cannot discover nested file structures like `data/train/`, `data/config1/`, etc.

**Python Reference:**
```python
# huggingface_hub/hf_api.py lines 3023-3152
def list_repo_tree(
    repo_id: str,
    path_in_repo: Optional[str] = None,
    recursive: bool = False,
    expand: bool = False,
    revision: Optional[str] = None,
    repo_type: Optional[str] = None,
    token: Union[str, bool, None] = None,
) -> Iterable[Union[RepoFile, RepoFolder]]
```

**Required Implementation:**
```elixir
@spec list_repo_tree(HfHub.repo_id(), keyword()) ::
  {:ok, [HfHub.repo_file() | HfHub.repo_folder()]} | {:error, term()}

def list_repo_tree(repo_id, opts \\ []) do
  # Call GET /api/{repo_type}s/{repo_id}/tree/{revision}/{path_in_repo}
  # Support params: recursive=true, expand=true
  # Return list of %{type: "file", path: ..., size: ..., blob_id: ...}
  #             or %{type: "folder", path: ..., tree_id: ...}
end
```

**Endpoint:** `GET /api/datasets/{repo_id}/tree/{revision}?recursive=true&expand=false`

**Effort:** 6 hours (includes pagination support)

---

### 2. HfHub.DatasetFiles - Config/Split to File Path Resolution

**Status:** Missing
**Priority:** CRITICAL
**Blocks:** load_dataset(config, split)

**Current State:** No module exists

**Required Functionality:**
- Given (repo_id, config, split), return list of file paths
- Handle patterns: `data/{split}-*.parquet`, `{config}/data/{split}-*.parquet`
- Infer splits from file naming conventions when metadata unavailable

**Implementation Plan:**
```elixir
defmodule HfHub.DatasetFiles do
  @spec resolve(repo_id, config, split, keyword()) ::
    {:ok, [String.t()]} | {:error, term()}
  def resolve(repo_id, config, split, opts \\ [])

  @spec infer_split(filename :: String.t()) :: String.t() | nil
  def infer_split("data/train-" <> _), do: "train"
  def infer_split("data/test-" <> _), do: "test"
  def infer_split("data/validation-" <> _), do: "validation"
end
```

**Dependencies:** list_repo_tree/2

**Effort:** 8 hours

---

### 3. dataset_splits/2 - Enumerate Splits for a Config

**Status:** Missing
**Priority:** CRITICAL
**Blocks:** Discovery of available splits

**Current State:**
- `dataset_configs/2` exists (returns config names from cardData)
- No equivalent for splits

**Required Implementation:**
```elixir
@spec dataset_splits(HfHub.repo_id(), keyword()) ::
  {:ok, [String.t()]} | {:error, term()}
def dataset_splits(repo_id, opts \\ []) do
  config = Keyword.get(opts, :config, "default")

  with {:ok, tree} <- list_repo_tree(repo_id, recursive: true, repo_type: :dataset),
       files <- Enum.filter(tree, &(&1.type == "file")),
       splits <- extract_split_names(files, config) do
    {:ok, Enum.uniq(splits)}
  end
end
```

**Effort:** 4 hours

---

## CRITICAL - Download & Extraction Gaps

### 4. Archive Extraction Support

**Status:** Missing
**Priority:** CRITICAL
**Blocks:** Datasets distributed as archives (zip, tar.gz, tar.xz)

**Current State:**
- `HfHub.Download.hf_hub_download/1` downloads files
- No post-download extraction
- Files left as compressed archives

**Required Formats:**
- `.zip` (unzip via Erlang :zip)
- `.tar` (tar extract via System.cmd)
- `.tar.gz`, `.tgz` (gunzip + tar)
- `.tar.xz` (xz decompress + tar)
- `.gz` (gunzip single file via :zlib)

**Implementation Plan:**
```elixir
defmodule HfHub.Extract do
  @spec extract(archive_path, dest_dir, keyword()) ::
    {:ok, %{files: [String.t()], total_size: integer()}} | {:error, term()}
  def extract(archive_path, dest_dir, opts \\ [])

  @spec detect_archive_type(String.t()) :: atom() | {:tar, atom()}
  def detect_archive_type(path)
end
```

**Effort:** 10 hours

---

## HIGH - Robustness & Fallbacks

### 5. Robust Dataset Config Parsing with Fallback

**Status:** Partial
**Priority:** HIGH
**Blocks:** Datasets without cardData metadata

**Current State:**
- `dataset_configs/2` only reads cardData
- Returns empty list if cardData missing
- No tree-based inference

**Required Fallback Strategy:**
```elixir
def dataset_configs(repo_id, opts \\ []) do
  case get_configs_from_card_data(repo_id, token) do
    {:ok, configs} when configs != [] -> {:ok, configs}
    _ -> infer_configs_from_tree(repo_id, token)
  end
end
```

**Effort:** 5 hours

---

### 6. Enhanced Resume Download with Validation

**Status:** Partial
**Priority:** HIGH

**Current State:**
- `resume_download/1` exists
- Uses HTTP Range requests
- No checksum validation after resume
- No state persistence for crash recovery

**Enhancements Needed:**
- Add checksum validation after resume
- Add state file for resume metadata
- Add automatic retry logic

**Effort:** 4 hours

---

## MEDIUM - Nice to Have

### 7. HfHub.FS.open/1 - Unified File Access

**Status:** Missing
**Priority:** MEDIUM

**Purpose:** Unified API for opening files from different sources

```elixir
defmodule HfHub.FS do
  @spec open(String.t(), keyword()) :: {:ok, File.Stream.t()} | {:error, term()}
  def open("hf://" <> path, opts), do: open_hf_path(path, opts)
  def open("http" <> _ = url, opts), do: open_http(url, opts)
  def open(local_path, opts), do: File.open(local_path, [:read | opts])
end
```

**Effort:** 6 hours

---

### 8. Subfolder Support in Downloads

**Status:** Missing
**Priority:** MEDIUM

**Current Gap:** Can't specify subfolder separately from filename

**Effort:** 2 hours

---

### 9. Enhanced Cache Introspection

**Status:** Basic
**Priority:** MEDIUM

**Current State:** `cache_stats/0` provides basic stats only

**Enhancements:**
- `list_cached_repos/0`
- `repo_cache_info/1`
- `find_in_cache/1`

**Effort:** 3 hours

---

## Implementation Sequencing

### Phase 1: Critical API Gaps (2-3 days)
1. list_repo_tree/2 - Foundation for everything else
2. dataset_splits/2 - Split discovery
3. HfHub.DatasetFiles module - File resolution

### Phase 2: Extraction & Download (2-3 days)
4. HfHub.Extract module - Archive support
5. Extraction integration in hf_hub_download/1
6. Enhanced resume_download with validation

### Phase 3: Robustness & Polish (1-2 days)
7. dataset_configs/2 fallback to tree inference
8. Subfolder support
9. FS.open/1 unified access
10. Enhanced cache introspection

**Total Estimated Effort:** 6-9 days

---

## Files Changed Summary

**Modified Files:**
1. `lib/hf_hub/api.ex` - Add list_repo_tree, dataset_splits, enhance dataset_configs
2. `lib/hf_hub/http.ex` - Add pagination support
3. `lib/hf_hub/download.ex` - Add extraction, progress, resume
4. `lib/hf_hub/cache.ex` - Enhanced introspection
5. `mix.exs` - Add optional dependencies

**New Files:**
1. `lib/hf_hub/dataset_files.ex`
2. `lib/hf_hub/extract.ex`
3. `lib/hf_hub/fs_open.ex`

---

## Success Criteria

hf_hub_ex achieves tinker parity when:

1. `HfHub.Api.list_repo_tree/2` can recursively list all files
2. `HfHub.Api.dataset_splits/2` discovers available splits
3. `HfHub.DatasetFiles.resolve/3` maps config+split to file paths
4. `HfHub.Download.hf_hub_download/1` can extract archives
5. `HfHub.Api.dataset_configs/2` falls back to tree inference
6. All tinker-cookbook dataset loaders work without modification
7. OpenThoughts-1.2M can stream efficiently
8. Vision datasets can download and extract

---

**Document Status:** Complete
**Last Updated:** 2025-12-21
