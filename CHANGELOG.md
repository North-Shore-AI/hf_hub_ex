# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial project structure
- Core module stubs for API, Download, Cache, FS, and Auth
- Comprehensive README with usage examples
- Professional hexagonal logo
- MIT License
- CI/CD configuration placeholder

### Completed (2025-12-20)
- **HfHub.Config**: Configuration management with env var support (HF_TOKEN, HF_HUB_CACHE, HF_HOME)
- **HfHub.Auth**: Token management, validation, and auth header generation
- **HfHub.HTTP**: Req-based HTTP client with auth injection, JSON decoding, retry logic
- **HfHub.FS**: Cache directory management, path utilities, file locking for concurrent access
- **HfHub.Cache**: Cache checking, path lookup, clearing, statistics via GenServer
- **HfHub.Cache.Server**: GenServer for tracking cached files and stats
- **HfHub.Download**: File downloads with caching, resume support, content-addressed storage
- **HfHub.Api**: Complete Hub API client
  - `model_info/2`, `dataset_info/2`, `space_info/2` - Get metadata
  - `list_models/1`, `list_datasets/1` - List with filters and sorting
  - `list_files/2` - List files in repositories
- Full test coverage (53 tests, 0 failures)
- Working examples: list_datasets, dataset_info, download_file, list_models, cache_demo
- Zero compilation warnings
- Credo compliance

### Planned
- Snapshot downloads (download entire repos)
- Streaming downloads for large files
- LRU eviction implementation
- Repository management (create, delete, update)
- File uploads
- Inference API client
- Integration tests with live HF Hub
- Hex.pm package publication

## [0.1.0] - TBD

### Added
- First public release
- Core API client functionality
- File download and caching
- Authentication support
- Comprehensive documentation

[Unreleased]: https://github.com/North-Shore-AI/hf_hub_ex/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/North-Shore-AI/hf_hub_ex/releases/tag/v0.1.0
