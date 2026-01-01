<p align="center">
  <img src="assets/hf_hub_ex.svg" alt="HfHub Logo" width="200">
</p>

<h1 align="center">HfHub</h1>

<p align="center">
  <a href="https://hex.pm/packages/hf_hub"><img src="https://img.shields.io/hexpm/v/hf_hub.svg" alt="Hex.pm"></a>
  <a href="https://hexdocs.pm/hf_hub"><img src="https://img.shields.io/badge/docs-hexdocs-blue.svg" alt="Documentation"></a>
  <a href="https://github.com/North-Shore-AI/hf_hub_ex/actions"><img src="https://img.shields.io/github/actions/workflow/status/North-Shore-AI/hf_hub_ex/ci.yml?branch=main" alt="CI"></a>
  <a href="https://github.com/North-Shore-AI/hf_hub_ex/blob/main/LICENSE"><img src="https://img.shields.io/hexpm/l/hf_hub.svg" alt="License"></a>
</p>

**Elixir client for [HuggingFace Hub](https://huggingface.co)** — dataset/model metadata, file downloads, caching, and authentication. An Elixir port of Python's [`huggingface_hub`](https://github.com/huggingface/huggingface_hub).

`hf_hub_ex` provides a robust, production-ready interface to the HuggingFace Hub API, enabling Elixir applications to seamlessly access models, datasets, and spaces. This library is designed to be the foundational layer for porting Python HuggingFace libraries (datasets, evaluate, transformers) to the BEAM ecosystem.

## Features

- **Hub API Client** — Fetch metadata for models, datasets, and spaces
- **Bumblebee Compatible** — Drop-in integration with Elixir ML pipelines via tuple-based repository API
- **Repo Tree Listing** — Recursive tree listing with pagination
- **File Downloads** — Stream files from HuggingFace repositories with resume support
- **Archive Extraction** — Optional extraction for zip/tar.gz/tgz/tar.xz/gz files
- **Smart Caching** — Local file caching with LRU eviction and ETag-based validation
- **Filesystem Utilities** — Manage local HuggingFace cache directory structure
- **Authentication** — Token-based authentication for private repositories
- **Structured Errors** — 30+ exception types matching Python's `huggingface_hub`
- **BEAM-native** — Leverages OTP, GenServers, and supervision trees for reliability
- **Type-safe** — Comprehensive typespecs and pattern matching

## Installation

Add `hf_hub` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:hf_hub, "~> 0.1.2"}
  ]
end
```

Then run:

```bash
mix deps.get
```

## Quick Start

### Authentication

Set your HuggingFace token as an environment variable or in config:

```bash
export HF_TOKEN="hf_..."
```

Or in `config/config.exs`:

```elixir
config :hf_hub,
  token: System.get_env("HF_TOKEN"),
  cache_dir: Path.expand("~/.cache/huggingface")
```

### Fetching Model Metadata

```elixir
# Get model information
{:ok, model_info} = HfHub.Api.model_info("bert-base-uncased")

IO.inspect(model_info.id)          # "bert-base-uncased"
IO.inspect(model_info.downloads)   # 123456789
IO.inspect(model_info.tags)        # ["pytorch", "bert", "fill-mask"]
```

### Downloading Files

```elixir
# Download a model file
{:ok, path} = HfHub.Download.hf_hub_download(
  repo_id: "bert-base-uncased",
  filename: "config.json",
  repo_type: :model
)

# Read the downloaded file
{:ok, config} = File.read(path)

# Download and extract an archive (returns extracted path)
{:ok, extracted_path} = HfHub.Download.hf_hub_download(
  repo_id: "albertvillanova/tmp-tests-zip",
  filename: "ds.zip",
  repo_type: :dataset,
  extract: true
)
```

### Accessing Datasets

```elixir
# Get dataset information
{:ok, dataset_info} = HfHub.Api.dataset_info("squad")

# Download dataset files
{:ok, path} = HfHub.Download.hf_hub_download(
  repo_id: "squad",
  filename: "train-v1.1.json",
  repo_type: :dataset
)

# Discover configs and splits
{:ok, configs} = HfHub.Api.dataset_configs("dpdl-benchmark/caltech101")
{:ok, splits} = HfHub.Api.dataset_splits("dpdl-benchmark/caltech101", config: "default")

# Resolve file paths for a config + split
{:ok, files} =
  HfHub.DatasetFiles.resolve("dpdl-benchmark/caltech101", "default", "train")
```

### Bumblebee-Compatible API

Use the tuple-based repository API for seamless integration with Elixir ML pipelines:

```elixir
# Repository reference types
repo = {:hf, "bert-base-uncased"}
repo_with_opts = {:hf, "bert-base-uncased", revision: "v1.0", auth_token: "hf_xxx"}
local_repo = {:local, "/path/to/model"}

