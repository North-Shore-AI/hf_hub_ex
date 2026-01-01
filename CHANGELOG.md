# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.2] - 2025-12-31

### Added
- **Bumblebee-compatible API** for seamless integration with Elixir ML pipelines
  - `HfHub.Repository` — Repository reference types (`{:hf, id}`, `{:hf, id, opts}`, `{:local, dir}`)
  - `HfHub.Hub` — ETag-based caching matching Bumblebee's `Bumblebee.HuggingFace.Hub`
  - `HfHub.RepoFiles` — Repository file listing with ETags for cache validation
  - Top-level delegations: `get_repo_files/1`, `cached_download/1,2`, `file_url/3`, `file_listing_url/3`
- `HfHub.Constants` — File names, headers, timeouts matching Python's `huggingface_hub.constants`
- `HfHub.Errors` — 30+ structured exception types matching Python's `huggingface_hub.errors`
- `HfHub.LFS` — LFS utilities for file hashing and upload info preparation
- `HfHub.HTTP.head/2` — HEAD requests for ETag-based cache validation

### Changed
- Refactored `HfHub.DatasetFiles` with extracted helper functions
- Refactored `HfHub.Download` with extracted extraction helpers
- Refactored `HfHub.HTTP` with extracted pagination helpers

## [0.1.1] - 2025-12-21

### Added
- `list_repo_tree/2` with pagination support via `HfHub.HTTP.get_paginated/2`
- `dataset_configs/2` with fallback (dataset_infos.json + tree inference)
- `dataset_splits/2` with fallback (dataset_infos.json + tree inference)
- `HfHub.DatasetFiles` resolver for config + split file paths
- `HfHub.Extract` for archive extraction (zip/tar.gz/tgz/tar.xz/gz)
- Optional `extract: true` flow in `hf_hub_download/1`

### Changed
- `list_files/2` upgraded to use tree listings for datasets/recursive mode

## [0.1.0] - 2025-12-20

Initial release with full HuggingFace Hub client functionality:

- **HfHub.Api**: Repository info, file listings, model/dataset/space queries
- **HfHub.Download**: File downloads with caching and resume support
- **HfHub.Cache**: Cache management with GenServer-based tracking
- **HfHub.Auth**: Token management and authentication
- **HfHub.HTTP**: Req-based HTTP client with retry logic
- **HfHub.FS**: Cache directory and file locking utilities
- **HfHub.Config**: Configuration with environment variable support

[0.1.2]: https://github.com/North-Shore-AI/hf_hub_ex/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/North-Shore-AI/hf_hub_ex/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/North-Shore-AI/hf_hub_ex/releases/tag/v0.1.0
