# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2026-05-21

### Fixed
- **Atomic downloads and cache hardening** — `HfHub.HTTP.download_file/3`
  now streams into `<destination>.incomplete` and renames into place only after
  a successful `200`/`206`, so failed `404`/`401`/network responses no longer
  leave 0-byte cache poison or clobber an existing cached file.
  `HfHub.Download.hf_hub_download/1` now treats pre-existing 0-byte cache
  entries as corrupt and redownloads them, and failed downloads release cache
  locks on every exit path.
- **Resume streaming wire shape** — `HfHub.HTTP.download_file/3` with
  `resume: true` now correctly persists the response body for both
  `206 Partial Content` (server honors `Range`) and `200 OK` (server ignores
  `Range` and restarts from scratch). Previously, Req's `Collectable` `into:`
  contract silently skipped streaming for non-200 bodies, so a 206 returned
  `:ok` with zero bytes appended; combined with the new atomic-rename, that
  promoted to silent cache corruption. The streaming primitive is now a
  function-form `into:` lambda that receives chunks for every status code, and
  truncates the prior partial bytes on the first chunk when the server
  responds 200 to a Range request.
- **Preupload preflight** — `HfHub.Commit.create/3` now POSTs each commit's
  add-operations to `/api/{type}s/{repo_id}/preupload/{revision}` to ask the
  Hub which files should ride LFS vs. regular base64. The previous local 10 MB
  size threshold caused small `.safetensors`/`.bin`/etc. files to be sent as
  base64 even when the destination repo's `.gitattributes` tracked their
  extension as LFS, producing
  `400 "Your push was rejected because it contains binary files"`. This is
  identical in shape to `_fetch_upload_modes` in
  `huggingface_hub/_commit_api.py`. Callers can opt out with
  `preupload: false` to keep the legacy size-threshold-only fallback (used
  primarily by offline tests).
- **Commit payload wire shape** — `HfHub.Commit.create/3` (and therefore
  `upload_file/4`, `upload_folder/3`, `upload_large_folder/3`, `delete_file/3`,
  `delete_folder/3`) now sends the canonical
  `Content-Type: application/x-ndjson` body with one header line followed by
  one operation per line, matching `_prepare_commit_payload` in
  `huggingface_hub/_commit_api.py`. Each operation envelope is now
  `{"key": "file" | "lfsFile" | "deletedFile" | "deletedFolder" | "copy",
  "value": {"path": <path_in_repo>, ...}}`. The previous JSON-envelope shape
  silently caused the Hub to accept the request and return a `commitOid`
  while **discarding every operation**, producing an "empty" commit that left
  only `.gitattributes` in the repository.
- `create_pr` is now passed as a `create_pr=1` query parameter rather than as
  a body field, matching the Python client.
- Align Git branch/tag/ref routes with Python `huggingface_hub` for namespaced repos:
  - preserve literal `/` in `repo_id` path components;
  - encode branch/tag/revision segments independently;
  - `create_tag/3` now posts to `/tag/{revision}` with `%{"tag" => tag}`;
  - `list_refs/2` now uses `include_prs=1` for PR refs;
  - `super_squash/2` now posts to `/super-squash/{branch}` with a message body.
- Align repository-management routes used by the artifact-publishing flow:
  - `update_settings/2` and `revision_exists?/3` preserve literal repo slashes;
  - `delete/2` now uses Python-compatible `DELETE /api/repos/delete` with JSON body;
  - `file_exists?/3` now encodes `repo_id` (literal slash), `revision`
    (`quote(safe="")` shape), and `filename` (`quote()` shape, preserving
    subpath separators), matching `huggingface_hub.file_download.hf_hub_url`.
- Eliminate URL-encoded repo slashes across every remaining surface that calls
  into the HuggingFace API. The first pass fixed `Git`, `Commit`, and `Repo`;
  this pass covers `Users`, `Spaces` (including `duplicate/2`), `Discussions`,
  `AccessRequests`, `Collections`, and `Organizations`. Every module-private
  `defp encode(repo_id)` helper is now routed through the internal "HfHub.Path" repo-id encoder
  so namespaced ids never reach the Hub as `org%2Frepo`.
- **LFS multipart upload protocol** (the `Cannot PUT /api/complete_multipart` bug):
  - Multipart detection now reads the `chunk_size` header (case-insensitive)
    instead of the wrong `x-amz-meta-chunk-size` key. Previously, files that
    HF wanted uploaded in parts fell through to single-part `PUT` against
    the completion endpoint and returned 404.
  - Part URL parsing now uses digit-only string keys (`"1"`, `"00001"`, ...)
    instead of the wrong `x-amz-meta-part-N-url` pattern.
  - Completion payload now includes the required top-level `"oid"` field
    alongside `"parts"`, matching `huggingface_hub/lfs.py` exactly.
  - Completion request now sends the LFS `Accept: application/vnd.git-lfs+json`
    and `Content-Type: application/vnd.git-lfs+json` headers.
  - Malformed `chunk_size` server responses now surface as
    `{:error, {:malformed_response, message}}` instead of crashing the
    caller process via a linked task EXIT.
  - Part-count mismatches surface as
    `{:error, {:multipart_upload_failed, {:part_count_mismatch, ...}}}`.
