# TDD Examples for hf_hub_ex

## Example 1: Downloading GSM8K

### The Test (write first)
```elixir
defmodule HfHub.Integration.GSM8KTest do
  use ExUnit.Case, async: false

  @moduletag :live

  test "downloads GSM8K train parquet file" do
    {:ok, path} =
      HfHub.Download.hf_hub_download(
        repo_id: "openai/gsm8k",
        filename: "data/train-00000-of-00001.parquet",
        repo_type: :dataset
      )

    assert File.exists?(path)
    assert String.ends_with?(path, ".parquet")
  end
end
```

### The Implementation
```elixir
defmodule HfHub.Download do
  def hf_hub_download(opts) do
    # Existing implementation uses HfHub.FS + HfHub.HTTP to download and cache
  end
end
```

## Example 2: Repo Tree Listing (unit test with Bypass)

### The Test (write first)
```elixir
defmodule HfHub.Api.ListRepoTreeTest do
  use ExUnit.Case, async: true

  test "list_repo_tree returns files and folders" do
    bypass = Bypass.open()
    Application.put_env(:hf_hub, :endpoint, "http://localhost:#{bypass.port}")

    Bypass.expect_once(bypass, "GET", "/api/datasets/test-repo/tree/main", fn conn ->
      Plug.Conn.resp(conn, 200, Jason.encode!([
        %{"type" => "file", "path" => "data/train-00000.parquet", "size" => 123, "oid" => "abc"},
        %{"type" => "directory", "path" => "data", "oid" => "def"}
      ]))
    end)

    assert {:ok, items} = HfHub.Api.list_repo_tree("test-repo", repo_type: :dataset)
    assert Enum.any?(items, &(&1.type == :file))
    assert Enum.any?(items, &(&1.type == :folder))
  end
end
```

### The Implementation
```elixir
defmodule HfHub.Api do
  def list_repo_tree(repo_id, opts \\ []) do
    # New implementation using HfHub.HTTP.get_paginated/2 and tree entry parsing
  end
end
```

## Example 3: Dataset Splits Fallback (unit test with Bypass)

### The Test (write first)
```elixir
defmodule HfHub.Api.DatasetSplitsTest do
  use ExUnit.Case, async: false

  test "falls back to tree inference when dataset_infos.json is missing" do
    bypass = Bypass.open()
    Application.put_env(:hf_hub, :endpoint, "http://localhost:#{bypass.port}")

    Bypass.expect_once(bypass, "GET", "/datasets/test-repo/resolve/main/dataset_infos.json", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(404, Jason.encode!(%{error: "Not Found"}))
    end)

    Bypass.expect_once(bypass, "GET", "/api/datasets/test-repo/tree/main", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, Jason.encode!([
        %{"type" => "file", "path" => "data/train-00000.parquet"},
        %{"type" => "file", "path" => "data/test-00000.parquet"}
      ]))
    end)

    assert {:ok, ["test", "train"]} =
             HfHub.Api.dataset_splits("test-repo", config: "default")
  end
end
```

### The Implementation
```elixir
defmodule HfHub.Api do
  def dataset_splits(repo_id, opts \\ []) do
    # Prefer dataset_infos.json, fallback to list_repo_tree + inference
  end
end
```

## Example 4: Archive Extraction (unit test)

### The Test (write first)
```elixir
defmodule HfHub.ExtractTest do
  use ExUnit.Case, async: true

  test "extracts gzip files" do
    gz_path = "/tmp/sample.txt.gz"
    File.write!(gz_path, :zlib.gzip("hello"))

    assert {:ok, "/tmp/sample.txt"} = HfHub.Extract.extract(gz_path, "/tmp/sample.txt")
  end
end
```

### The Implementation
```elixir
defmodule HfHub.Extract do
  def extract(path, dest) do
    # Detect archive type and extract to dest
  end
end
```
