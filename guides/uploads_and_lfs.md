# Uploads and LFS

`HfHub.Commit` provides Python-`huggingface_hub`-style upload primitives for
creating commits without requiring local `git` or `git-lfs` binaries.

## Single file

```elixir
{:ok, info} =
  HfHub.Commit.upload_file(
    "/path/to/model.safetensors",
    "model.safetensors",
    "my-org/my-model",
    token: token,
    commit_message: "Add model weights"
  )
```

Files under 10 MiB are inlined in the commit payload as base64. Files at or
above 10 MiB use the Hub's Git LFS batch API automatically.

## Folder upload

```elixir
{:ok, info} =
  HfHub.Commit.upload_folder(
    "/path/to/exported_bundle",
    "my-org/my-dataset",
    repo_type: :dataset,
    token: token,
    commit_message: "v1.0.0: initial artifact bundle",
    ignore_patterns: ["*.log.jsonl", "*.tmp", ".DS_Store"]
  )
```

The folder structure is preserved. `allow_patterns`, `ignore_patterns`, and
`delete_patterns` use gitignore-style matching.

## Large safetensors / model artifacts

For hundreds-of-megabytes safetensors files, use a conservative concurrency and
long LFS timeouts. This mirrors the operational shape used to publish the
Trinity Coordinator adapted Qwen3 router bundle.

```elixir
{:ok, info} =
  HfHub.Commit.upload_folder(
    "priv/sakana_trinity/adapted_qwen3_0_6b_layer26",
    "nshkrdotcom/trinity-coordinator-adapted-qwen3-0.6b",
    repo_type: :dataset,
    token: token,
    commit_message: "v1.0.0: initial adapted-artifact bundle",
    ignore_patterns: ["*.log.jsonl", "*.tmp", ".DS_Store"],
    max_workers: 1,
    lfs_upload_timeout: 60 * 60 * 1000,
    lfs_task_timeout: 65 * 60 * 1000
  )
```

Recommended defaults for large one-time artifact publishing:

| Option | Recommended value | Why |
|---|---:|---|
| `max_workers` | `1` | Avoids concurrent multipart uploads contending for memory/network on large files. |
| `lfs_upload_timeout` | `60 * 60 * 1000` | Allows a single large part/upload/complete request to run for up to 60 minutes. |
| `lfs_task_timeout` | `65 * 60 * 1000` | Gives the worker process a small margin beyond the HTTP receive timeout. |

## LFS protocol alignment

The multipart implementation intentionally follows Python
`huggingface_hub/src/huggingface_hub/lfs.py`:

- `upload.header["chunk_size"]` selects multipart upload;
- digit-only header keys (`"1"`, `"00001"`, ...) are sorted numerically as part
  URLs;
- every part is uploaded with `PUT`;
- completion is a `POST` to the Hub completion endpoint with
  `%{"oid" => oid, "parts" => [%{"partNumber" => n, "etag" => etag}]}`;
- completion uses `application/vnd.git-lfs+json` LFS headers.

This guards against the common failure mode where a multipart completion URL is
mistakenly used as a single-part `PUT` target.