- The internal LFS header reader in `HfHub.Commit.LfsUpload` now correctly reads ETags from the
  `Req` >= 0.4 response-headers map (was always returning `nil`, which made
  multipart completion latently impossible even before the protocol fix).
- Prevent URL-encoded slashes in repository IDs

### Internal
- Test fixtures across `commit_test.exs`, `commit/folder_upload_test.exs`,
  `commit/lfs_upload_test.exs`, `users_test.exs`, `spaces_test.exs`,
  `discussions_test.exs`, `access_requests_test.exs`, `collections_test.exs`,
  and `repo_test.exs` now expect literal `/` between org and repo name,
  matching the corrected URL encoding shipped in `0.2.1` and extended in
  `0.3.0`.
- Add `HTTP.delete/3` contract test pinning that JSON bodies reach the wire,
  preventing future regressions on Python-compatible `DELETE /api/repos/delete`.
- Add `Repo.file_exists?/3` contract tests for revision encoding and dataset
  prefix handling.

### Added
- Add an internal path helper with regression tests for repo-id and path-segment encoding.
- Add user-facing guides for runtime auth config, uploads/LFS, and Git refs/tags; package them in Hex/HexDocs.
- Add configurable timeouts for LFS uploads

### Changed
- Refresh all resolvable Hex dependencies to current latest versions; `decimal` and `ranch` remain constrained by upstream dependency requirements.
- Rewrite README around the artifact-publishing workflow while preserving badges and SVG logo.
- Decouple library from OS environment variables

## [0.2.0] - 2026-01-25

### Added
- `:progress_callback` option in `HfHub.Download.hf_hub_download/1` for download progress tracking.
  The callback receives `(bytes_downloaded, total_bytes)` during download.
- `:verify_checksum` option in `HfHub.Download.hf_hub_download/1` to compute SHA256 after download.
- `:expected_sha256` option in `HfHub.Download.hf_hub_download/1` for SHA256 verification.
  Returns `{:error, {:checksum_mismatch, expected, actual}}` if hashes don't match.
- `HfHub.Download.compute_sha256/1` to compute SHA256 hash of a file.
- `HfHub.offline_mode?/0` to check if offline mode is enabled via `HF_HUB_OFFLINE=1` env var
  or `Application.put_env(:hf_hub, :offline, true)`. (`is_offline_mode/0` available for Python compatibility)
- `HfHub.try_to_load_from_cache/3` for cache-only file loading without network requests.
  Returns `{:ok, path}` if file is cached, `{:error, :not_cached}` otherwise.

## [0.1.3] - 2025-12-31

### Added
- `HfHub.HTTP` write methods: `post/3`, `put/3`, `patch/3`, `delete/2`, `post_action/3`
- Unified error mapping for all HTTP requests
- `HfHub.Repo` module for repository management
  - `create/2` - Create new repositories (models, datasets, spaces)
  - `delete/2` - Delete repositories
  - `update_settings/2` - Update repository settings (visibility, gated)
  - `move/3` - Move/rename repositories
  - `exists?/2` - Check if repository exists
  - `file_exists?/3` - Check if file exists in repository
  - `revision_exists?/3` - Check if revision exists
- `HfHub.Repo.RepoUrl` struct for repository URL responses
- `HfHub.Commit.Operation` module with Add, Delete, Copy operation types
- `HfHub.Commit.CommitInfo` struct for commit responses
- `HfHub.Commit.create/3` - Create commits with multiple operations
- `HfHub.Commit.upload_file/4` - Upload single file (regular or LFS)
- `HfHub.Commit.delete_file/3` - Delete file from repository
- `HfHub.Commit.delete_folder/3` - Delete folder from repository
- `HfHub.Commit.LfsUpload` - Git LFS batch upload support
- `HfHub.Commit.upload_folder/3` - Upload entire directories
- `HfHub.Commit.upload_large_folder/3` - Upload large directories with batching
- `HfHub.Commit.matches_pattern?/2` - Gitignore-style pattern matching
- Pattern filtering support (allow_patterns, ignore_patterns, delete_patterns)
- Concurrent LFS uploads with configurable workers (`:max_workers` option)
- `HfHub.Git` module for git operations
  - `create_branch/3`, `delete_branch/3` - Branch management
  - `create_tag/3`, `delete_tag/3` - Tag management (lightweight and annotated)
  - `list_refs/2` - List all branches, tags, converts, and pull requests
  - `list_commits/2` - List commit history
  - `super_squash/2` - Squash all commits (destructive)
- `HfHub.Git.BranchInfo`, `HfHub.Git.TagInfo`, `HfHub.Git.GitRefs`, `HfHub.Git.CommitInfo` structs
- `HfHub.Discussions` module for community interactions
  - `list/2` - List discussions with status/author filters
  - `get/3` - Get discussion details with full event history
  - `create/3`, `create_pr/3` - Create discussions and pull requests
  - `comment/4`, `edit_comment/5`, `hide_comment/4` - Comment management
  - `close/3`, `reopen/3`, `change_status/4` - Status management
  - `merge_pr/3` - Merge pull requests
  - `rename/4` - Rename discussions
