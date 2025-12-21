#!/usr/bin/env elixir
#
# Example: Get information about a specific dataset
#
# Run with: mix run examples/dataset_info.exs
#

dataset_id = "openai/gsm8k"

IO.puts("\n=== Dataset Info: #{dataset_id} ===\n")

case HfHub.Api.dataset_info(dataset_id) do
  {:ok, info} ->
    IO.puts("ID: #{info.id}")
    IO.puts("Author: #{info.author || "N/A"}")
    IO.puts("Downloads: #{info.downloads}")
    IO.puts("Likes: #{info.likes}")

    if info.tags && length(info.tags) > 0 do
      IO.puts("Tags: #{Enum.join(info.tags, ", ")}")
    end

    if info.created_at do
      IO.puts("Created: #{Calendar.strftime(info.created_at, "%Y-%m-%d")}")
    end

    if info.updated_at do
      IO.puts("Updated: #{Calendar.strftime(info.updated_at, "%Y-%m-%d")}")
    end

    IO.puts("\nFiles in repository:")

    if info.siblings && length(info.siblings) > 0 do
      info.siblings
      |> Enum.take(10)
      |> Enum.each(fn file ->
        size_mb = Float.round(file.size / (1024 * 1024), 2)
        IO.puts("  - #{file.rfilename} (#{size_mb} MB)")
      end)
    else
      IO.puts("  No files found")
    end

  {:error, reason} ->
    IO.puts("Error getting dataset info: #{inspect(reason)}")
end
