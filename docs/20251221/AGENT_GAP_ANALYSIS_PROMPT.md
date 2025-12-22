# Agent Task: HF Hub Elixir Port Gap Analysis for Tinker Cookbook

## Mission

You are tasked with performing a **critical gap analysis** between the Python `huggingface_hub` library and its Elixir port `hf_hub_ex`, specifically scoped to what's needed to run the **Tinker Cookbook** experiments via the **crucible_datasets** Elixir library.

Your deliverable is a **unified, superseding set of documents** that:
1. Precisely define the remaining work in `hf_hub_ex`
2. Provide TDD-based implementation plans with working examples
3. Supersede and consolidate all existing planning documents

---

## Context & Directory Layout

```
~/p/g/North-Shore-AI/
├── hf_hub_ex/                    # Elixir port (YOUR FOCUS)
│   ├── lib/                      # Elixir source code
│   ├── huggingface_hub/          # Original Python library (reference)
│   └── docs/
│       ├── ROADMAP.md
│       └── 20251221/
│           ├── API_GAPS.md
│           ├── DOWNLOAD_GAPS.md
│           ├── IMPLEMENTATION_PLAN.md
│           ├── REMAINING_WORK.md
│           └── tinker_parity/
│               └── hf_hub_ex_tinker_parity_status.md
│
├── crucible_datasets/            # Elixir dataset library (CONSUMER)
│   ├── lib/dataset_manager/
│   │   ├── source/huggingface.ex        # HF source integration
│   │   ├── fetcher/huggingface.ex       # HF fetcher
│   │   ├── loader/*.ex                  # Dataset loaders (gsm8k, mmlu, etc.)
│   │   └── format/parquet.ex            # Parquet format support
│   └── datasets/                 # Python datasets lib (reference)
│
└── tinkex_cookbook/
    └── tinker-cookbook/          # Python cookbook (REQUIREMENTS SOURCE)
        ├── tinker_cookbook/
        │   ├── supervised/       # SL training code
        │   ├── rl/               # RL training code
        │   ├── renderers.py      # Message/token rendering
        │   └── recipes/          # Experiment recipes
        └── docs/                 # Tinker documentation
```

---

## Your Analysis Tasks

### 1. Trace the Dependency Chain

**Start from tinker-cookbook and trace backwards:**

```
tinker-cookbook experiments
        ↓ needs
    datasets (GSM8K, MMLU, Tulu3, etc.)
        ↓ loaded via
    crucible_datasets (Elixir)
        ↓ fetches from
    HuggingFace Hub API
        ↓ requires
    hf_hub_ex (Elixir client)
```

**Specifically identify:**

a) **What datasets do tinker-cookbook recipes use?**
   - Read `tinker-cookbook/tinker_cookbook/recipes/*/`
   - Read `tinker-cookbook/tinker_cookbook/supervised/data.py`
   - Read `tinker-cookbook/tinker_cookbook/distillation/datasets.py`
   - List every HuggingFace dataset referenced

b) **What HF Hub operations does crucible_datasets need?**
   - Read `crucible_datasets/lib/dataset_manager/source/huggingface.ex`
   - Read `crucible_datasets/lib/dataset_manager/fetcher/huggingface.ex`
   - List every HF API call made

c) **What does hf_hub_ex currently implement?**
   - Read all `.ex` files in `hf_hub_ex/lib/`
   - Create inventory of working functions
   - Note which have tests passing

---

### 2. Identify Specific Gaps

For each HF Hub operation needed by crucible_datasets:

| Operation | Python Function | hf_hub_ex Status | Priority |
|-----------|----------------|------------------|----------|
| Download file | `hf_hub_download()` | ??? | ??? |
| List repo files | `list_repo_files()` | ??? | ??? |
| Get dataset info | `dataset_info()` | ??? | ??? |
| Download dataset | `snapshot_download()` | ??? | ??? |
| ... | ... | ... | ... |

**Priority levels:**
- **P0**: Blocks running ANY cookbook experiment
- **P1**: Blocks specific recipes (list which)
- **P2**: Nice to have, can work around

---

### 3. Review Existing Documentation

Read and critically assess:

1. `hf_hub_ex/docs/ROADMAP.md`
2. `hf_hub_ex/docs/20251221/API_GAPS.md`
3. `hf_hub_ex/docs/20251221/DOWNLOAD_GAPS.md`
4. `hf_hub_ex/docs/20251221/IMPLEMENTATION_PLAN.md`
5. `hf_hub_ex/docs/20251221/REMAINING_WORK.md`
6. `hf_hub_ex/docs/20251221/tinker_parity/hf_hub_ex_tinker_parity_status.md`

**For each document, note:**
- What's accurate/still relevant?
- What's outdated or superseded?
- What's missing?
- What conflicts with other docs?

---

### 4. Analyze the Python Reference

In `hf_hub_ex/huggingface_hub/src/huggingface_hub/`:

- `hf_api.py` - Main API class
- `file_download.py` - Download functionality
- `hub_mixin.py` - Model hub integration
- `repository.py` - Git-based repo ops
- `utils/` - Utilities

**Focus on:**
- Function signatures needed by crucible_datasets
- Edge cases and error handling patterns
- Caching behavior
- Authentication flow

---

### 5. Verify Against Tinker Cookbook Requirements

Read the tinker-cookbook to understand data flow:

1. `tinker-cookbook/docs/training-sampling.mdx` - How data is prepared
2. `tinker-cookbook/docs/rendering.mdx` - How messages become tokens
3. `tinker-cookbook/tinker_cookbook/supervised/data.py` - Dataset loading patterns
4. `tinker-cookbook/tinker_cookbook/recipes/math_rl/train.py` - Example: GSM8K usage
5. `tinker-cookbook/tinker_cookbook/recipes/chat_sl/train.py` - Example: Tulu3 usage

