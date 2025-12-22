# Gap Analysis: hf_hub_ex vs Cookbook Requirements

## Operation Coverage
| Operation | Python Function | hf_hub_ex Status | Priority |
|-----------|----------------|------------------|----------|
| Download file | hf_hub_download | Implemented; no ETag/local_dir/local_files_only | P2 |
| Archive extraction | hf_hub_download (extract) | Implemented for zip/tar.gz/tgz/tar.xz/gz | P1 |
| List repo files (recursive) | list_repo_files / list_repo_tree | Implemented via list_repo_tree/2 + pagination; list_files upgraded | P0 |
| Get dataset info | dataset_info | Implemented; no expand/files_metadata | P2 |
| List dataset configs | get_dataset_config_names | Implemented with dataset_infos.json + tree fallback | P1 |
| Resolve config+split -> files | (list_repo_tree + heuristics) | Implemented (HfHub.DatasetFiles) | P1 |
| List dataset splits | get_dataset_split_names (datasets) | Implemented (dataset_infos.json + tree inference) | P1 |
| Download snapshot | snapshot_download | Implemented; relies on list_files (tree-backed for datasets) | P2 |
| Stream file | (requests stream) | download_stream implemented | P2 |
| Cache lookup | try_to_load_from_cache | HfHub.Cache.cached?/cache_path implemented | P2 |

## Critical Gaps (P0)
- Resolved: recursive repo tree listing with pagination (`list_repo_tree/2`).
- Resolved: `list_files/2` upgraded to use tree data for datasets/recursive mode.

## High Priority Gaps (P1)
- Resolved: dataset config discovery fallback (cardData -> dataset_infos.json -> tree inference).
- Resolved: DatasetFiles resolver to map config+split to file paths.
- Resolved: dataset_splits helper to list available splits for a config.
- Resolved: archive extraction pipeline for image datasets (zip/tar.gz/tgz/tar.xz/gz).

## Low Priority Gaps (P2)
- Cache parity with huggingface_hub (refs/blobs, commit hash snapshots, ETag validation).
- Retry/backoff for 429/5xx and rate-limit handling.
- Token lookup from HF_HOME/stored tokens and `local_files_only` support.
- Progress callbacks/bandwidth control for large downloads.

## What We DON'T Need
- Repository write operations (create_repo, upload_file, create_commit, delete_repo).
- Spaces management APIs (pause, restart, hardware, secrets).
- Discussions, collections, social features, webhooks.
- Git-based repository operations (Repository class, LFS preupload).
