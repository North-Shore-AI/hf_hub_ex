# Prompt 04: Single File Upload Implementation

## Context

You are implementing the single file upload functionality for `hf_hub_ex`. This completes the commit operations started in Prompt 03, supporting both regular (base64) and LFS uploads.

**Prerequisites**: Prompts 01-03 must be completed first.

## Required Reading

**Read these files first:**
```
lib/hf_hub/commit.ex                    # Skeleton from Prompt 03
lib/hf_hub/commit/operation.ex          # Operation types
lib/hf_hub/commit/commit_info.ex        # CommitInfo struct
lib/hf_hub/lfs.ex                       # UploadInfo (sha256, size, sample)
lib/hf_hub/http.ex                      # HTTP client
lib/hf_hub/auth.ex                      # Token handling
```

**Reference documentation:**
```
docs/20251231/upload-api/docs.md        # Full API specification
```

**Python reference:**
```
huggingface_hub/src/huggingface_hub/_commit_api.py
huggingface_hub/src/huggingface_hub/lfs.py
```

## Task

Implement the commit API for single file uploads, including LFS support.

## Implementation Requirements

### 1. Complete `lib/hf_hub/commit.ex`

```elixir
defmodule HfHub.Commit do
  # ... existing module docs and aliases ...

  @lfs_threshold 10 * 1024 * 1024  # 10MB

  @doc """
  Creates a commit with one or more operations.
  """
  @spec create(String.t(), [Operation.t()], commit_opts()) ::
    {:ok, CommitInfo.t()} | {:error, term()}
  def create(repo_id, operations, opts \\ []) when is_list(operations) do
    with :ok <- validate_options(opts),
         {:ok, token} <- get_token(opts),
         {:ok, prepared_ops} <- prepare_operations(operations),
         {:ok, _} <- upload_lfs_files(repo_id, prepared_ops, token, opts),
         {:ok, response} <- commit_operations(repo_id, prepared_ops, token, opts) do
      {:ok, CommitInfo.from_response(response)}
    end
  end

  @spec upload_file(binary() | Path.t(), String.t(), String.t(), commit_opts()) ::
    {:ok, CommitInfo.t()} | {:error, term()}
  def upload_file(path_or_data, path_in_repo, repo_id, opts \\ []) do
    message = opts[:commit_message] || "Upload #{path_in_repo}"
    opts = Keyword.put(opts, :commit_message, message)

    operation = Operation.add(path_in_repo, path_or_data)
    create(repo_id, [operation], opts)
  end

  @spec delete_file(String.t(), String.t(), commit_opts()) ::
    {:ok, CommitInfo.t()} | {:error, term()}
  def delete_file(path_in_repo, repo_id, opts \\ []) do
    message = opts[:commit_message] || "Delete #{path_in_repo}"
    opts = Keyword.put(opts, :commit_message, message)

    operation = Operation.delete(path_in_repo)
    create(repo_id, [operation], opts)
  end

  @spec delete_folder(String.t(), String.t(), commit_opts()) ::
    {:ok, CommitInfo.t()} | {:error, term()}
  def delete_folder(path_in_repo, repo_id, opts \\ []) do
    message = opts[:commit_message] || "Delete #{path_in_repo}/"
    opts = Keyword.put(opts, :commit_message, message)

    operation = Operation.delete(path_in_repo, is_folder: true)
    create(repo_id, [operation], opts)
  end

  # Private implementation

  defp validate_options(opts) do
    case Keyword.get(opts, :commit_message) do
      nil -> {:error, :missing_commit_message}
      "" -> {:error, :empty_commit_message}
      _ -> :ok
    end
  end

  defp get_token(opts) do
    case opts[:token] || Auth.get_token() do
      nil -> {:error, :no_token}
      token -> {:ok, token}
    end
  end

  defp prepare_operations(operations) do
    # Determine upload mode for each add operation
    prepared = Enum.map(operations, fn
      %Operation.Add{} = op ->
        mode = if needs_lfs?(op), do: :lfs, else: :regular
        %{op | upload_mode: mode}

      other ->
        other
    end)

    {:ok, prepared}
  end

  defp upload_lfs_files(repo_id, operations, token, opts) do
    lfs_ops = Enum.filter(operations, fn
      %Operation.Add{upload_mode: :lfs} -> true
      _ -> false
    end)

    if Enum.empty?(lfs_ops) do
      {:ok, operations}
    else
      LfsUpload.upload_batch(repo_id, lfs_ops, token, opts)
    end
  end

  defp commit_operations(repo_id, operations, token, opts) do
    repo_type = opts[:repo_type] || :model
    revision = opts[:revision] || "main"

    payload = build_commit_payload(operations, opts)
    path = commit_path(repo_id, repo_type, revision)

    HTTP.post(path, payload, token: token)
  end

  defp build_commit_payload(operations, opts) do
    %{
      "operations" => Enum.map(operations, &operation_to_payload/1),
      "summary" => opts[:commit_message],
      "description" => opts[:commit_description],
      "createPr" => opts[:create_pr] || false,
      "parentCommit" => opts[:parent_commit]
    }
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp operation_to_payload(%Operation.Add{upload_mode: :regular} = op) do
    {:ok, content} = Operation.base64_content(op)

    %{
      "key" => op.path_in_repo,
      "value" => %{
        "content" => content,
        "encoding" => "base64"
      }
    }
  end

  defp operation_to_payload(%Operation.Add{upload_mode: :lfs} = op) do
    %{
      "key" => op.path_in_repo,
      "value" => %{
        "lfs" => %{
          "oid" => HfHub.LFS.oid(op.upload_info),
          "size" => op.upload_info.size
        }
      }
    }
  end

  defp operation_to_payload(%Operation.Delete{} = op) do
    %{
      "key" => op.path_in_repo,
      "value" => %{
        "delete" => %{
          "isFolder" => op.is_folder
        }
      }
    }
  end

  defp operation_to_payload(%Operation.Copy{} = op) do
    %{
      "key" => op.dst_path,
      "value" => %{
        "copy" => %{
          "src" => op.src_path,
          "srcRevision" => op.src_revision
        }
        |> Enum.reject(fn {_, v} -> is_nil(v) end)
        |> Map.new()
      }
    }
  end

  defp commit_path(repo_id, repo_type, revision) do
    prefix = repo_type_prefix(repo_type)
    encoded_repo = URI.encode(repo_id, &URI.char_unreserved?/1)
    "/api/#{prefix}/#{encoded_repo}/commit/#{revision}"
  end

  defp repo_type_prefix(:model), do: "models"
  defp repo_type_prefix(:dataset), do: "datasets"
  defp repo_type_prefix(:space), do: "spaces"
end
```