**Document:**
- Exact dataset identifiers (e.g., `openai/gsm8k`, `allenai/tulu-3-sft-mixture`)
- Required file types (parquet, json, jsonl)
- Required splits (train, validation, test)
- Any preprocessing that happens client-side

---

## Deliverables

Create these documents in `hf_hub_ex/docs/20251221/`:

### Document 1: `COOKBOOK_REQUIREMENTS.md`

```markdown
# Tinker Cookbook HF Hub Requirements

## Datasets Required
| Dataset | Repo ID | Files | Splits | Used By |
|---------|---------|-------|--------|---------|
| GSM8K | openai/gsm8k | *.parquet | train, test | math_rl |
| ... | ... | ... | ... | ... |

## HF Hub Operations Required
| Operation | Python API | Parameters | Returns |
|-----------|-----------|------------|---------|
| ... | ... | ... | ... |

## Data Flow
[Diagram showing cookbook → crucible_datasets → hf_hub_ex → HF API]
```

### Document 2: `HF_HUB_EX_CURRENT_STATE.md`

```markdown
# hf_hub_ex Current Implementation State

## Working Functions (with tests)
| Module | Function | Test File | Notes |
|--------|----------|-----------|-------|
| ... | ... | ... | ... |

## Partially Working (no tests or failing)
| Module | Function | Issue |
|--------|----------|-------|
| ... | ... | ... |

## Not Implemented
| Required Function | Priority | Blocks |
|-------------------|----------|--------|
| ... | ... | ... |
```

### Document 3: `GAP_ANALYSIS.md`

```markdown
# Gap Analysis: hf_hub_ex vs Cookbook Requirements

## Critical Gaps (P0)
[Functions that completely block cookbook usage]

## High Priority Gaps (P1)
[Functions needed for specific recipes]

## Low Priority Gaps (P2)
[Nice to have, workarounds exist]

## What We DON'T Need
[HF Hub features not required for cookbook - explicitly skip these]
```

### Document 4: `IMPLEMENTATION_PLAN_UNIFIED.md`

```markdown
# Unified Implementation Plan

## Phase 1: Core Download (P0)
### 1.1 hf_hub_download/2
- Current state: ...
- Required behavior: ...
- Test plan:
  ```elixir
  # Test 1: Download single file
  test "downloads file from public repo" do
    ...
  end
  ```
- Implementation steps:
  1. ...
  2. ...

### 1.2 ...

## Phase 2: Dataset Operations (P1)
...

## Phase 3: Nice to Have (P2)
...
```

### Document 5: `TDD_EXAMPLES.md`

```markdown
# TDD Examples for hf_hub_ex

## Example 1: Downloading GSM8K

### The Test (write first)
```elixir
defmodule HfHubEx.Integration.GSM8KTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  describe "GSM8K dataset download" do
    test "downloads train split parquet file" do
      result = HfHubEx.hf_hub_download(
        "openai/gsm8k",
        "data/train-00000-of-00001.parquet",
        repo_type: :dataset
      )

      assert {:ok, path} = result
      assert File.exists?(path)
      assert String.ends_with?(path, ".parquet")
    end
  end
end
```

### The Implementation
```elixir
defmodule HfHubEx do
  def hf_hub_download(repo_id, filename, opts \\ []) do
    # Implementation here
  end
end
```

## Example 2: ...
```

### Document 6: `SUPERSEDED_DOCS.md`

```markdown
# Superseded Documentation

The following documents are superseded by this unified plan:

| Old Document | Status | Replaced By |
|--------------|--------|-------------|
| ROADMAP.md | Partially superseded | IMPLEMENTATION_PLAN_UNIFIED.md |
| API_GAPS.md | Superseded | GAP_ANALYSIS.md |
| ... | ... | ... |

## Change Log
- 2025-12-21: Created unified documentation set
  - Consolidated 6 existing documents
  - Added TDD examples
  - Scoped to cookbook requirements only
```

---

## Critical Questions to Answer

1. **What is the MINIMUM set of HF Hub functions needed to run:**
   - `tinker_cookbook/recipes/math_rl/train.py` (GSM8K)
   - `tinker_cookbook/recipes/chat_sl/train.py` (Tulu3)
   - `tinker_cookbook/recipes/code_rl/train.py` (LiveCodeBench)

2. **Does crucible_datasets currently work?**
   - Run `mix test` in crucible_datasets
   - Which tests pass/fail?
   - What's blocking the failing tests?

3. **What caching behavior is required?**
   - Does crucible_datasets expect HF Hub caching?
   - What cache directory structure?
   - Cache invalidation strategy?

4. **Authentication requirements:**
   - Which datasets are public vs gated?
   - How does token auth work in hf_hub_ex?
   - Is it tested?

5. **Error handling:**
   - What errors does crucible_datasets expect?
   - Rate limiting handling?
   - Retry logic?

---

## Output Format

After completing your analysis, structure your output as:

```
## Summary
[2-3 paragraph executive summary]

## Critical Findings
[Bullet points of most important discoveries]

## Recommended Immediate Actions
[Ordered list of next steps]

## Documents Created
[List of documents with brief descriptions]
```

---

## Validation Checklist

Before completing, verify:

- [ ] Every cookbook recipe's dataset requirements traced
- [ ] Every crucible_datasets HF call identified
- [ ] Every hf_hub_ex function audited
- [ ] All existing docs reviewed for conflicts
- [ ] TDD examples are runnable
- [ ] Implementation plan has clear acceptance criteria
- [ ] Scope is MINIMAL (only what cookbook needs)
