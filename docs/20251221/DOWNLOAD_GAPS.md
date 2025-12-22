# Download and Cache Gaps Analysis

**Date:** 2025-12-21
**Python Reference:** `./huggingface_hub/src/huggingface_hub/file_download.py`

---

## 1. Archive Extraction Support

### Current State

Downloaded files are left as-is, no extraction.

### Problem

Many datasets are distributed as archives:
- `.zip` - Common for image datasets
- `.tar.gz` / `.tgz` - Standard Unix archives
- `.tar.xz` - High compression archives
- `.gz` - Single-file compression

### Examples of Datasets Requiring Extraction

1. **caltech101** - Images in tar.gz
2. **oxford_flowers102** - Images in tar.gz
3. **CIFAR-10** - Binary files in tar.gz

### Required Implementation

```elixir
defmodule HfHub.Extract do
  @moduledoc """
  Archive extraction utilities for downloaded files.
  """

  @spec extract(archive_path :: String.t(), dest_dir :: String.t(), keyword()) ::
    {:ok, %{files: [String.t()], total_size: integer()}} | {:error, term()}
  def extract(archive_path, dest_dir, opts \\ []) do
    File.mkdir_p!(dest_dir)

    case detect_archive_type(archive_path) do
      :zip -> extract_zip(archive_path, dest_dir, opts)
      {:tar, compression} -> extract_tar(archive_path, dest_dir, compression, opts)
      :gzip -> extract_gzip(archive_path, dest_dir, opts)
      :xz -> extract_xz(archive_path, dest_dir, opts)
      :unknown -> {:error, :unsupported_format}
    end
  end

  @spec detect_archive_type(String.t()) :: atom() | {:tar, atom()}
  def detect_archive_type(path) do
    ext = Path.extname(path)

    case ext do
      ".zip" -> :zip
      ".tar" -> {:tar, :none}
      ".tgz" -> {:tar, :gzip}
      ".gz" ->
        if String.ends_with?(path, ".tar.gz"), do: {:tar, :gzip}, else: :gzip
      ".xz" ->
        if String.ends_with?(path, ".tar.xz"), do: {:tar, :xz}, else: :xz
      ".bz2" ->
        if String.ends_with?(path, ".tar.bz2"), do: {:tar, :bzip2}, else: :unknown
      _ -> :unknown
    end
  end

  # ZIP extraction using Erlang :zip module
  defp extract_zip(archive_path, dest_dir, _opts) do
    case :zip.unzip(to_charlist(archive_path), [{:cwd, to_charlist(dest_dir)}]) do
      {:ok, files} ->
        file_paths = Enum.map(files, &to_string/1)
        total_size = calculate_total_size(file_paths)
        {:ok, %{files: file_paths, total_size: total_size}}
      {:error, reason} ->
        {:error, {:zip_error, reason}}
    end
  end

  # TAR extraction via System.cmd
  defp extract_tar(archive_path, dest_dir, compression, _opts) do
    flags = case compression do
      :none -> "-xf"
      :gzip -> "-xzf"
      :bzip2 -> "-xjf"
      :xz -> "-xJf"
    end

    case System.cmd("tar", [flags, archive_path, "-C", dest_dir], stderr_to_stdout: true) do
      {_output, 0} ->
        files = list_directory_recursive(dest_dir)
        total_size = calculate_total_size(files)
        {:ok, %{files: files, total_size: total_size}}
      {error, exit_code} ->
        {:error, {:tar_failed, exit_code, error}}
    end
  end

  # GZIP single file decompression
  defp extract_gzip(archive_path, dest_dir, _opts) do
    output_path = Path.join(dest_dir, Path.basename(archive_path, ".gz"))

    with {:ok, compressed} <- File.read(archive_path),
         decompressed <- :zlib.gunzip(compressed),
         :ok <- File.write(output_path, decompressed) do
      {:ok, stat} = File.stat(output_path)
      {:ok, %{files: [output_path], total_size: stat.size}}
    end
  end
end
```

### Integration with Download

