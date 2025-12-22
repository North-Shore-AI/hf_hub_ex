# Unified Implementation Plan

## Phase 1: Core Listing + File Resolution (P0)

### 1.1 list_repo_tree/2
- Status: Implemented with pagination (Link header) and tree entry parsing.
- Tests: `test/hf_hub/api_tree_test.exs`, `test/hf_hub/http_test.exs`.
- Notes: Supports `path_in_repo`, `recursive`, `expand`, `repo_type`, `revision`, `token`.

### 1.2 list_files/2 upgrade
- Status: Implemented (datasets default to tree listing; recursive option supported).
- Tests: `test/hf_hub/api_tree_test.exs`.
- Notes: Non-recursive model/space listings keep siblings fallback.

### 1.3 dataset_configs/2 fallback
- Status: Implemented (cardData -> dataset_infos.json -> tree inference).
- Tests: `test/hf_hub/api_dataset_fallback_test.exs`.

### 1.4 DatasetFiles resolver
- Status: Implemented (`HfHub.DatasetFiles` with config/split resolution).
- Tests: `test/hf_hub/dataset_files_test.exs`.

## Phase 2: Dataset Operations (P1)

### 2.1 dataset_splits/2
- Status: Implemented (dataset_infos.json + tree inference).
- Tests: `test/hf_hub/api_dataset_fallback_test.exs`.

### 2.2 Archive extraction
- Status: Implemented (zip/tar.gz/tgz/tar.xz/gz extraction + download option).
- Tests: `test/hf_hub/extract_test.exs`, `test/hf_hub/download_test.exs`.

## Phase 3: Nice To Have (P2)
- Cache parity with huggingface_hub (refs/blobs, commit-hash snapshots, ETag validation).
- Retry/backoff for 429/5xx and rate limit handling.
- Token lookup from HF_HOME/stored tokens; `local_files_only` support.
- Progress callbacks for large downloads.
