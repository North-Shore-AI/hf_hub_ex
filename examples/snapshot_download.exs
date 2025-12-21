#!/usr/bin/env elixir
#
# Example: Download entire repository snapshot
#
# Run with: mix run examples/snapshot_download.exs
#
# This example demonstrates:
# - Downloading all files from a repository
# - Using ignore/allow patterns
# - Parallel downloads
#

IO.puts("\n=== Snapshot Download Demo ===\n")

repo_id = "hf-internal-testing/tiny-random-bert"

IO.puts("Downloading snapshot of #{repo_id}...")
IO.puts("(Using a tiny test model to keep download small)\n")

# First, list available files
IO.puts("Files in repository:")

case HfHub.Api.list_files(repo_id, repo_type: :model) do
  {:ok, files} ->
    for file <- files do
      size =
        if file.size > 1024 do
          "#{div(file.size, 1024)} KB"
        else
          "#{file.size} B"
        end

      IO.puts("  #{file.rfilename} (#{size})")
    end

    IO.puts("")

  {:error, reason} ->
    IO.puts("  Error listing files: #{inspect(reason)}")
end

# Download with patterns
IO.puts("Downloading (ignoring large binary files)...")

case HfHub.Download.snapshot_download(
       repo_id: repo_id,
       repo_type: :model,
       ignore_patterns: ["*.bin", "*.safetensors", "*.h5"]
     ) do
  {:ok, snapshot_path} ->
    IO.puts("\nSnapshot downloaded to: #{snapshot_path}\n")

    # List downloaded files
    IO.puts("Downloaded files:")

    Path.wildcard(Path.join(snapshot_path, "**/*"))
    |> Enum.filter(&File.regular?/1)
    |> Enum.each(fn path ->
      relative = Path.relative_to(path, snapshot_path)
      size = File.stat!(path).size
      IO.puts("  #{relative} (#{size} bytes)")
    end)

  {:error, reason} ->
    IO.puts("Error: #{inspect(reason)}")
end

IO.puts("\n=== Demo Complete ===\n")
