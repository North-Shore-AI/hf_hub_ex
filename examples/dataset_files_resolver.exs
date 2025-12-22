#!/usr/bin/env elixir
#
# Example: Resolve dataset files for a config + split
#
# Run with: mix run examples/dataset_files_resolver.exs
#

repo_id = "dpdl-benchmark/caltech101"
split = "train"

IO.puts("\n=== Dataset file resolver for #{repo_id} ===\n")

config =
  case HfHub.Api.dataset_configs(repo_id) do
    {:ok, [first | _]} ->
      first

    {:ok, []} ->
      "default"

    {:error, reason} ->
      IO.puts("Error fetching configs: #{inspect(reason)}")
      "default"
  end

case HfHub.DatasetFiles.resolve(repo_id, config, split) do
  {:ok, files} ->
    IO.puts("Config: #{config}")
    IO.puts("Split: #{split}")
    IO.puts("Files:")
    Enum.each(files, &IO.puts("- #{&1}"))

  {:error, reason} ->
    IO.puts("Error resolving files: #{inspect(reason)}")
end
