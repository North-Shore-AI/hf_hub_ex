# Implementation Prompts

Sequential prompts for implementing missing features in `hf_hub_ex`.

## Overview

These prompts are designed to be executed sequentially, each building on the previous. Each prompt:
- Assumes a **fresh context** (include all required reading)
- Uses **TDD** (tests before implementation)
- Updates **CHANGELOG.md** with changes
- Updates **README.md** where applicable
- Ensures **quality gates pass**: `mix test`, `mix format`, `mix credo --strict`, `mix dialyzer`

## Prompt Sequence

| # | Prompt | Description | Dependencies |
|---|--------|-------------|--------------|
| 01 | [http-write-methods](01-http-write-methods.md) | POST, PUT, DELETE, PATCH support | None |
| 02 | [repository-management](02-repository-management.md) | Create, delete, update, move repos | 01 |
| 03 | [commit-operations](03-commit-operations.md) | Operation structs and CommitInfo | 01-02 |
| 04 | [file-upload](04-file-upload.md) | Single file upload (regular + LFS) | 01-03 |
| 05 | [folder-upload](05-folder-upload.md) | Folder upload with patterns | 01-04 |
| 06 | [git-operations](06-git-operations.md) | Branches, tags, refs, commits | 01-02 |
| 07 | [discussions](07-discussions.md) | Discussions and pull requests | 01-02 |
| 08 | [collections](08-collections.md) | Collections API | 01-02 |
| 09 | [webhooks](09-webhooks.md) | Webhooks API | 01-02 |
| 10 | [spaces](10-spaces.md) | Space management | 01-02 |
| 11 | [inference-endpoints](11-inference-endpoints.md) | Inference endpoints | 01-02 |
| 12 | [access-requests](12-access-requests.md) | Access request management | 01-02 |
| 13 | [users-orgs-cards](13-users-orgs-cards.md) | Users, Organizations, Cards | 01-02 |

## Execution Order

**Phase 1: Core Write Operations** (Required first)
1. `01-http-write-methods.md` - Foundation for all write operations
2. `02-repository-management.md` - CRUD for repositories

**Phase 2: Upload Support**
3. `03-commit-operations.md` - Data structures
4. `04-file-upload.md` - Single file upload
5. `05-folder-upload.md` - Directory upload

**Phase 3: Git & Community**
6. `06-git-operations.md` - Version control
7. `07-discussions.md` - Community features

**Phase 4: Advanced Features** (Can be parallelized)
8. `08-collections.md`
9. `09-webhooks.md`
10. `10-spaces.md`
11. `11-inference-endpoints.md`
12. `12-access-requests.md`
13. `13-users-orgs-cards.md`

## Usage

Each prompt file contains:

1. **Context** - What you're building and prerequisites
2. **Required Reading** - Files to read first
3. **Task** - What to implement
4. **Implementation Requirements** - Detailed specs with code
5. **Test Requirements** - TDD test cases
6. **Quality Requirements** - Must-pass checks
7. **Changelog Entry** - What to add
8. **README Update** - Documentation changes
9. **Completion Checklist** - Verify all done

## Estimated Lines of Code

| Category | LOC | Test LOC |
|----------|-----|----------|
| HTTP + Repo | ~400 | ~300 |
| Upload API | ~800 | ~500 |
| Git Ops | ~300 | ~200 |
| Community | ~400 | ~250 |
| Advanced | ~1,000 | ~600 |
| Profile/Cards | ~500 | ~300 |
| **Total** | **~3,400** | **~2,150** |

## New Modules Created

After all prompts:
```
lib/hf_hub/
├── repo.ex                   # Repository management
├── repo/repo_url.ex
├── commit.ex                 # Commit operations
├── commit/
│   ├── operation.ex
│   ├── commit_info.ex
│   └── lfs_upload.ex
├── git.ex                    # Git operations
├── git/
│   ├── branch_info.ex
│   ├── tag_info.ex
│   ├── git_refs.ex
│   └── commit_info.ex
├── discussions.ex            # Discussions
├── discussions/
│   ├── discussion.ex
│   ├── discussion_details.ex
│   └── comment.ex
├── collections.ex            # Collections
├── collections/
│   ├── collection.ex
│   └── collection_item.ex
├── webhooks.ex               # Webhooks
├── webhooks/
│   ├── webhook_info.ex
│   └── watched_item.ex
├── spaces.ex                 # Spaces
├── spaces/
│   ├── space_runtime.ex
│   └── space_variable.ex
├── inference_endpoints.ex    # Inference
├── inference_endpoints/
│   └── endpoint.ex
├── access_requests.ex        # Access
├── access_requests/
│   └── access_request.ex
├── users.ex                  # Users
├── organizations.ex          # Orgs
├── users/
│   ├── user.ex
│   └── organization.ex
└── cards.ex                  # Cards
    └── cards/
        ├── model_card.ex
        ├── model_card_data.ex
        ├── dataset_card.ex
        └── dataset_card_data.ex
```

## Dependencies to Add

```elixir
# mix.exs
{:yaml_elixir, "~> 2.9"}  # For card parsing (Prompt 13)
```
