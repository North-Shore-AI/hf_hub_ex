# Superseded Documentation

The following documents are superseded by this unified plan:

| Old Document | Status | Replaced By |
|--------------|--------|-------------|
| docs/ROADMAP.md | Partially superseded | docs/20251221/IMPLEMENTATION_PLAN_UNIFIED.md, docs/20251221/GAP_ANALYSIS.md |
| docs/20251221/API_GAPS.md | Superseded | docs/20251221/GAP_ANALYSIS.md, docs/20251221/IMPLEMENTATION_PLAN_UNIFIED.md |
| docs/20251221/DOWNLOAD_GAPS.md | Superseded | docs/20251221/GAP_ANALYSIS.md, docs/20251221/IMPLEMENTATION_PLAN_UNIFIED.md |
| docs/20251221/IMPLEMENTATION_PLAN.md | Superseded | docs/20251221/IMPLEMENTATION_PLAN_UNIFIED.md |
| docs/20251221/REMAINING_WORK.md | Superseded | docs/20251221/GAP_ANALYSIS.md, docs/20251221/IMPLEMENTATION_PLAN_UNIFIED.md |
| docs/20251221/tinker_parity/hf_hub_ex_tinker_parity_status.md | Superseded | docs/20251221/HF_HUB_EX_CURRENT_STATE.md, docs/20251221/GAP_ANALYSIS.md |

## Review Notes (Accuracy / Gaps / Conflicts)
- docs/ROADMAP.md: Accurate for high-level feature list, but overstates list_files/dataset_configs parity and is not scoped to cookbook. Missing large-repo tree listing risks and crucible_datasets integration needs.
- docs/20251221/API_GAPS.md: Core diagnosis (list_repo_tree, dataset_splits, dataset_files) is still valid. It is outdated on file/line references and does not reflect current test status or crucible_datasets call paths.
- docs/20251221/DOWNLOAD_GAPS.md: Extraction and resume gaps remain relevant, but the doc is not tied to cookbook recipes that actually need archive handling.
- docs/20251221/IMPLEMENTATION_PLAN.md: Reasonable structure, but includes non-cookbook work (fs_open, cache introspection) and lacks explicit mapping to cookbook datasets/recipes.
- docs/20251221/REMAINING_WORK.md: Summary aligns with prior gaps but duplicates API_GAPS/DOWNLOAD_GAPS and does not reflect updated test results.
- docs/20251221/tinker_parity/hf_hub_ex_tinker_parity_status.md: Accurate snapshot of existing surface, but missing test status, missing crucible_datasets call inventory, and now superseded by the current-state doc.

## Change Log
- 2025-12-21: Created unified documentation set
  - Consolidated 6 existing documents
  - Added TDD examples and cookbook-scoped priorities
  - Captured test status and crucible_datasets dependencies
