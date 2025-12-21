#!/usr/bin/env elixir
#
# Example: List top models from HuggingFace Hub
#
# Run with: mix run examples/list_models.exs
#

IO.puts("\n=== Listing Top 5 Text Generation Models ===\n")

case HfHub.Api.list_models(limit: 5, filter: "text-generation", sort: "downloads") do
  {:ok, models} ->
    models
    |> Enum.with_index(1)
    |> Enum.each(fn {model, index} ->
      IO.puts("#{index}. #{model.id}")
      IO.puts("   Downloads: #{model.downloads}")
      IO.puts("   Likes: #{model.likes}")

      if model.pipeline_tag do
        IO.puts("   Pipeline: #{model.pipeline_tag}")
      end

      if model.tags && length(model.tags) > 0 do
        IO.puts("   Tags: #{Enum.join(Enum.take(model.tags, 3), ", ")}")
      end

      IO.puts("")
    end)

  {:error, reason} ->
    IO.puts("Error listing models: #{inspect(reason)}")
end
