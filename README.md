# HfHub

![HfHub Logo](assets/hf_hub_ex.svg)

[![Hex.pm](https://img.shields.io/hexpm/v/hf_hub.svg)](https://hex.pm/packages/hf_hub)
[![Documentation](https://img.shields.io/badge/docs-hexdocs-blue.svg)](https://hexdocs.pm/hf_hub)
[![CI](https://img.shields.io/github/actions/workflow/status/North-Shore-AI/hf_hub_ex/ci.yml?branch=main)](https://github.com/North-Shore-AI/hf_hub_ex/actions)
[![License](https://img.shields.io/hexpm/l/hf_hub.svg)](https://github.com/North-Shore-AI/hf_hub_ex/blob/main/LICENSE)

**Elixir client for [HuggingFace Hub](https://huggingface.co)** — dataset/model metadata, file downloads, caching, and authentication. An Elixir port of Python's [`huggingface_hub`](https://github.com/huggingface/huggingface_hub).

`hf_hub_ex` provides a robust, production-ready interface to the HuggingFace Hub API, enabling Elixir applications to seamlessly access models, datasets, and spaces. This library is designed to be the foundational layer for porting Python HuggingFace libraries (datasets, evaluate, transformers) to the BEAM ecosystem.

## Features

- **Hub API Client** — Fetch metadata for models, datasets, and spaces
- **File Downloads** — Stream files from HuggingFace repositories with resume support
- **Smart Caching** — Local file caching with LRU eviction and integrity checks
- **Filesystem Utilities** — Manage local HuggingFace cache directory structure
- **Authentication** — Token-based authentication for private repositories
- **BEAM-native** — Leverages OTP, GenServers, and supervision trees for reliability
- **Type-safe** — Comprehensive typespecs and pattern matching

## Installation

Add `hf_hub` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:hf_hub, "~> 0.1.0"}
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
mix run examples/download_file.exs      # Download a single file
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
- `list_files/2` — List files in a repository
- `dataset_configs/2` — Get dataset configuration/subset names

### HfHub.Download

Download files from HuggingFace repositories:

- `hf_hub_download/1` — Download a single file (with caching)
- `snapshot_download/1` — Download entire repository snapshot
- `download_stream/1` — Stream download for large files
- `resume_download/1` — Resume interrupted downloads

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
