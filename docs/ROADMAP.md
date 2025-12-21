# HfHub Roadmap

Feature parity roadmap with Python [huggingface_hub](https://github.com/huggingface/huggingface_hub).

## Current Status

### Implemented

| Category | Elixir Function | Python Equivalent | Status |
|----------|-----------------|-------------------|--------|
| **Auth** | `HfHub.Auth.whoami/0` | `whoami()` | Done |
| | `HfHub.Auth.login/1` | `login()` | Done |
| | `HfHub.Auth.logout/0` | `logout()` | Done |
| | `HfHub.Auth.get_token/0` | `get_token()` | Done |
| | `HfHub.Auth.set_token/1` | - | Done |
| | `HfHub.Auth.validate_token/1` | - | Done |
| | `HfHub.Auth.auth_headers/1` | `build_hf_headers()` | Done |
| **Models** | `HfHub.Api.list_models/1` | `list_models()` | Done |
| | `HfHub.Api.model_info/2` | `model_info()` | Done |
| **Datasets** | `HfHub.Api.list_datasets/1` | `list_datasets()` | Done |
| | `HfHub.Api.dataset_info/2` | `dataset_info()` | Done |
| **Spaces** | `HfHub.Api.space_info/2` | `space_info()` | Done |
| **Files** | `HfHub.Api.list_files/2` | `list_repo_files()` | Done |
| **Datasets** | `HfHub.Api.dataset_configs/2` | `get_dataset_config_names()` | Done |
| **Download** | `HfHub.Download.hf_hub_download/1` | `hf_hub_download()` | Done |
| | `HfHub.Download.snapshot_download/1` | `snapshot_download()` | Done |
| | `HfHub.Download.download_stream/1` | - | Done |
| | `HfHub.Download.resume_download/1` | - | Done |
| **Cache** | `HfHub.Cache.cached?/1` | `try_to_load_from_cache()` | Done |
| | `HfHub.Cache.cache_path/1` | - | Done |
| | `HfHub.Cache.clear_cache/1` | `scan_cache_dir()` + delete | Done |
| | `HfHub.Cache.cache_stats/0` | `scan_cache_dir()` | Done |
| | `HfHub.Cache.evict_lru/1` | `delete_revisions()` | Done |
| | `HfHub.Cache.validate_integrity/0` | - | Done |
| **FS** | `HfHub.FS.repo_path/2` | `repo_folder_name()` | Done |
| | `HfHub.FS.file_path/4` | - | Done |
| | `HfHub.FS.lock_file/2` | `FileLock` | Done |
| **Config** | `HfHub.Config.endpoint/0` | `ENDPOINT` | Done |
| | `HfHub.Config.cache_dir/0` | `HF_HUB_CACHE` | Done |

---

## Roadmap

### Priority: High

Essential for write operations and full Hub integration.

| Feature | Python Functions | Notes |
|---------|------------------|-------|
| **Repository Management** | | |
| Create repository | `create_repo()` | POST `/api/repos/create` |
| Delete repository | `delete_repo()` | DELETE `/api/repos/delete` |
| Update repo settings | `update_repo_settings()` | PUT `/api/repos/{type}/{id}/settings` |
| Move/rename repo | `move_repo()` | POST `/api/repos/move` |
| **File Uploads** | | |
| Upload single file | `upload_file()` | Multipart upload or LFS |
| Upload folder | `upload_folder()` | Batch upload with commit |
| Create commit | `create_commit()` | POST `/api/{type}/{id}/commit` |
| Preupload LFS | `preupload_lfs_files()` | LFS protocol implementation |
| Delete file | `delete_file()` | Via commit operation |
| Delete folder | `delete_folder()` | Via commit operation |

### Priority: Medium

Extended read operations and space management.

| Feature | Python Functions | Notes |
|---------|------------------|-------|
| **Repository Info** | | |
| Check repo exists | `repo_exists()` | HEAD request |
| Check revision exists | `revision_exists()` | HEAD request |
| Check file exists | `file_exists()` | HEAD request |
| List repo tree | `list_repo_tree()` | GET `/api/{type}/{id}/tree/{revision}` |
| List repo refs | `list_repo_refs()` | Branches and tags |
| List repo commits | `list_repo_commits()` | Commit history |
| Get paths info | `get_paths_info()` | File metadata |
| **Branching & Tagging** | | |
| Create branch | `create_branch()` | POST `/api/{type}/{id}/branch` |
| Delete branch | `delete_branch()` | DELETE `/api/{type}/{id}/branch` |
| Create tag | `create_tag()` | POST `/api/{type}/{id}/tag` |
| Delete tag | `delete_tag()` | DELETE `/api/{type}/{id}/tag` |
| **Spaces API** | | |
| List spaces | `list_spaces()` | GET `/api/spaces` |
| Get space runtime | `get_space_runtime()` | Runtime status |
| Pause space | `pause_space()` | POST `/api/spaces/{id}/pause` |
| Restart space | `restart_space()` | POST `/api/spaces/{id}/restart` |
| Duplicate space | `duplicate_space()` | POST `/api/spaces/{id}/duplicate` |
| Request hardware | `request_space_hardware()` | GPU allocation |
| Set sleep time | `set_space_sleep_time()` | Auto-sleep config |
| Space secrets | `add/delete_space_secret()` | Environment variables |
| Space variables | `add/delete_space_variable()` | Public config |

### Priority: Low

Social features, discussions, and advanced functionality.

| Feature | Python Functions | Notes |
|---------|------------------|-------|
| **Discussions & PRs** | | |
| List discussions | `get_repo_discussions()` | GET `/api/{type}/{id}/discussions` |
| Get discussion details | `get_discussion_details()` | Single discussion |
| Create discussion | `create_discussion()` | New discussion thread |
| Create pull request | `create_pull_request()` | PR from branch |
| Comment on discussion | `comment_discussion()` | Add comment |
| Merge pull request | `merge_pull_request()` | Merge PR |
| Change status | `change_discussion_status()` | Open/close |
| **Collections** | | |
| Get collection | `get_collection()` | Collection metadata |
| Create collection | `create_collection()` | New collection |
| Update collection | `update_collection_metadata()` | Edit collection |
| Delete collection | `delete_collection()` | Remove collection |
| Add/remove items | `add/delete_collection_item()` | Manage items |
| **Webhooks** | | |
| List webhooks | `list_webhooks()` | GET `/api/webhooks` |
| Create webhook | `create_webhook()` | POST `/api/webhooks` |
| Update webhook | `update_webhook()` | PATCH `/api/webhooks/{id}` |
| Delete webhook | `delete_webhook()` | DELETE `/api/webhooks/{id}` |
| Enable/disable | `enable/disable_webhook()` | Toggle state |
| **Social** | | |
| Like repo | `like()` | POST `/api/{type}/{id}/like` |
| Unlike repo | `unlike()` | DELETE `/api/{type}/{id}/like` |
| List liked repos | `list_liked_repos()` | User's likes |
| List repo likers | `list_repo_likers()` | Who liked a repo |
| **User/Org Info** | | |
| Get user overview | `get_user_overview()` | User profile |
| Get org overview | `get_organization_overview()` | Org profile |
| List followers | `list_user_followers()` | Follower list |
| List following | `list_user_following()` | Following list |
| **Inference** | | |
| Inference endpoints | `create/delete_inference_endpoint()` | Managed inference |
| Inference API | Direct API calls | Serverless inference |
| **Misc** | | |
| Get model/dataset tags | `get_model_tags()`, `get_dataset_tags()` | Tag taxonomy |
| Paper info | `paper_info()` | ArXiv paper metadata |
| Safetensors metadata | `get_safetensors_metadata()` | Tensor info |

---

## Implementation Order

Recommended order for implementing remaining features:

```
Phase 1: Write Operations (High Priority)
├── create_repo / delete_repo
├── upload_file (simple multipart)
├── create_commit
└── upload_folder

Phase 2: Repository Management (Medium Priority)
├── repo_exists / file_exists
├── list_repo_tree
├── create_branch / delete_branch
└── create_tag / delete_tag

Phase 3: Spaces (Medium Priority)
├── list_spaces
├── pause_space / restart_space
└── Space secrets/variables

Phase 4: Social & Discussions (Low Priority)
├── Discussions API
├── Collections API
└── Like/unlike, followers
```

---

## Related HuggingFace Ecosystem

For context on how `hf_hub_ex` fits into the broader ecosystem:

| Python Library | Stars | Depends on `huggingface_hub` | Elixir Port Status |
|----------------|-------|------------------------------|-------------------|
| [transformers](https://github.com/huggingface/transformers) | 154k | Yes | Not started |
| [diffusers](https://github.com/huggingface/diffusers) | 32k | Yes | Not started |
| [datasets](https://github.com/huggingface/datasets) | 21k | Yes | Planned (`crucible_datasets`) |
| [peft](https://github.com/huggingface/peft) | 20k | Yes | Not started |
| [trl](https://github.com/huggingface/trl) | 17k | Yes | Not started |
| [accelerate](https://github.com/huggingface/accelerate) | 9k | Yes | Not started |
| [evaluate](https://github.com/huggingface/evaluate) | 2k | Yes | Planned |
| [tokenizers](https://github.com/huggingface/tokenizers) | 9k | No (Rust) | Could use NIF |
| [safetensors](https://github.com/huggingface/safetensors) | 3k | No (Rust) | Could use NIF |

### Recommended Port Order

1. **hf_hub_ex** (this library) - Hub API client
2. **datasets port** - Dataset loading, integrates with `crucible_datasets`
3. **evaluate port** - Metrics (BLEU, ROUGE, F1)
4. **tokenizers NIF** - Rust bindings for fast tokenization
5. **safetensors NIF** - Rust bindings for tensor loading

---

## API Compatibility Notes

### Endpoint Versions

- `/api/whoami-v2` - Required for modern tokens (not `/api/whoami`)
- Download URLs require type prefix: `datasets/{repo}`, `spaces/{repo}`

### Token Types

HuggingFace supports multiple token types:
- **Fine-grained tokens** - Scoped permissions (recommended)
- **Write tokens** - Full write access
- **Read tokens** - Read-only access

Classic tokens deprecated December 2025. Use fine-grained tokens.

### Rate Limits

- `/api/whoami-v2` is heavily rate-limited for security
- Use `cache: true` option when calling repeatedly
- File downloads have no practical limits

---

## Contributing

Priority areas for contribution:

1. Repository management (create/delete)
2. File upload implementation
3. Test coverage for existing features