# List files with ETags for cache validation
{:ok, files} = HfHub.get_repo_files({:hf, "bert-base-uncased"})
# => %{"config.json" => "\"abc123\"", "pytorch_model.bin" => "\"def456\"", ...}

# ETag-based cached download
{:ok, path} = HfHub.cached_download(
  "https://huggingface.co/bert-base-uncased/resolve/main/config.json"
)

# Build file URLs
url = HfHub.file_url("bert-base-uncased", "config.json", "main")
```

### Cache Management

```elixir
# Check if a file is cached
cached? = HfHub.Cache.cached?(
  repo_id: "bert-base-uncased",
  filename: "pytorch_model.bin"
)

# Clear cache for a specific repo
:ok = HfHub.Cache.clear_cache(repo_id: "bert-base-uncased")

# Get cache statistics
{:ok, stats} = HfHub.Cache.cache_stats()
IO.inspect(stats.total_size)  # Total bytes in cache
IO.inspect(stats.file_count)  # Number of cached files
```

## Examples

The `examples/` directory contains runnable scripts demonstrating common use cases:

```bash
# Run all examples at once
./examples/run_all.sh

# Or run individual examples:
mix run examples/list_datasets.exs      # List top datasets
mix run examples/list_models.exs        # List popular models
mix run examples/dataset_info.exs       # Get dataset metadata
mix run examples/list_repo_tree.exs     # List repo tree entries
mix run examples/dataset_configs_splits.exs  # Dataset configs + splits
mix run examples/dataset_files_resolver.exs  # Resolve dataset files by config + split
mix run examples/download_file.exs      # Download a single file
mix run examples/download_with_extract.exs   # Download + extract archives
mix run examples/cache_demo.exs         # Cache management demo
mix run examples/stream_download.exs    # Stream large files
mix run examples/snapshot_download.exs  # Download entire repo
mix run examples/auth_demo.exs          # Authentication flow
```

See the [examples README](examples/README.md) for detailed documentation.

## API Overview

### HfHub.Api

Interact with the HuggingFace Hub API:

- `model_info/2` — Fetch model metadata
- `dataset_info/2` — Fetch dataset metadata
- `space_info/2` — Fetch space metadata
- `list_models/1` — List models with filters
- `list_datasets/1` — List datasets with filters
- `list_repo_tree/2` — List repo tree entries (files + folders)
- `list_files/2` — List files in a repository
- `dataset_configs/2` — Get dataset configuration/subset names
- `dataset_splits/2` — Get dataset split names for a config

### HfHub.Download

Download files from HuggingFace repositories:

- `hf_hub_download/1` — Download a single file (with caching, optional extraction)
- `snapshot_download/1` — Download entire repository snapshot
- `download_stream/1` — Stream download for large files
- `resume_download/1` — Resume interrupted downloads

### HfHub.DatasetFiles

Resolve dataset files by config and split:

- `resolve/4` — Resolve file paths by config + split
- `resolve_from_tree/3` — Resolve file paths from a repo tree

### HfHub.Cache

Manage local file cache:

- `cached?/1` — Check if file exists in cache
- `cache_path/1` — Get local path for cached file
- `clear_cache/1` — Remove cached files
- `cache_stats/0` — Get cache usage statistics
- `evict_lru/1` — Evict least recently used files
- `validate_integrity/0` — Validate checksums of cached files

### HfHub.FS

Filesystem utilities for HuggingFace cache:

- `ensure_cache_dir/0` — Create cache directory structure
- `repo_path/2` — Get local path for repository
- `file_path/4` — Get local path for file in repository
- `lock_file/2` — Acquire file lock for concurrent downloads
- `unlock_file/1` — Release a file lock
- `cache_dir/0` — Get configured cache directory

### HfHub.Config

Configuration utilities:

- `endpoint/0` — Get HuggingFace Hub endpoint URL
- `cache_dir/0` — Get cache directory path
- `http_opts/0` — Get HTTP client options
- `cache_opts/0` — Get cache options

### HfHub.Auth

Authentication and authorization:

- `get_token/0` — Retrieve HuggingFace token
- `set_token/1` — Set authentication token
- `login/1` — Interactive login flow
- `logout/0` — Remove stored credentials
- `whoami/0` — Get current user information
- `validate_token/1` — Validate token format
- `auth_headers/1` — Build HTTP authorization headers

### HfHub.Hub

Bumblebee-compatible ETag-based caching:

- `cached_download/2` — Download with ETag-based cache validation
- `file_url/3` — Build file URL for repository
- `file_listing_url/3` — Build tree listing URL

### HfHub.Repository

Repository reference types and helpers:

- `normalize!/1` — Normalize repository tuples
- `file_url/2` — Build file URL from repository reference
- `file_listing_url/1` — Build listing URL from repository reference
- `cache_scope/1` — Convert repo ID to cache scope string

### HfHub.RepoFiles

Repository file listing with ETags:

- `get_repo_files/1` — Get map of files to ETags for cache validation

### HfHub.Constants

Constants matching Python's `huggingface_hub.constants`:

- File names: `config_name/0`, `pytorch_weights_name/0`, `safetensors_single_file/0`
- Timeouts: `default_etag_timeout/0`, `default_download_timeout/0`
- Repository types: `repo_types/0`, `repo_type_url_prefix/1`

### HfHub.Errors

Structured exceptions for error handling:

- Repository: `RepositoryNotFound`, `RevisionNotFound`, `EntryNotFound`, `GatedRepo`
- HTTP: `HTTPError`, `BadRequest`, `OfflineMode`
- Cache: `CacheNotFound`, `CorruptedCache`, `LocalEntryNotFound`
- Inference: `InferenceTimeout`, `InferenceEndpointError`
- Storage: `XetError`, `DDUFError`, `SafetensorsParsing`

### HfHub.LFS

LFS (Large File Storage) utilities:

- `UploadInfo.from_path/1` — Create upload info from file
- `UploadInfo.from_binary/1` — Create upload info from binary
- `sha256_hex/1` — Get hex-encoded SHA256 hash
- `oid/1` — Get LFS object identifier
- `lfs_headers/0` — Get standard LFS headers

## Configuration

Configure `hf_hub` in your `config/config.exs`:

```elixir
config :hf_hub,
  # Authentication token (defaults to HF_TOKEN env var)
  token: System.get_env("HF_TOKEN"),

  # Cache directory (defaults to ~/.cache/huggingface)
  cache_dir: Path.expand("~/.cache/huggingface"),

  # Hub endpoint (defaults to https://huggingface.co)
  endpoint: "https://huggingface.co",

  # HTTP client options
  http_opts: [
    receive_timeout: 30_000,
    pool_timeout: 5_000
  ],

  # Cache options
  cache_opts: [
    max_size: 10 * 1024 * 1024 * 1024,  # 10 GB
    eviction_policy: :lru
  ]
