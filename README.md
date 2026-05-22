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

- Hub metadata APIs for models, datasets, and Spaces
- Downloads, snapshots, local cache helpers, and offline mode
- Repository management: create, delete, move, settings, existence checks
- Commit API: upload files/folders, regular payloads, Git LFS, multipart LFS
- Git refs: branches, tags, commits, and super-squash
- Bumblebee-style repository helpers for Elixir ML workflows
- Structured `{:ok, result}` / `{:error, reason}` return values

## Installation

```elixir
def deps do
  [
    {:hf_hub, "~> 0.3.0"}
  ]
end
```

Then run:

```bash
mix deps.get
```

## Guides

Start here for production-oriented usage:

- [Authentication and runtime configuration](guides/auth_and_runtime_config.md)
- [Uploads and LFS](guides/uploads_and_lfs.md)
- [Git refs, branches, tags, and releases](guides/git_refs_and_tags.md)
- [Roadmap / Python parity notes](docs/ROADMAP.md)

## Quick start

### Runtime configuration

Host applications should read OS environment variables at their boundary (for
example, `config/runtime.exs`) and pass values into `:hf_hub` config:

```elixir
import Config

if token = System.get_env("HF_TOKEN") do
  config :hf_hub, token: token
end

if cache_dir = System.get_env("HF_HUB_CACHE") || System.get_env("HF_HOME") do
  config :hf_hub, cache_dir: cache_dir
end

if System.get_env("HF_HUB_OFFLINE") in ["1", "true", "TRUE", "yes", "YES"] do
  config :hf_hub, offline: true
end
```

Library calls also accept explicit `token:` options:

```elixir
token = System.fetch_env!("HF_TOKEN")
```

### Create a dataset repo

```elixir
{:ok, repo} =
  HfHub.Repo.create(
    "my-org/my-artifact-bundle",
    repo_type: :dataset,
    private: false,
    token: token
  )
```

### Upload a folder with LFS support

```elixir
{:ok, info} =
  HfHub.Commit.upload_folder(
    "/path/to/exported_bundle",
    "my-org/my-artifact-bundle",
    repo_type: :dataset,
    token: token,
    commit_message: "v1.0.0: initial artifact bundle",
    ignore_patterns: ["*.log.jsonl", "*.tmp", ".DS_Store"]
  )
```

For large safetensors/model bundles, prefer conservative LFS settings:

```elixir
{:ok, info} =
  HfHub.Commit.upload_folder(
    "/path/to/exported_bundle",
    "my-org/my-artifact-bundle",
    repo_type: :dataset,
    token: token,
    commit_message: "v1.0.0: initial artifact bundle",
    ignore_patterns: ["*.log.jsonl", "*.tmp", ".DS_Store"],
    max_workers: 1,
    lfs_upload_timeout: 60 * 60 * 1000,
    lfs_task_timeout: 65 * 60 * 1000
  )
```

See [Uploads and LFS](guides/uploads_and_lfs.md) for the multipart protocol
notes and operational rationale.

### Tag a release

```elixir
{:ok, tag} =
  HfHub.Git.create_tag(
    "my-org/my-artifact-bundle",
    "v1.0.0",
    repo_type: :dataset,
    message: "Initial public release",
    token: token
  )
```

This uses the Python-client-compatible endpoint shape:

```text
POST /api/datasets/my-org/my-artifact-bundle/tag/main
{"tag":"v1.0.0","message":"Initial public release"}
```

### Download a file

```elixir
{:ok, path} =
  HfHub.Download.hf_hub_download(
    repo_id: "bert-base-uncased",
    filename: "config.json",
    repo_type: :model
  )

config = File.read!(path)
```

### Offline/cache helpers

```elixir
if HfHub.offline_mode?() do
  IO.puts("Only cached files will be used")
end

case HfHub.try_to_load_from_cache("bert-base-uncased", "config.json") do
  {:ok, path} -> File.read!(path)
  {:error, :not_cached} -> :download_or_fail
end
```

## API overview

### `HfHub.Repo`

Repository lifecycle helpers:

