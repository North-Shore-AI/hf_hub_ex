# hf_hub_ex Current Implementation State

## Test Status
- `mix test` (hf_hub_ex): 138 tests, 0 failures, 17 excluded (tag :live)

## Working Functions (with tests)
| Module | Function | Test File | Notes |
|--------|----------|-----------|-------|
| HfHub.Auth | get_token/0, set_token/1, logout/0, validate_token/1, auth_headers/1, login/1, whoami/0 | test/hf_hub/auth_test.exs | Uses HF_TOKEN env or app config; login validate uses whoami |
| HfHub.Config | endpoint/0, cache_dir/0, http_opts/0, cache_opts/0 | test/hf_hub/config_test.exs | cache_dir honors HF_HUB_CACHE and HF_HOME |
| HfHub.FS | cache_dir/0, ensure_cache_dir/0, repo_path/2, file_path/4, lock_file/2, unlock_file/1 | test/hf_hub/fs_test.exs | cache_dir here ignores HF_HUB_CACHE/HF_HOME (app config only) |
| HfHub.Cache | cached?/1, cache_path/1, clear_cache/1, evict_lru/1, validate_integrity/0 | test/hf_hub/cache_test.exs | LRU eviction uses atime, integrity checks sha256 files |
| HfHub.Download | hf_hub_download/1, download_stream/1, snapshot_download/1, resume_download/1 | test/hf_hub/download_test.exs | Tested with Bypass; snapshot_download uses list_files; extract option supported |
| HfHub.HTTP | get/2, get_paginated/2, post/3, download_file/3 | test/hf_hub/http_test.exs | Basic status handling (401/403/404) + pagination |
| HfHub.Api | list_repo_tree/2, list_files/2, dataset_configs/2, dataset_splits/2, extract_config_names/1 | test/hf_hub/api_tree_test.exs, test/hf_hub/api_dataset_fallback_test.exs, test/hf_hub/api_test.exs | Tree listing, recursive file listing, config/split inference |
| HfHub.DatasetFiles | resolve/4, resolve_from_tree/3, splits_from_tree/2, configs_from_tree/1 | test/hf_hub/dataset_files_test.exs | Config + split file resolution |
| HfHub.Extract | extract/2, detect_archive_type/1 | test/hf_hub/extract_test.exs | zip/tar.gz/tgz/tar.xz/gz extraction |

## Partially Working (no tests or missing behaviors)
| Module | Function | Issue |
|--------|----------|-------|
| HfHub.Api | model_info/2, dataset_info/2, space_info/2 | No direct tests; lacks expand/files_metadata options parity |
| HfHub.Api | list_models/1, list_datasets/1 | No direct tests; no pagination handling |
| HfHub.Cache | cache_stats/0 | Reports in-memory state only; no on-disk scan; no tests |
| HfHub.Download | snapshot_download/1 | Works for small repos; relies on list_files siblings (large repo risk) |

## Not Implemented
| Required Function | Priority | Blocks |
|-------------------|----------|--------|
| Token lookup from HF_HOME/stored tokens | P2 | gated datasets when HF_TOKEN not set |
