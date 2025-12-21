#!/bin/bash
#
# Run all HfHub examples
#
# Usage: ./examples/run_all.sh
#        HF_TOKEN=hf_xxx ./examples/run_all.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "========================================"
echo "  HfHub Examples Runner"
echo "========================================"
echo ""

if [ -n "$HF_TOKEN" ]; then
    echo "HF_TOKEN is set - authenticated examples will work"
else
    echo "HF_TOKEN not set - some examples may have limited functionality"
fi
echo ""

examples=(
    "list_datasets.exs"
    "list_models.exs"
    "dataset_info.exs"
    "download_file.exs"
    "cache_demo.exs"
    "stream_download.exs"
    "snapshot_download.exs"
    "auth_demo.exs"
)

for example in "${examples[@]}"; do
    echo "========================================"
    echo "Running: $example"
    echo "========================================"
    mix run "examples/$example"
    echo ""
done

echo "========================================"
echo "  All examples completed!"
echo "========================================"