### 2. Create `lib/hf_hub/commit/lfs_upload.ex`

```elixir
defmodule HfHub.Commit.LfsUpload do
  @moduledoc """
  Git LFS upload protocol implementation.

  Handles uploading large files (>= 10MB) using the Git LFS batch API.
  """

  alias HfHub.{HTTP, LFS}
  alias HfHub.Commit.Operation

  @doc """
  Uploads multiple LFS files in batch.
  """
  @spec upload_batch(String.t(), [Operation.Add.t()], String.t(), keyword()) ::
    {:ok, [Operation.Add.t()]} | {:error, term()}
  def upload_batch(repo_id, operations, token, opts \\ []) do
    upload_infos = Enum.map(operations, & &1.upload_info)

    with {:ok, batch_response} <- request_batch_info(repo_id, upload_infos, token, opts),
         :ok <- upload_all(operations, batch_response, token) do
      # Mark all as uploaded
      uploaded = Enum.map(operations, fn op -> %{op | is_uploaded: true} end)
      {:ok, uploaded}
    end
  end

  @doc """
  Requests upload instructions from the LFS batch endpoint.
  """
  @spec request_batch_info(String.t(), [LFS.UploadInfo.t()], String.t(), keyword()) ::
    {:ok, map()} | {:error, term()}
  def request_batch_info(repo_id, upload_infos, token, opts \\ []) do
    repo_type = opts[:repo_type] || :model

    path = lfs_batch_path(repo_id, repo_type)

    body = %{
      "operation" => "upload",
      "transfers" => ["basic", "multipart"],
      "objects" => Enum.map(upload_infos, fn info ->
        %{
          "oid" => LFS.oid(info),
          "size" => info.size
        }
      end),
      "hash_algo" => "sha256"
    }

    headers = LFS.lfs_headers()

    HTTP.post(path, body, token: token, headers: headers)
  end

  defp upload_all(operations, batch_response, token) do
    objects = batch_response["objects"] || []

    # Create a map from OID to operation for quick lookup
    ops_by_oid = Map.new(operations, fn op ->
      {LFS.oid(op.upload_info), op}
    end)

    # Upload each object that has an upload action
    results = Enum.map(objects, fn obj ->
      oid = obj["oid"]
      actions = obj["actions"] || %{}

      case Map.get(actions, "upload") do
        nil ->
          # Already exists, no upload needed
          :ok

        upload_action ->
          op = Map.fetch!(ops_by_oid, oid)
          verify_action = Map.get(actions, "verify")
          upload_single(op, upload_action, verify_action, token)
      end
    end)

    case Enum.find(results, &match?({:error, _}, &1)) do
      nil -> :ok
      error -> error
    end
  end

  defp upload_single(operation, upload_action, verify_action, _token) do
    href = upload_action["href"]
    headers = upload_action["header"] || %{}

    with {:ok, content} <- Operation.get_content(operation),
         :ok <- do_upload(href, content, headers),
         :ok <- maybe_verify(verify_action, operation) do
      :ok
    end
  end

  defp do_upload(href, content, headers) do
    # Check if multipart upload is needed
    case Map.get(headers, "x-amz-meta-upload-chunk-index") do
      nil ->
        # Single part upload
        single_part_upload(href, content, headers)

      _ ->
        # Multipart upload
        multipart_upload(href, content, headers)
    end
  end

  defp single_part_upload(href, content, headers) do
    req_headers = Enum.map(headers, fn {k, v} -> {k, v} end)

    case Req.put(href, body: content, headers: req_headers) do
      {:ok, %{status: status}} when status in [200, 201] ->
        :ok

      {:ok, %{status: status, body: body}} ->
        {:error, {:lfs_upload_failed, status, body}}

      {:error, reason} ->
        {:error, {:lfs_upload_error, reason}}
    end
  end

  defp multipart_upload(href, content, headers) do
    # Parse chunk size and count from headers
    chunk_size = String.to_integer(headers["x-amz-meta-chunk-size"] || "67108864")

    chunks = chunk_content(content, chunk_size)
    part_urls = parse_part_urls(headers)

    # Upload all chunks
    etags = Enum.with_index(chunks, 1)
    |> Enum.map(fn {chunk, part_num} ->
      url = Enum.at(part_urls, part_num - 1)
      upload_part(url, chunk, part_num)
    end)

    case Enum.all?(etags, &match?({:ok, _}, &1)) do
      true ->
        etags = Enum.map(etags, fn {:ok, etag} -> etag end)
        complete_multipart(href, etags)

      false ->
        {:error, :multipart_upload_failed}
    end
  end

  defp chunk_content(content, chunk_size) do
    content
    |> :binary.bin_to_list()
    |> Enum.chunk_every(chunk_size)
    |> Enum.map(&:binary.list_to_bin/1)
  end

  defp parse_part_urls(headers) do
    # Part URLs are in x-amz-meta-part-1-url, x-amz-meta-part-2-url, etc.
    headers
    |> Enum.filter(fn {k, _} -> String.match?(k, ~r/x-amz-meta-part-\d+-url/) end)
    |> Enum.sort_by(fn {k, _} ->
      [_, num] = Regex.run(~r/part-(\d+)-url/, k)
      String.to_integer(num)
    end)
    |> Enum.map(fn {_, v} -> v end)
  end

  defp upload_part(url, chunk, _part_num) do
    case Req.put(url, body: chunk) do
      {:ok, %{status: 200, headers: headers}} ->
        etag = get_header(headers, "etag")
        {:ok, etag}

      {:ok, %{status: status}} ->
        {:error, {:part_upload_failed, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_header(headers, name) do
    Enum.find_value(headers, fn
      {^name, value} -> value
      _ -> nil
    end)
  end

  defp complete_multipart(href, etags) do
    body = %{
      "parts" => Enum.with_index(etags, 1) |> Enum.map(fn {etag, num} ->
        %{"partNumber" => num, "etag" => etag}
      end)
    }

    case Req.post(href, json: body) do
      {:ok, %{status: status}} when status in [200, 201] ->
        :ok

      {:ok, %{status: status, body: body}} ->
        {:error, {:complete_failed, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp maybe_verify(nil, _operation), do: :ok

  defp maybe_verify(verify_action, operation) do
    href = verify_action["href"]
    headers = verify_action["header"] || %{}

    body = %{
      "oid" => LFS.oid(operation.upload_info),
      "size" => operation.upload_info.size
    }

    req_headers = Map.merge(headers, %{"Content-Type" => "application/json"})
    |> Enum.to_list()

    case Req.post(href, json: body, headers: req_headers) do
      {:ok, %{status: status}} when status in [200, 201] ->
        :ok

      {:ok, %{status: status}} ->
        {:error, {:verify_failed, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp lfs_batch_path(repo_id, repo_type) do
    prefix = case repo_type do
      :model -> ""
      :dataset -> "datasets/"
      :space -> "spaces/"
    end

    encoded = URI.encode(repo_id, &URI.char_unreserved?/1)
    "/#{prefix}#{encoded}.git/info/lfs/objects/batch"
  end
end
```

