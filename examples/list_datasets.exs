#!/usr/bin/env elixir
#
# Example: List top datasets from HuggingFace Hub
#
# Run with: mix run examples/list_datasets.exs
#

IO.puts("\n=== Listing Top 5 Datasets ===\n")

case HfHub.Api.list_datasets(limit: 5, sort: "downloads") do
  {:ok, datasets} ->
    datasets
    |> Enum.with_index(1)
    |> Enum.each(fn {dataset, index} ->
      IO.puts("#{index}. #{dataset.id}")
      IO.puts("   Downloads: #{dataset.downloads}")
      IO.puts("   Likes: #{dataset.likes}")

      if dataset.tags && length(dataset.tags) > 0 do
        IO.puts("   Tags: #{Enum.join(Enum.take(dataset.tags, 3), ", ")}")
      end

      IO.puts("")
    end)

  {:error, reason} ->
    IO.puts("Error listing datasets: #{inspect(reason)}")
end
