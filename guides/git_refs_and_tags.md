# Git refs, branches, tags, and releases

`HfHub.Git` covers the Hub's branch/tag/ref endpoints. Route and payload shapes
are aligned with Python `huggingface_hub.HfApi` for this surface.

## Repository IDs and URL encoding

For API paths, repository IDs preserve the literal owner/name separator:

```text
/api/datasets/my-org/my-dataset/refs
```

Branch, tag, revision, and file path segments are encoded individually. For
example, branch `feature/upload #1` becomes `feature%2Fupload%20%231`.

## Create a tag after uploading an artifact bundle

```elixir
{:ok, tag} =
  HfHub.Git.create_tag(
    "my-org/my-dataset",
    "v1.0.0",
    repo_type: :dataset,
    message: "Initial public release",
    token: token
  )
```

Wire shape:

```text
POST /api/datasets/my-org/my-dataset/tag/main
{"tag":"v1.0.0","message":"Initial public release"}
```

To tag a specific commit or branch:

```elixir
{:ok, tag} =
  HfHub.Git.create_tag(
    "my-org/my-dataset",
    "v1.0.1",
    repo_type: :dataset,
    revision: "7892223bef7a285d5326f3c1485ec68b226846d7",
    message: "Patch release",
    token: token
  )
```

## Branches

```elixir
{:ok, branch} = HfHub.Git.create_branch("my-org/my-model", "evals", token: token)

{:ok, branch} =
  HfHub.Git.create_branch(
    "my-org/my-model",
    "hotfix",
    revision: "v1.0.0",
    token: token
  )
```

When `revision:` is omitted, the server defaults to `main`; the request payload
is empty, matching Python `huggingface_hub`.

## Listing refs

```elixir
{:ok, refs} = HfHub.Git.list_refs("my-org/my-dataset", repo_type: :dataset)

{:ok, refs_with_prs} =
  HfHub.Git.list_refs("my-org/my-dataset",
    repo_type: :dataset,
    include_pull_requests: true
  )
```

When PR refs are requested, `hf_hub_ex` sends `include_prs=1`, matching the
Python client.
