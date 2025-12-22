#!/usr/bin/env elixir
#
# Example: List repo tree entries
#
# Run with: mix run examples/list_repo_tree.exs
#

repo_id = "dpdl-benchmark/caltech101"

IO.puts("\n=== Repo tree (root) for #{repo_id} ===\n")

case HfHub.Api.list_repo_tree(repo_id, repo_type: :dataset, recursive: false) do
  {:ok, entries} ->
    IO.puts("Total entries: #{length(entries)}")

    entries
    |> Enum.take(20)
    |> Enum.each(fn entry ->
      IO.puts("#{entry.type}\t#{entry.path}")
    end)

    if length(entries) > 20 do
      IO.puts("... (truncated)")
    end

  {:error, reason} ->
    IO.puts("Error listing repo tree: #{inspect(reason)}")
    IO.puts("\nNote: This example requires internet access.")
end
