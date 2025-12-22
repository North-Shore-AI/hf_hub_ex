#!/usr/bin/env elixir
#
# Example: Download and extract an archive
#
# Run with: mix run examples/download_with_extract.exs
#

repo_id = "albertvillanova/tmp-tests-zip"
filename = "ds.zip"

IO.puts("\n=== Download + extract #{filename} from #{repo_id} ===\n")

case HfHub.Download.hf_hub_download(
       repo_id: repo_id,
       filename: filename,
       repo_type: :dataset,
       extract: true
     ) do
  {:ok, extracted_path} ->
    IO.puts("Extracted to: #{extracted_path}")

    if File.dir?(extracted_path) do
      extracted_path
      |> Path.join("**/*")
      |> Path.wildcard()
      |> Enum.reject(&File.dir?/1)
      |> Enum.each(fn file ->
        IO.puts("- #{Path.relative_to(file, extracted_path)}")
      end)
    else
      IO.puts("Extracted file: #{Path.basename(extracted_path)}")
    end

  {:error, reason} ->
    IO.puts("Error downloading archive: #{inspect(reason)}")
    IO.puts("\nNote: This example requires internet access.")
end