```

## Comparison to Python's `huggingface_hub`

`hf_hub_ex` aims for feature parity with the Python library while embracing Elixir idioms:

| Feature | Python `huggingface_hub` | Elixir `hf_hub_ex` |
|---------|--------------------------|---------------------|
| API Client | ✅ | ✅ |
| File Downloads | ✅ | ✅ |
| Caching | ✅ | ✅ (OTP-based) |
| Authentication | ✅ | ✅ |
| Repository Management | ✅ | 🚧 (Planned) |
| Upload Files | ✅ | 🚧 (Planned) |
| Inference API | ✅ | 🚧 (Planned) |

### Key Differences

- **Concurrency** — Leverages OTP for parallel downloads and supervision
- **Caching** — GenServer-based cache with configurable eviction policies
- **Error Handling** — Pattern matching with `{:ok, result}` / `{:error, reason}` tuples
- **Type Safety** — Comprehensive typespecs and Dialyzer integration

## Roadmap

- [x] Core API client (models, datasets, spaces)
- [x] File download with caching
- [x] Authentication support
- [ ] Repository management (create, delete, update)
- [ ] File uploads
- [ ] Inference API client
- [ ] WebSocket support for real-time inference
- [ ] Integration with `crucible_datasets` for dataset loading

See [docs/ROADMAP.md](docs/ROADMAP.md) for detailed feature parity status with Python `huggingface_hub`.

## Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-new-feature`)
3. Write tests for your changes
4. Ensure all tests pass (`mix test`)
5. Run code quality checks (`mix format && mix credo && mix dialyzer`)
6. Commit your changes (`git commit -am 'Add new feature'`)
7. Push to the branch (`git push origin feature/my-new-feature`)
8. Create a Pull Request

## Testing

```bash
# Run all tests
mix test

# Run with coverage
mix test --cover

# Run specific test file
mix test test/hf_hub/api_test.exs
```

## License

MIT License - See [LICENSE](LICENSE) for details.

## Acknowledgments

- Inspired by [huggingface_hub](https://github.com/huggingface/huggingface_hub) (Python)
- Part of the [North-Shore-AI](https://github.com/North-Shore-AI) research ecosystem
- Built with [Req](https://github.com/wojtekmach/req) for HTTP client functionality

## Links

- **Hex Package**: https://hex.pm/packages/hf_hub
- **Documentation**: https://hexdocs.pm/hf_hub
- **GitHub**: https://github.com/North-Shore-AI/hf_hub_ex
- **Issues**: https://github.com/North-Shore-AI/hf_hub_ex/issues
- **HuggingFace Hub**: https://huggingface.co

---

Built with ❤️ by the North-Shore-AI team