- `create/2`
- `delete/2`
- `update_settings/2`
- `move/3`
- `exists?/2`
- `file_exists?/3`
- `revision_exists?/3`

### `HfHub.Commit`

Commit and upload helpers:

- `create/3`
- `upload_file/4`
- `upload_folder/3`
- `upload_large_folder/3`
- `delete_file/3`
- `delete_folder/3`
- `matches_pattern?/2`
- `needs_lfs?/1`
- `lfs_threshold/0`

### `HfHub.Git`

Git refs and release helpers:

- `create_branch/3`
- `delete_branch/3`
- `create_tag/3`
- `delete_tag/3`
- `list_refs/2`
- `list_commits/2`
- `super_squash/2`

### `HfHub.Download`

Download and snapshot helpers:

- `hf_hub_download/1`
- `snapshot_download/1`
- `download_stream/1`
- `resume_download/1`

### `HfHub.Api`

Hub metadata APIs:

- `model_info/2`
- `dataset_info/2`
- `space_info/2`
- `list_models/1`
- `list_datasets/1`
- `list_repo_tree/2`
- `list_files/2`
- `dataset_configs/2`
- `dataset_splits/2`

### Other modules

- `HfHub.Auth` — application-config-backed auth helpers
- `HfHub.Config` — endpoint/cache/http configuration helpers
- `HfHub.Cache` and `HfHub.FS` — local cache/filesystem helpers
- `HfHub.Hub`, `HfHub.Repository`, and `HfHub.RepoFiles` — Bumblebee-style helpers
- `HfHub.Cards` — model/dataset card parsing and rendering
- `HfHub.LFS` — LFS upload-info and hashing utilities

## Python-client alignment

`hf_hub_ex` intentionally follows Python `huggingface_hub` route and payload
shapes for the artifact-publishing surface:

- repository IDs preserve the literal owner/name `/` separator in API paths;
- branch, tag, revision, and file path segments are URL-encoded individually;
- multipart LFS uses `chunk_size`, digit-only part URL keys, ETag collection,
  and completion `POST` payload `%{"oid" => oid, "parts" => ...}`;
- `create_tag/3` posts to `/tag/{revision}` with payload `%{"tag" => tag}`;
- `list_refs/2` uses `include_prs=1` for pull-request refs.

## Examples

The `examples/` directory contains runnable scripts:

```bash
./examples/run_all.sh
mix run examples/list_datasets.exs
mix run examples/list_models.exs
mix run examples/download_file.exs
mix run examples/snapshot_download.exs
mix run examples/auth_demo.exs
```

See [examples/README.md](examples/README.md) for details.

## Testing

```bash
mix format --check-formatted
mix compile --warnings-as-errors
mix test
mix credo --strict
mix dialyzer
mix docs --warnings-as-errors
```

## Roadmap

- [x] Core API client (models, datasets, spaces)
- [x] File download with caching
- [x] Authentication support
- [x] Repository management
- [x] File uploads and Git LFS support
- [x] Folder uploads with pattern filtering and batching
- [x] Git refs/tags for artifact release workflows
- [ ] Full endpoint-by-endpoint parity audit for every Python `huggingface_hub` surface
- [ ] Inference API client
- [ ] Integration with `crucible_datasets` for dataset loading

## Contributing

1. Fork the repository
2. Create a feature branch
3. Write tests for your changes
4. Run the quality gates above
5. Open a pull request

## License

MIT License - See [LICENSE](LICENSE) for details.

## Acknowledgments

- Inspired by [huggingface_hub](https://github.com/huggingface/huggingface_hub) (Python)
- Part of the [North-Shore-AI](https://github.com/North-Shore-AI) research ecosystem
- Built with [Req](https://github.com/wojtekmach/req)

## Links

- **Hex Package**: https://hex.pm/packages/hf_hub
- **Documentation**: https://hexdocs.pm/hf_hub
- **GitHub**: https://github.com/North-Shore-AI/hf_hub_ex
- **Issues**: https://github.com/North-Shore-AI/hf_hub_ex/issues
- **HuggingFace Hub**: https://huggingface.co

---

Built with ❤️ by the North-Shore-AI team
