#!/usr/bin/env elixir
#
# Example: Download a file from HuggingFace Hub
#
# Run with: mix run examples/download_file.exs
#
# Note: This example requires an active internet connection
#

repo_id = "openai-community/gpt2"
filename = "README.md"

IO.puts("\n=== Downloading #{filename} from #{repo_id} ===\n")

case HfHub.Download.hf_hub_download(
       repo_id: repo_id,
       filename: filename,
       repo_type: :model
     ) do
  {:ok, path} ->
    IO.puts("Downloaded to: #{path}")
    IO.puts("\nFile size: #{File.stat!(path).size} bytes")

    IO.puts("\nFirst 500 characters:")
    IO.puts(String.slice(File.read!(path), 0, 500))
    IO.puts("...")

  {:error, reason} ->
    IO.puts("Error downloading file: #{inspect(reason)}")
    IO.puts("\nNote: This example requires an active internet connection")
    IO.puts("and the HuggingFace Hub API to be accessible.")
end