## Test Requirements (TDD)

Create `test/hf_hub/commit_test.exs`:

```elixir
defmodule HfHub.CommitTest do
  use ExUnit.Case, async: true

  alias HfHub.Commit
  alias HfHub.Commit.{Operation, CommitInfo}

  setup do
    bypass = Bypass.open()
    original_endpoint = Application.get_env(:hf_hub, :endpoint)
    Application.put_env(:hf_hub, :endpoint, "http://localhost:#{bypass.port}")

    on_exit(fn ->
      if original_endpoint do
        Application.put_env(:hf_hub, :endpoint, original_endpoint)
      else
        Application.delete_env(:hf_hub, :endpoint)
      end
    end)

    {:ok, bypass: bypass}
  end

  describe "upload_file/4 with regular upload" do
    test "uploads small file successfully", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/models/user/repo/commit/main", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        payload = Jason.decode!(body)

        assert payload["summary"] == "Upload config.json"
        assert [operation] = payload["operations"]
        assert operation["key"] == "config.json"
        assert operation["value"]["encoding"] == "base64"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{
          "commitUrl" => "https://huggingface.co/user/repo/commit/abc123",
          "commitOid" => "abc123",
          "commitMessage" => "Upload config.json",
          "repoUrl" => "https://huggingface.co/user/repo"
        }))
      end)

      {:ok, info} = Commit.upload_file(
        ~s({"key": "value"}),
        "config.json",
        "user/repo",
        token: "hf_test_token"
      )

      assert %CommitInfo{} = info
      assert info.oid == "abc123"
    end

    test "returns error without commit message", %{bypass: _bypass} do
      # commit_message is auto-generated for upload_file, so test create directly
      {:error, :missing_commit_message} = Commit.create(
        "user/repo",
        [Operation.add("file.txt", "content")],
        token: "hf_test"
      )
    end

    test "returns error without token", %{bypass: _bypass} do
      {:error, :no_token} = Commit.upload_file(
        "content",
        "file.txt",
        "user/repo",
        commit_message: "Test"
      )
    end
  end

  describe "delete_file/3" do
    test "deletes file successfully", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/models/user/repo/commit/main", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        payload = Jason.decode!(body)

        assert [operation] = payload["operations"]
        assert operation["key"] == "old_file.bin"
        assert operation["value"]["delete"]["isFolder"] == false

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{
          "commitUrl" => "https://huggingface.co/user/repo/commit/abc123",
          "commitOid" => "abc123",
          "commitMessage" => "Delete old_file.bin",
          "repoUrl" => "https://huggingface.co/user/repo"
        }))
      end)

      {:ok, _info} = Commit.delete_file(
        "old_file.bin",
        "user/repo",
        token: "hf_test"
      )
    end
  end

  describe "delete_folder/3" do
    test "deletes folder successfully", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/models/user/repo/commit/main", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        payload = Jason.decode!(body)

        assert [operation] = payload["operations"]
        assert operation["value"]["delete"]["isFolder"] == true

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{
          "commitUrl" => "url",
          "commitOid" => "abc",
          "commitMessage" => "msg",
          "repoUrl" => "url"
        }))
      end)

      {:ok, _} = Commit.delete_folder("old_dir/", "user/repo", token: "hf_test")
    end
  end

  describe "create/3 with multiple operations" do
    test "commits multiple operations", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/models/user/repo/commit/main", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        payload = Jason.decode!(body)

        assert length(payload["operations"]) == 2

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{
          "commitUrl" => "url",
          "commitOid" => "abc",
          "commitMessage" => "msg",
          "repoUrl" => "url"
        }))
      end)

      {:ok, _} = Commit.create("user/repo", [
        Operation.add("new.txt", "content"),
        Operation.delete("old.txt")
      ], token: "hf_test", commit_message: "Update files")
    end
  end
end
```

