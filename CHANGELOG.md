# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[0.1.1]: https://github.com/North-Shore-AI/hf_hub_ex/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/North-Shore-AI/hf_hub_ex/releases/tag/v0.1.0
