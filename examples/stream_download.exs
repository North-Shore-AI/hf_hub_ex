#!/usr/bin/env elixir
#
# Example: Streaming download from HuggingFace Hub
#
# Run with: mix run examples/stream_download.exs
#
# This example demonstrates:
# - Downloading files as a stream
# - Processing chunks as they arrive
# - Progress tracking
#

IO.puts("\n=== Streaming Download Demo ===\n")

repo_id = "bert-base-uncased"
filename = "config.json"

IO.puts("Streaming #{filename} from #{repo_id}...")
IO.puts("")

case HfHub.Download.download_stream(
       repo_id: repo_id,
       filename: filename,
       repo_type: :model
     ) do
  {:ok, stream} ->
    # Process stream with chunk counting
    {content, chunk_count} =
      stream
      |> Stream.with_index(1)
      |> Enum.reduce({"", 0}, fn {chunk, idx}, {acc, _} ->
        IO.write("\rReceived chunk #{idx}...")
        {acc <> chunk, idx}
      end)

    IO.puts("\n")
    IO.puts("Download complete!")
    IO.puts("  Total chunks: #{chunk_count}")
    IO.puts("  Total bytes: #{byte_size(content)}")

    # Parse the JSON
    case Jason.decode(content) do
      {:ok, json} ->
        IO.puts("\nParsed config.json:")
        IO.puts("  Model type: #{json["model_type"]}")
        IO.puts("  Hidden size: #{json["hidden_size"]}")
        IO.puts("  Vocab size: #{json["vocab_size"]}")

      {:error, _} ->
        IO.puts("\nContent preview:")
        IO.puts(String.slice(content, 0, 200))
    end

  {:error, reason} ->
    IO.puts("Error: #{inspect(reason)}")
end

IO.puts("\n=== Demo Complete ===\n")
