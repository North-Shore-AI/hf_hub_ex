# Immutable revisions and reproducible model artifacts

Branches and tags such as `main` or `v1.0` are convenient names, but they are
not immutable artifact identities. A branch can advance and a tag can be moved.
For reproducible model loading, resolve the requested revision once and use the
resulting full commit hash for every file in the artifact set.

## Resolve once, then download by commit

```elixir
{:ok, revision} =
  HfHub.resolve_revision(
    "org/model",
    revision: "main",
    repo_type: :model,
    token: token
  )

revision.requested
# => "main"

revision.resolved
# => "0123456789abcdef0123456789abcdef01234567"

{:ok, config_path} =
  HfHub.Download.hf_hub_download(
    repo_id: "org/model",
    filename: "config.json",
    revision: revision.resolved,
    token: token
  )

{:ok, weights_path} =
  HfHub.Download.hf_hub_download(
    repo_id: "org/model",
    filename: "model.safetensors",
    revision: revision.resolved,
    token: token,
    expected_sha256: expected_weights_sha256
  )
```

This separates two identities:

- `requested` records what the caller asked for (`main`, a tag, or a commit).
- `resolved` is the immutable 40-character commit hash used for the artifact.

If the input is already a full commit hash, resolution does not make a network
request.

## Snapshot downloads

`HfHub.Download.snapshot_download/1` resolves mutable revisions automatically.
Files are listed and downloaded using the resolved commit, and the returned
snapshot directory is keyed by that commit hash:

```elixir
{:ok, snapshot_path} =
  HfHub.Download.snapshot_download(
    repo_id: "org/model",
    revision: "main",
    allow_patterns: ["*.json", "*.safetensors"]
  )

# .../models--org--model/snapshots/<40-character-commit>
```

The mutable ref-to-commit mapping is recorded under the repository cache's
`refs/` directory.

## Offline resolution

A mutable revision can be resolved without network access after its ref mapping
has been cached:

```elixir
config :hf_hub, offline: true

{:ok, revision} = HfHub.resolve_revision("org/model", revision: "main")
```

You can request cache-only resolution explicitly as well:

```elixir
HfHub.resolve_revision("org/model",
  revision: "main",
  local_files_only: true
)
```

If no cached mapping exists, the result is
`{:error, {:revision_not_cached, revision}}`.

## Integrity and identity are separate

The commit hash identifies the repository state. For high-assurance artifact
loading, also verify the expected SHA-256 of critical files with
`expected_sha256:`. This protects the local bytes while the commit hash pins the
remote repository state.
