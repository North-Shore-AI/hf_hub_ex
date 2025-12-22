# Tinker Cookbook HF Hub Requirements

## Datasets Required
| Dataset | Repo ID | Files | Splits | Used By |
|---------|---------|-------|--------|---------|
| GSM8K | openai/gsm8k | data/{split}-*.parquet (expected HF shard layout) | train, test | math_rl (gsm8k env), rl_loop |
| MATH-500 | HuggingFaceH4/MATH-500 | data/{split}-*.parquet (default config) | test | math_rl (math env test set) |
| Hendrycks MATH | EleutherAI/hendrycks_math | config dirs with split shards (auto-detect parquet/json) | train, test | math_rl (math env train/test) |
| Polaris 53K | POLARIS-Project/Polaris-Dataset-53K | split shards (auto-detect parquet/json) | train | math_rl (polaris env) |
| DeepMath-103K | zwhe99/DeepMath-103K | split shards (auto-detect parquet/json) | train (test if available) | math_rl (deepmath env), distillation (prompt-only) |
| Tulu-3 SFT Mixture | allenai/tulu-3-sft-mixture | data/train-*.parquet (large shard set) | train | chat_sl (tulu3), distillation (prompt-only) |
| No Robots | HuggingFaceH4/no_robots | split shards (auto-detect parquet/jsonl) | train, test | chat_sl (no_robots), sl_loop |
| DeepCoder Preview | agentica-org/DeepCoder-Preview-Dataset | config/{split}-*.parquet (configs: primeintellect, taco, lcbv5, codeforces) | train, test | code_rl (LiveCodeBench via lcbv5) |
| OpenThoughts3-1.2M | open-thoughts/OpenThoughts3-1.2M | streaming dataset (parquet/jsonl shards) | train | distillation/off_policy_reasoning |
| Search R1 | PeterJinGo/nq_hotpotqa_train | train.parquet, test.parquet | train, test | tool_use/search |
| Tulu 3.8B Preference | allenai/llama-3.1-tulu-3-8b-preference-mixture | split shards (auto-detect parquet/jsonl) | train | preference |
| HH-RLHF | Anthropic/hh-rlhf | split shards (auto-detect parquet/jsonl) | train, test | preference |
| HelpSteer3 | nvidia/HelpSteer3 (config: preference) | split shards (auto-detect parquet/jsonl) | train, validation | preference |
| HelpSteer2 | nvidia/HelpSteer2 | split shards (auto-detect parquet/jsonl) | train | preference |
| UltraFeedback | argilla/ultrafeedback-binarized-preferences | split shards (auto-detect parquet/jsonl) | train | preference |
| Arena Human Preference 140K | lmarena-ai/arena-human-preference-140k | split shards (auto-detect parquet/jsonl) | train | preference |
| Prometheus Feedback Collection | prometheus-eval/Feedback-Collection | split shards (auto-detect parquet/jsonl) | train | rubric |
| Caltech101 | dpdl-benchmark/caltech101 | image dataset (parquet/arrow or archive) | train, test | vlm_classifier |
| Oxford Flowers 102 | dpdl-benchmark/oxford_flowers102 | image dataset (parquet/arrow or archive) | train, test | vlm_classifier |
| Oxford IIIT Pet | dpdl-benchmark/oxford_iiit_pet | image dataset (parquet/arrow or archive) | train, test | vlm_classifier |
| Stanford Cars | tanganke/stanford_cars | image dataset (parquet/arrow or archive) | train, test | vlm_classifier |

Notes:
- File patterns are based on loader expectations and common HF layouts. CrucibleDatasets can parse parquet/json/jsonl/csv; archive formats require extraction support.
- Some datasets above are gated (for example Anthropic/hh-rlhf). Token auth is required for gated repos.

## HF Hub Operations Required
| Operation | Python API | Parameters | Returns |
|-----------|------------|------------|---------|
| List repo files (recursive) | HfApi.list_repo_tree / list_repo_files | repo_id, repo_type, revision, token, recursive, path_in_repo | list of file paths or file/folder metadata |
| Download file to cache | hf_hub_download | repo_id, filename, repo_type, revision, token, force_download | local cache path |
| Stream file | hf_hub_download + streaming (python) | repo_id, filename, repo_type, revision, token | stream of bytes |
| Get dataset info | dataset_info | repo_id, revision, token, files_metadata | dataset metadata (siblings, sha, etc) |
| List dataset configs | get_dataset_config_names | repo_id, token | list of config names |
| Cache lookup | try_to_load_from_cache (internal) | repo_id, filename, repo_type, revision | cached path or not cached |

## Data Flow

```
Tinker cookbook recipes
  -> crucible_datasets loaders
    -> CrucibleDatasets.Fetcher.HuggingFace
      -> hf_hub_ex (HfHub.Api, HfHub.Download, HfHub.Cache)
        -> HuggingFace Hub API + CDN
```