```elixir
def hf_hub_download(opts) do
  with {:ok, cache_path} <- do_download(opts) do
    if Keyword.get(opts, :extract, false) do
      extract_if_archive(cache_path, opts)
    else
      {:ok, cache_path}
    end
  end
end

defp extract_if_archive(cache_path, opts) do
  extract_dir = Keyword.get(opts, :extract_dir) ||
                Path.join(Path.dirname(cache_path), "extracted")

  case HfHub.Extract.detect_archive_type(cache_path) do
    :unknown -> {:ok, cache_path}  # Not an archive
    _archive_type ->
      hash = :crypto.hash(:sha256, File.read!(cache_path))
              |> Base.encode16(case: :lower)
      final_extract_dir = Path.join(extract_dir, String.slice(hash, 0..7))

      if File.exists?(final_extract_dir) do
        {:ok, final_extract_dir}
      else
        case HfHub.Extract.extract(cache_path, final_extract_dir) do
          {:ok, %{files: files}} when files != [] -> {:ok, final_extract_dir}
          {:error, reason} -> {:error, {:extraction_failed, reason}}
        end
      end
  end
end
```

### Cache Layout with Extraction

```
~/.cache/huggingface/hub/
└── datasets--username--dataset/
    ├── blobs/
    │   └── abc123...  (original .tar.gz)
    └── extracted/
        └── abc123ab/  (extracted contents)
            ├── image1.jpg
            ├── image2.jpg
            └── ...
```

**Effort Estimate:** 8-10 hours

---

## 2. Streaming Downloads for Large Files

### Current State

- `download_stream/1` returns a Stream
- Basic chunked reading
- No progress reporting
- No bandwidth control

### Problem

Large datasets (>1GB) need:
1. Progress callbacks for UI feedback
2. Bandwidth throttling to avoid overwhelming network
3. Memory-efficient processing

### Enhanced Implementation

```elixir
defmodule HfHub.Download do
  @spec hf_hub_download(keyword()) :: {:ok, Path.t()} | {:error, term()}
  def hf_hub_download(opts) do
    progress_fn = Keyword.get(opts, :progress, &default_progress/2)
    bandwidth_limit = Keyword.get(opts, :bandwidth_limit)

    {:ok, metadata} = get_file_metadata(url, token)
    total_size = metadata.size

    download_with_progress(url, cache_path, total_size, progress_fn, bandwidth_limit)
  end

  defp download_with_progress(url, dest_path, total_size, progress_fn, bandwidth_limit) do
    {:ok, file} = File.open(dest_path, [:write, :binary])

    try do
      stream = get_download_stream(url)

      stream
      |> maybe_throttle(bandwidth_limit)
      |> Stream.transform(0, fn chunk, bytes_downloaded ->
        new_total = bytes_downloaded + byte_size(chunk)
        progress_fn.(new_total, total_size)
        {[chunk], new_total}
      end)
      |> Enum.each(&IO.binwrite(file, &1))

      {:ok, dest_path}
    after
      File.close(file)
    end
  end

  defp maybe_throttle(stream, nil), do: stream
  defp maybe_throttle(stream, bytes_per_sec) do
    chunk_size = 65_536
    chunks_per_sec = div(bytes_per_sec, chunk_size)
    delay_ms = if chunks_per_sec > 0, do: div(1000, chunks_per_sec), else: 0

    Stream.transform(stream, nil, fn chunk, _acc ->
      if delay_ms > 0, do: Process.sleep(delay_ms)
      {[chunk], nil}
    end)
  end
end
```

**Effort Estimate:** 4-6 hours

---

## 3. Resume Support Enhancements

### Current State

- Basic resume with HTTP Range header
- No integrity validation
- No state persistence

### Gaps

1. **No checksum validation** - Resumed file could be corrupted
2. **No state file** - Can't resume after process restart
3. **No automatic retry** - Single failure aborts

### Enhanced Implementation

