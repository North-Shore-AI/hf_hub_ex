# hf_hub_ex Status and Extension Plan (Tinker Parity)

Date: 2025-12-21
Scope: What hf_hub_ex already provides and what must be added to support tinker-cookbook parity
without creating extra dependency repos.

## Current Implemented Surface (in repo)

API and metadata
- HfHub.Api.dataset_info/2 (dataset metadata)
- HfHub.Api.dataset_configs/2 (config names from cardData)
- HfHub.Api.list_files/2 (files via dataset info siblings)

Downloads and cache
- HfHub.Download.hf_hub_download/1 (download + cache)
- HfHub.Download.snapshot_download/1 (download repo snapshot)
- HfHub.Download.download_stream/1 (streaming download)
- HfHub.Download.resume_download/1 (resume)
- HfHub.Cache.* (cache stats, LRU, integrity)

Filesystem utilities
- HfHub.FS.repo_path/2
- HfHub.FS.file_path/4
- HfHub.FS.lock_file/2 + unlock_file/1

Auth + config
- HfHub.Auth.*
- HfHub.Config.*
- HfHub.HTTP.*

## Gaps For Tinker Parity

1) Repo tree listing for datasets
- list_files/2 is backed by dataset info siblings; it does not traverse subdirectories.
- Need: list_repo_tree/2 or equivalent to support split/config discovery at depth.

2) Split enumeration
- Need explicit split listing per config (train/test/validation/other).
- Should derive from repo tree or a metadata source.

3) DataFiles resolution
- Need mapping of config + split to file paths, including patterns like
  data/train-00000-of-000xx.parquet and config-specific directories.

4) Extraction support for archives
- Download currently writes raw files; no extraction pipeline for zip/tar/gz/xz.
- Tinker parity requires extraction for datasets that ship archives.

5) Unified file open abstraction
- HfHub.FS is cache path utilities only; no hf:// or http:// open/read API.
- Need a simple file open/read abstraction to unify local and remote files.

6) Dataset card parsing robustness
- dataset_configs/2 depends on cardData; some repos do not expose it cleanly.
- Need a fallback path (inspect tree and infer configs/splits).

## Decision: Extend hf_hub_ex vs New Subprojects

For tinker parity, extend hf_hub_ex in-place rather than creating new repos.
Rationale: hf_hub_ex already provides most of hf_hub_ex + hf_fs_ex + hf_download_ex functionality.
Splitting it now adds overhead without short-term benefit.

## Proposed Extensions Inside hf_hub_ex

A) Add repo tree listing
- New API: HfHub.Api.list_repo_tree/2
- Endpoint: /api/datasets/{repo_id}/tree/{revision}
- Support recursion and directories

B) Add split/config resolver
- New module: HfHub.DatasetFiles
- Inputs: repo_id, config, split
- Output: list of file paths
- Strategy:
  - Use list_repo_tree/2
  - Apply split/config heuristics (train/test/validation + config subdirs)

C) Add extraction utilities
- New module: HfHub.Extract
- Support zip/tar/gz/xz
- Integrate with download paths

D) Add unified open/read
- New module: HfHub.FS.open/1
- Handle:
  - local file paths
  - hf://repo_id/path (resolve via cache or download)
  - http/https

E) Add dataset split list helper
- New API: HfHub.Api.dataset_splits/2
- Implementation uses list_repo_tree + naming patterns

## Integration Contract For CrucibleDatasets

CrucibleDatasets should use hf_hub_ex for:
- config names: HfHub.Api.dataset_configs/2
- file listing: HfHub.Api.list_repo_tree/2
- file download: HfHub.Download.hf_hub_download/1
- streaming: HfHub.Download.download_stream/1

This keeps dataset logic in CrucibleDatasets while hf_hub_ex owns HF mechanics.

## Open Questions
- Should extraction live in hf_hub_ex or in CrucibleDatasets? (recommended: hf_hub_ex)
- Should HfHub.Api.list_files/2 be upgraded to tree listing or kept as-is?

