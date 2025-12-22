#!/usr/bin/env elixir
#
# Example: Dataset configs + splits (with fallback)
#
# Run with: mix run examples/dataset_configs_splits.exs
#

repo_id = "dpdl-benchmark/caltech101"

IO.puts("\n=== Dataset configs + splits for #{repo_id} ===\n")

config =
  case HfHub.Api.dataset_configs(repo_id) do
    {:ok, configs} ->
      IO.puts("Configs: #{Enum.join(configs, ", ")}")
      List.first(configs) || "default"

    {:error, reason} ->
      IO.puts("Error fetching configs: #{inspect(reason)}")
      "default"
  end

case HfHub.Api.dataset_splits(repo_id, config: config) do
  {:ok, splits} ->
    IO.puts("Splits for #{config}: #{Enum.join(splits, ", ")}")

  {:error, reason} ->
    IO.puts("Error fetching splits: #{inspect(reason)}")
end