```elixir
defp start_fresh_download(opts) do
  cache_path = Keyword.fetch!(opts, :cache_path)
  {:ok, metadata} = get_file_metadata(url, token)

  state = %{
    url: url,
    dest_path: cache_path,
    total_size: metadata.size,
    etag: metadata.etag,
    bytes_downloaded: 0
  }
  save_resume_state(cache_path, state)
  download_with_resume_support(state, opts)
end

defp download_with_resume_support(state, opts) do
  {:ok, file} = File.open(state.dest_path, [:append, :binary])

  try do
    headers = [{"Range", "bytes=#{state.bytes_downloaded}-"}]
    stream = get_download_stream(state.url, headers)

    stream
    |> Stream.each(fn chunk ->
      IO.binwrite(file, chunk)
      new_bytes = state.bytes_downloaded + byte_size(chunk)
      if rem(new_bytes, 1_000_000) == 0 do  # Every 1MB
        updated_state = %{state | bytes_downloaded: new_bytes}
        save_resume_state(state.dest_path, updated_state)
      end
    end)
    |> Stream.run()

    validate_download(state.dest_path, state.etag)
    delete_resume_state(state.dest_path)
    {:ok, state.dest_path}
  catch
    error ->
      File.close(file)
      {:error, {:interrupted, error}}
  end
end

defp save_resume_state(cache_path, state) do
  resume_path = cache_path <> ".resume"
  File.write!(resume_path, Jason.encode!(state))
end

defp validate_download(path, expected_etag) do
  hash = File.stream!(path, 65_536)
  |> Enum.reduce(:crypto.hash_init(:sha256), fn chunk, acc ->
    :crypto.hash_update(acc, chunk)
  end)
  |> :crypto.hash_final()
  |> Base.encode16(case: :lower)

  if String.length(expected_etag) == 64 and hash == expected_etag do
    :ok
  else
    :ok  # Can't validate non-hash etags
  end
end
```

### Resume State File Format

```json
{
  "url": "https://huggingface.co/.../file.bin",
  "dest_path": "/cache/hub/.../file.bin",
  "total_size": 1234567890,
  "etag": "abc123...",
  "bytes_downloaded": 500000000,
  "started_at": "2025-12-21T10:30:00Z",
  "last_updated": "2025-12-21T10:35:00Z"
}
```

**Effort Estimate:** 3-4 hours

---

## 4. Download URL Construction Edge Cases

### Current Implementation

```elixir
defp build_download_url(repo_id, repo_type, filename, revision) do
  endpoint = HfHub.Config.endpoint()
  repo_path = repo_type_prefix(repo_type) <> repo_id
  "#{endpoint}/#{repo_path}/resolve/#{revision}/#{filename}"
end
```

### Gaps

1. **No URL encoding** - Filenames with spaces or special chars fail
2. **No subfolder support** - Can't specify subfolder separately
3. **No CDN handling** - Large files redirect to CDN

### Enhanced Implementation

```elixir
defp build_download_url(repo_id, repo_type, filename, revision, opts \\ []) do
  endpoint = HfHub.Config.endpoint()
  subfolder = Keyword.get(opts, :subfolder)

  full_path = if subfolder do
    Path.join(subfolder, filename)
  else
    filename
  end

  encoded_path = full_path
  |> Path.split()
  |> Enum.map(&URI.encode(&1, &URI.char_unreserved?/1))
  |> Path.join()

  repo_path = repo_type_prefix(repo_type) <> repo_id
  "#{endpoint}/#{repo_path}/resolve/#{revision}/#{encoded_path}"
end
```

**Effort Estimate:** 2-3 hours

---

## Summary: Download Gaps

| Feature | Status | Priority | Effort | Complexity |
|---------|--------|----------|--------|------------|
| Archive extraction (.zip) | Missing | CRITICAL | 2h | Low |
| Archive extraction (.tar.gz) | Missing | CRITICAL | 3h | Medium |
| Archive extraction (.tar.xz) | Missing | HIGH | 2h | Medium |
| Progress callbacks | Missing | HIGH | 2h | Low |
| Bandwidth throttling | Missing | MEDIUM | 1h | Low |
| Resume state persistence | Missing | HIGH | 1h | Low |
| Checksum validation | Missing | HIGH | 1h | Low |
| URL encoding | Missing | HIGH | 1h | Low |
| Subfolder support | Missing | MEDIUM | 2h | Low |

**Total Estimated Effort:** 18-20 hours (~2.5 days)

---

**Document Status:** Complete
**Last Updated:** 2025-12-21