Create `test/hf_hub/commit/lfs_upload_test.exs`:

```elixir
defmodule HfHub.Commit.LfsUploadTest do
  use ExUnit.Case, async: true

  alias HfHub.Commit.{LfsUpload, Operation}

  setup do
    bypass = Bypass.open()
    {:ok, bypass: bypass}
  end

  describe "request_batch_info/4" do
    test "requests upload info for objects", %{bypass: bypass} do
      Application.put_env(:hf_hub, :endpoint, "http://localhost:#{bypass.port}")

      Bypass.expect_once(bypass, "POST", "/user/repo.git/info/lfs/objects/batch", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        payload = Jason.decode!(body)

        assert payload["operation"] == "upload"
        assert ["basic", "multipart"] = payload["transfers"]
        assert [%{"oid" => _, "size" => _}] = payload["objects"]

        conn
        |> Plug.Conn.put_resp_content_type("application/vnd.git-lfs+json")
        |> Plug.Conn.resp(200, Jason.encode!(%{
          "transfer" => "basic",
          "objects" => [
            %{
              "oid" => "abc123",
              "size" => 1000,
              "actions" => %{
                "upload" => %{
                  "href" => "https://storage.example.com/upload",
                  "header" => %{}
                }
              }
            }
          ]
        }))
      end)

      upload_info = %HfHub.LFS.UploadInfo{
        sha256: :crypto.hash(:sha256, "test"),
        size: 1000,
        sample: "test"
      }

      {:ok, response} = LfsUpload.request_batch_info(
        "user/repo",
        [upload_info],
        "hf_test_token"
      )

      assert response["transfer"] == "basic"
    end
  end
end
```

