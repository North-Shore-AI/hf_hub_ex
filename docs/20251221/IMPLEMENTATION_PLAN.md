# Implementation Plan for Tinker Parity

**Date:** 2025-12-21
**Total Estimated Effort:** 6-9 days

---

## Overview

This plan details the exact file changes, new modules, and testing required to achieve tinker parity for hf_hub_ex.

---

## Phase 1: Critical API Foundation (Days 1-3)

### Task 1.1: Implement list_repo_tree/2

**File:** `lib/hf_hub/api.ex`

**Changes Required:**
1. Add new function `list_repo_tree/2` after `list_files/2`
2. Add typespecs for tree entries
3. Implement pagination support

**Key Implementation Points:**
- Endpoint: `GET /api/{repo_type}s/{repo_id}/tree/{revision}/{path_in_repo}`
- Support `recursive: true` and `expand: true` params
- Handle pagination via Link header
- Return both file and folder objects

**HTTP Module Changes:**

**File:** `lib/hf_hub/http.ex`

Add pagination support:
```elixir
@spec get_paginated(String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
def get_paginated(path, opts) do
  get_paginated_recursive(path, opts, [])
end

defp get_paginated_recursive(path, opts, acc) do
  case get(path, opts) do
    {:ok, items} when is_list(items) ->
      new_acc = acc ++ items
      handle_pagination(path, opts, new_acc)
    {:error, reason} ->
      {:error, reason}
  end
end
```

**Effort:** 6 hours

---

### Task 1.2: Implement dataset_splits/2

**File:** `lib/hf_hub/api.ex`

Add after `dataset_configs/2`:
- Try dataset_infos.json first
- Fallback to tree inference
- Extract split names from file patterns

**Effort:** 4 hours

---

### Task 1.3: Create HfHub.DatasetFiles Module

**New File:** `lib/hf_hub/dataset_files.ex`

**Key Functions:**
- `resolve/4` - Map config+split to file paths
- `infer_split/1` - Extract split from filename
- `infer_config/1` - Extract config from path

**Effort:** 8 hours

---

## Phase 2: Extraction & Download (Days 4-5)

### Task 2.1: Create HfHub.Extract Module

**New File:** `lib/hf_hub/extract.ex`

**Key Functions:**
- `extract/3` - Main extraction function
- `detect_archive_type/1` - Detect from extension
- `extract_zip/3` - Using Erlang :zip
- `extract_tar/4` - Using System.cmd
- `extract_gzip/3` - Using :zlib

**Dependencies to Add (mix.exs):**
```elixir
{:easytar, "~> 0.1.0", optional: true}  # Pure Elixir TAR
```

**Effort:** 8 hours

---

### Task 2.2: Integrate Extraction in Download

**File:** `lib/hf_hub/download.ex`

Modify `hf_hub_download/1`:
- Add `:extract` option
- Add `:extract_dir` option
- Call HfHub.Extract after download

**Effort:** 2 hours

---

## Phase 3: Robustness & Fallbacks (Days 6-7)

### Task 3.1: Enhanced dataset_configs with Fallback

**File:** `lib/hf_hub/api.ex`

- Try cardData first
- Fallback to dataset_infos.json
- Fallback to tree inference

**Effort:** 5 hours

---

### Task 3.2: Download Enhancements

**File:** `lib/hf_hub/download.ex`

1. Add progress callbacks
2. Add resume state persistence
3. Add checksum validation

**Effort:** 6 hours

---

## Phase 4: Polish (Days 8-9)

### Task 4.1: Subfolder Support

**File:** `lib/hf_hub/download.ex`

**Effort:** 2 hours

---

### Task 4.2: HfHub.FS.open/1

**New File:** `lib/hf_hub/fs_open.ex`

Unified file access for local, hf://, and http:// paths

**Effort:** 6 hours

---

### Task 4.3: Enhanced Cache Introspection

**File:** `lib/hf_hub/cache.ex`

Add:
- `list_cached_repos/0`
- `repo_cache_info/1`
- `find_in_cache/1`

**Effort:** 3 hours

---

## Testing Strategy

### Unit Tests (Per Module)
- Test with mocked HTTP responses
- Test edge cases (missing files, malformed data)
- Test error handling

### Integration Tests
- Use real HuggingFace API (cached responses)
- Test datasets: openai/gsm8k, mnist, squad
- Test large files (with small test archives)

### Test Datasets
1. **openai/gsm8k** - Standard structure
2. **mnist** - Multi-config
3. **squad** - Validation split
4. **EleutherAI/hendrycks_math** - Nested

**Total Test Effort:** 8-10 hours across all phases

---

## Files Changed Summary

### Modified Files
1. `lib/hf_hub/api.ex` - Add list_repo_tree, dataset_splits, enhance dataset_configs
2. `lib/hf_hub/http.ex` - Add pagination support
3. `lib/hf_hub/download.ex` - Add extraction, progress, resume
4. `lib/hf_hub/cache.ex` - Enhanced introspection
5. `mix.exs` - Add optional dependencies

### New Files
1. `lib/hf_hub/dataset_files.ex`
2. `lib/hf_hub/extract.ex`
3. `lib/hf_hub/fs_open.ex`

### Test Files
1. `test/hf_hub/api_test.exs` - Enhanced
2. `test/hf_hub/dataset_files_test.exs` - New
3. `test/hf_hub/extract_test.exs` - New
4. `test/hf_hub/download_test.exs` - Enhanced

**Total Lines of Code:** ~2000-2500 LOC

---

## Success Metrics

After implementation, verify:
1. Can list full tree for openai/gsm8k
2. Can discover "train" and "test" splits
3. Can resolve split files correctly
4. Can download and extract tar.gz
5. Dataset configs fallback works
6. All tinker datasets loadable

---

## Risk Mitigation

### Risks
1. **API changes** - HuggingFace might change endpoints
2. **Large file handling** - Memory issues with huge archives
3. **Platform compatibility** - TAR/ZIP support varies

### Mitigations
1. Version API calls, add fallbacks
2. Stream extraction, chunk processing
3. Test on Linux/Mac/Windows, provide pure Elixir alternatives

---

## Maintenance Plan

After implementation:
1. **Monitor HF API changes** - Subscribe to huggingface_hub releases
2. **Update documentation** - Keep examples current
3. **Performance profiling** - Optimize hot paths
4. **Community feedback** - Iterate based on usage

---

**Document Status:** Complete
**Last Updated:** 2025-12-21
