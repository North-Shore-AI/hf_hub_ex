#!/usr/bin/env elixir
#
# Example: Demonstrate cache functionality
#
# Run with: mix run examples/cache_demo.exs
#

repo_id = "bert-base-uncased"
filename = "config.json"

IO.puts("\n=== Cache Demo ===\n")

# Check if file is cached
cached = HfHub.Cache.cached?(repo_id: repo_id, filename: filename, repo_type: :model)
IO.puts("Is #{filename} cached? #{cached}")

# Get cache path (will fail if not cached)
case HfHub.Cache.cache_path(repo_id: repo_id, filename: filename, repo_type: :model) do
  {:ok, path} ->
    IO.puts("Cache path: #{path}")

  {:error, :not_cached} ->
    IO.puts("File is not cached yet")
end

# Show cache statistics
case HfHub.Cache.cache_stats() do
  {:ok, stats} ->
    IO.puts("\n=== Cache Statistics ===")
    IO.puts("Total files: #{stats.file_count}")
    IO.puts("Total size: #{stats.total_size} bytes")

    if length(stats.repos) > 0 do
      IO.puts("Cached repos: #{Enum.join(stats.repos, ", ")}")
    end

  {:error, reason} ->
    IO.puts("Error getting cache stats: #{inspect(reason)}")
end
