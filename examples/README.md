# HfHub Examples

This directory contains runnable examples demonstrating the HfHub library capabilities.

## Prerequisites

```bash
# Install dependencies
mix deps.get

# Compile the project
mix compile
```

For authenticated examples, set your HuggingFace token:

```bash
export HF_TOKEN="hf_your_token_here"
```

## Running Examples

### Run All Examples

```bash
./examples/run_all.sh

# Or with authentication:
HF_TOKEN=hf_xxx ./examples/run_all.sh
```

### Run Individual Examples

```bash
mix run examples/<example_name>.exs
```

## Available Examples

| Example | Description |
|---------|-------------|
| `list_datasets.exs` | List top datasets from HuggingFace Hub sorted by downloads |
| `list_models.exs` | List popular models with filtering options |
| `dataset_info.exs` | Fetch detailed metadata for a specific dataset |
| `download_file.exs` | Download a single file from a repository |
| `cache_demo.exs` | Demonstrate cache management and statistics |
| `stream_download.exs` | Stream large files with progress tracking |
| `snapshot_download.exs` | Download entire repository with pattern filtering |
| `auth_demo.exs` | Authentication flow, token validation, and user info |

## Example Details

### list_datasets.exs

Lists the top 5 most downloaded datasets from HuggingFace Hub.

```bash
mix run examples/list_datasets.exs
```

### list_models.exs

Lists popular models with download counts and tags.

```bash
mix run examples/list_models.exs
```

### dataset_info.exs

Fetches and displays detailed metadata for a specific dataset.

```bash
mix run examples/dataset_info.exs
```

### download_file.exs

Downloads a single file (e.g., `config.json`) from a model repository.

```bash
mix run examples/download_file.exs
```

### cache_demo.exs

Demonstrates cache operations including checking cache status, getting statistics, and cache management.

```bash
mix run examples/cache_demo.exs
```

### stream_download.exs

Shows how to stream large files with progress callbacks and resume support.

```bash
mix run examples/stream_download.exs
```

### snapshot_download.exs

Downloads an entire repository snapshot with pattern-based filtering to ignore large binary files.

```bash
mix run examples/snapshot_download.exs
```

### auth_demo.exs

Demonstrates the authentication flow including token validation, login, user info retrieval, and logout.

```bash
HF_TOKEN=hf_xxx mix run examples/auth_demo.exs
```