- `HfHub.Discussions.Discussion`, `HfHub.Discussions.DiscussionDetails` structs
- `HfHub.Discussions.Comment`, `HfHub.Discussions.StatusChange`, `HfHub.Discussions.TitleChange` event types
- `HfHub.Collections` module for organizing models, datasets, and spaces
  - `list/1` - List collections with owner/item/sort filters
  - `get/2` - Get collection details with items
  - `create/2` - Create new collections (public/private)
  - `update/2` - Update collection metadata (title, description, visibility, theme)
  - `delete/2` - Delete collections
  - `add_item/4` - Add models, datasets, spaces, or papers to collections
  - `update_item/3` - Update item notes and positions
  - `delete_item/3` - Remove items from collections
- `HfHub.Collections.Collection`, `HfHub.Collections.CollectionItem` structs
- `HfHub.Webhooks` module for event notifications
  - `list/1` - List all webhooks for authenticated user
  - `get/2` - Get webhook details by ID
  - `create/2` - Create new webhooks with watched repos and domains
  - `update/2` - Update webhook URL, watched repos, domains, or secret
  - `enable/2`, `disable/2` - Enable/disable webhooks
  - `delete/2` - Delete webhooks
- `HfHub.Webhooks.WebhookInfo`, `HfHub.Webhooks.WatchedItem` structs
- `HfHub.Spaces` module for Space management
  - `get_runtime/2` - Get Space runtime information
  - `get_variables/2` - Get Space variables
  - `add_secret/4`, `delete_secret/3` - Manage secrets
  - `add_variable/4`, `delete_variable/3` - Manage variables
  - `request_hardware/3` - Request hardware upgrade/downgrade
  - `set_sleep_time/3` - Set auto-sleep timeout
  - `request_storage/3`, `delete_storage/2` - Manage persistent storage
  - `pause/2`, `restart/2` - Lifecycle control
  - `duplicate/2` - Duplicate Space to new repository
- `HfHub.Spaces.SpaceRuntime`, `HfHub.Spaces.SpaceVariable` structs
- `HfHub.InferenceEndpoints` module for dedicated model hosting
  - `list/1` - List all inference endpoints
  - `get/2` - Get endpoint by name
  - `create/2` - Create new inference endpoint (CPU/GPU, AWS/Azure/GCP)
  - `update/2` - Update endpoint configuration (scaling, model, compute)
  - `delete/2` - Delete endpoint
  - `pause/2`, `resume/2` - Lifecycle control
  - `scale_to_zero/2` - Scale endpoint to zero replicas with auto-wake
- `HfHub.InferenceEndpoints.Endpoint` struct with full endpoint details
- `HfHub.InferenceEndpoints.ModelConfig`, `ComputeConfig`, `ScalingConfig`, `ProviderConfig` structs
- `HfHub.AccessRequests` module for gated repository access management
  - `list_pending/2`, `list_accepted/2`, `list_rejected/2` - List access requests by status
  - `accept/3`, `reject/3` - Handle pending access requests
  - `cancel/3` - Revoke access
  - `grant/3` - Grant access directly without prior request
- `HfHub.AccessRequests.AccessRequest` struct for access request data
- `HfHub.Users` module for user profile and activity API
  - `get/2` - Get user profile by username
  - `list_followers/2` - List users who follow a user
  - `list_following/2` - List users a user is following
  - `list_liked_repos/2` - List repositories liked by a user
  - `like/2`, `unlike/2` - Like/unlike repositories
  - `list_likers/2` - List users who liked a repository
- `HfHub.Users.User` struct for user profile data
- `HfHub.Organizations` module for organization profile API
  - `get/2` - Get organization profile by name
  - `list_members/2` - List organization members
- `HfHub.Users.Organization` struct for organization profile data
- `HfHub.Cards` module for Model and Dataset card parsing
  - `load_model_card/2`, `load_dataset_card/2` - Load cards from repositories
  - `parse_model_card/1`, `parse_dataset_card/1` - Parse cards from content
  - `create_model_card/1`, `create_dataset_card/1` - Create cards from data
  - `render/1` - Render cards to markdown with YAML frontmatter
- `HfHub.Cards.ModelCard`, `HfHub.Cards.DatasetCard` structs
- `HfHub.Cards.ModelCardData`, `HfHub.Cards.DatasetCardData` for card metadata
- `HfHub.Cards.EvalResult` for model evaluation results
- YAML frontmatter extraction and parsing via `yaml_elixir`

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

[0.2.0]: https://github.com/North-Shore-AI/hf_hub_ex/compare/v0.1.3...v0.2.0
[0.1.3]: https://github.com/North-Shore-AI/hf_hub_ex/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/North-Shore-AI/hf_hub_ex/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/North-Shore-AI/hf_hub_ex/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/North-Shore-AI/hf_hub_ex/releases/tag/v0.1.0