## Quality Requirements

After implementation:
1. Run `mix test` - all tests must pass
2. Run `mix format` - code must be formatted
3. Run `mix credo --strict` - no warnings
4. Run `mix dialyzer` - no errors

## Changelog Entry

Update `CHANGELOG.md` under `## [0.1.3] - Unreleased`:

```markdown
### Added
- `HfHub.Commit.create/3` - Create commits with multiple operations
- `HfHub.Commit.upload_file/4` - Upload single file (regular or LFS)
- `HfHub.Commit.delete_file/3` - Delete file from repository
- `HfHub.Commit.delete_folder/3` - Delete folder from repository
- `HfHub.Commit.LfsUpload` - Git LFS batch upload support
```

## README Update

Add to README.md:

```markdown
### File Upload

```elixir
# Upload a small file (< 10MB uses base64, >= 10MB uses LFS automatically)
{:ok, info} = HfHub.Commit.upload_file(
  "/path/to/model.bin",
  "model.bin",
  "my-org/my-model",
  token: token,
  commit_message: "Add model weights"
)

# Upload from binary content
{:ok, info} = HfHub.Commit.upload_file(
  Jason.encode!(%{hidden_size: 768}),
  "config.json",
  "my-model",
  token: token
)

# Delete a file
{:ok, info} = HfHub.Commit.delete_file("old_model.bin", "my-model", token: token)

# Multiple operations in one commit
alias HfHub.Commit.Operation

{:ok, info} = HfHub.Commit.create("my-model", [
  Operation.add("config.json", config_content),
  Operation.add("model.bin", "/path/to/model.bin"),
  Operation.delete("old_config.json")
], token: token, commit_message: "Update model")
```
```

## Completion Checklist

- [ ] `HfHub.Commit.create/3` implemented
- [ ] `HfHub.Commit.upload_file/4` implemented
- [ ] `HfHub.Commit.delete_file/3` implemented
- [ ] `HfHub.Commit.delete_folder/3` implemented
- [ ] `HfHub.Commit.LfsUpload` module created
- [ ] Single-part LFS upload works
- [ ] Multipart LFS upload works
- [ ] LFS verify action handled
- [ ] All tests pass
- [ ] `mix format` passes
- [ ] `mix credo --strict` passes
- [ ] `mix dialyzer` passes
- [ ] CHANGELOG.md updated
- [ ] README.md updated
