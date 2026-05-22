defmodule HfHub.Commit.LfsUpload do
  @moduledoc """
  Git LFS upload protocol implementation.

  Handles uploading large files (>= 10MB) using the Git LFS batch API.
  Supports both single-part and multipart uploads based on server response.
  """

  alias HfHub.Commit.Operation
  alias HfHub.{Config, HTTP, LFS}
  alias HfHub.Path, as: HubPath

  @default_lfs_upload_timeout 30 * 60 * 1000

  @doc """
  Uploads multiple LFS files in batch.

  Requests batch upload info from the server, uploads each file that
  needs uploading, and verifies uploads if required.

  ## Options

  - `:repo_type` - Repository type: :model, :dataset, :space (default: :model)
  - `:max_workers` - Maximum concurrent uploads (default: 4)
  - `:lfs_upload_timeout` - Socket receive timeout for direct LFS PUT/POST
    requests in milliseconds (default: 30 minutes)
  - `:lfs_task_timeout` - Task timeout per LFS object in milliseconds
    (default: `:lfs_upload_timeout + 60_000`)

  ## Returns

  Returns `{:ok, operations}` where operations have `is_uploaded: true`,
  or `{:error, reason}` on failure.
  """
  @spec upload_batch(String.t(), [Operation.Add.t()], String.t(), keyword()) ::
          {:ok, [Operation.Add.t()]} | {:error, term()}
  def upload_batch(repo_id, operations, token, opts \\ []) do
    upload_infos = Enum.map(operations, & &1.upload_info)
    max_workers = opts[:max_workers] || 4

    with {:ok, batch_response} <- request_batch_info(repo_id, upload_infos, token, opts),
         :ok <- upload_all_concurrent(operations, batch_response, token, max_workers, opts) do
      # Mark all as uploaded
      uploaded = Enum.map(operations, fn op -> %{op | is_uploaded: true} end)
      {:ok, uploaded}
    end
  end

  @doc """
  Requests upload instructions from the LFS batch endpoint.

  Sends file info (OID and size) to the server and receives
  upload URLs and headers for each file.
  """
  @spec request_batch_info(String.t(), [LFS.UploadInfo.t()], String.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def request_batch_info(repo_id, upload_infos, token, opts \\ []) do
    repo_type = opts[:repo_type] || :model

    path = lfs_batch_path(repo_id, repo_type)

    body = %{
      "operation" => "upload",
      "transfers" => ["basic", "multipart"],
      "objects" =>
        Enum.map(upload_infos, fn info ->
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

  # Uploads all objects concurrently with configurable max workers
  defp upload_all_concurrent(operations, batch_response, token, max_workers, opts) do
    objects = batch_response["objects"] || []

    # Create a map from OID to operation for quick lookup
    ops_by_oid =
      Map.new(operations, fn op ->
        {LFS.oid(op.upload_info), op}
      end)

    # Upload each object that has an upload action (concurrently).
    #
    # The worker function is wrapped in `try/rescue/catch` so a malformed
    # server response (e.g. non-integer `chunk_size`) becomes an
    # `{:error, {:malformed_response, ...}}` tuple instead of a linked EXIT
    # that would crash the caller process. Genuine task timeouts and other
    # `:exit` payloads still surface as `{:error, {:upload_crashed, ...}}`.
    results =
      objects
      |> Task.async_stream(
        fn obj ->
          run_one_upload(obj, ops_by_oid, token, opts)
        end,
        max_concurrency: max_workers,
        timeout: lfs_task_timeout(opts)
      )
      |> Enum.map(fn
        {:ok, result} -> result
        {:exit, reason} -> {:error, {:upload_crashed, reason}}
      end)

    case Enum.find(results, &match?({:error, _}, &1)) do
      nil -> :ok
      error -> error
    end
  end

  # Drains one batch object into a tagged result, never raising.
  defp run_one_upload(obj, ops_by_oid, token, opts) do
    oid = obj["oid"]
    actions = obj["actions"] || %{}

    case Map.get(actions, "upload") do
      nil ->
        :ok

      upload_action ->
        op = Map.fetch!(ops_by_oid, oid)
        verify_action = Map.get(actions, "verify")

        try do
          upload_single(op, upload_action, verify_action, token, opts)
        rescue
          e in ArgumentError ->
            {:error, {:malformed_response, Exception.message(e)}}

          e ->
            {:error, {:upload_exception, Exception.message(e), __STACKTRACE__}}
        catch
          kind, reason ->
            {:error, {:upload_exception, {kind, reason}, __STACKTRACE__}}
        end
    end
  end

  # Uploads a single LFS object
  defp upload_single(operation, upload_action, verify_action, _token, opts) do
    href = upload_action["href"]
    headers = upload_action["header"] || %{}
    oid = LFS.oid(operation.upload_info)

    with {:ok, content} <- Operation.get_content(operation),
         :ok <- do_upload(href, content, headers, oid, opts) do
      maybe_verify(verify_action, operation, opts)
    end
  end

  # Determines upload type (single or multipart) and uploads.
  #
  # The HF LFS batch API returns multipart instructions in the `header` map
  # of the `upload` action with a `chunk_size` key alongside numeric (string)
  # part-number keys mapping to S3 presigned URLs. See the canonical Python
  # implementation: https://github.com/huggingface/huggingface_hub/blob/main/src/huggingface_hub/lfs.py
  defp do_upload(href, content, headers, oid, opts) do
    case fetch_chunk_size(headers) do
      nil ->
        single_part_upload(href, content, headers, opts)

      chunk_size when is_integer(chunk_size) and chunk_size > 0 ->
        multipart_upload(href, content, headers, chunk_size, oid, opts)
    end
  end

  # Looks up the HF multipart `chunk_size` header in a case-insensitive way
  # and parses it into a positive integer. Returns `nil` when absent, raises
  # `ArgumentError` when present-but-malformed (mirrors the upstream Python
  # behavior of failing loudly rather than silently falling back).
  defp fetch_chunk_size(headers) when is_map(headers) do
    headers
    |> Enum.find_value(fn
      {k, v} when is_binary(k) ->
        if String.downcase(k) == "chunk_size", do: v

      _ ->
        nil
    end)
    |> case do
      nil ->
        nil

      v when is_integer(v) and v > 0 ->
        v

      v when is_binary(v) ->
        case Integer.parse(v) do
          {n, ""} when n > 0 ->
            n

          _ ->
            raise ArgumentError,
                  "Malformed response from LFS batch endpoint: " <>
                    "`chunk_size` should be a positive integer, got #{inspect(v)}"
        end

      other ->
        raise ArgumentError,
              "Malformed response from LFS batch endpoint: " <>
                "`chunk_size` should be a positive integer, got #{inspect(other)}"
    end
  end

  # Performs a single-part PUT upload
  defp single_part_upload(href, content, headers, opts) do
    req_headers = headers_to_list(headers)

    case Req.put(href,
           body: content,
           headers: req_headers,
           receive_timeout: lfs_upload_timeout(opts),
           pool_timeout: lfs_pool_timeout(opts)
         ) do
      {:ok, %{status: status}} when status in [200, 201] ->
        :ok

      {:ok, %{status: status, body: body}} ->
        {:error, {:lfs_upload_failed, status, body}}

      {:error, reason} ->
        {:error, {:lfs_upload_error, reason}}
    end
  end

  # Performs a multipart upload using the HF LFS protocol.
  #
  # The server-provided `headers` map contains:
  #   - "chunk_size" – decimal byte-size for every part (last part may be smaller)
  #   - "00001", "00002", ... – S3 presigned PUT URLs (string digit keys)
  #
  # `href` is the *completion* endpoint on the Hub (POST), not an S3 URL.
  defp multipart_upload(href, content, headers, chunk_size, oid, opts) do
    chunks = chunk_content(content, chunk_size)
    part_urls = parse_part_urls(headers)

    cond do
      part_urls == [] ->
        {:error, {:multipart_upload_failed, :no_part_urls}}

      length(chunks) != length(part_urls) ->
        {:error,
         {:multipart_upload_failed,
          {:part_count_mismatch, expected: length(chunks), got: length(part_urls)}}}

      true ->
        do_multipart(href, chunks, part_urls, oid, opts)
    end
  end

  defp do_multipart(href, chunks, part_urls, oid, opts) do
    etag_results =
      chunks
      |> Enum.zip(part_urls)
      |> Enum.with_index(1)
      |> Enum.map(fn {{chunk, url}, part_num} ->
        upload_part(url, chunk, part_num, opts)
      end)

    case Enum.split_with(etag_results, &match?({:ok, _}, &1)) do
      {oks, []} ->
        etags = Enum.map(oks, fn {:ok, etag} -> etag end)
        complete_multipart(href, etags, oid, opts)

      {_, [first_error | _]} ->
        {:error, {:multipart_upload_failed, first_error}}
    end
  end

  # Splits content into chunks
  defp chunk_content(content, chunk_size) do
    do_chunk(content, chunk_size, [])
  end

  defp do_chunk(<<>>, _chunk_size, acc), do: Enum.reverse(acc)

  defp do_chunk(content, chunk_size, acc) when byte_size(content) <= chunk_size do
    Enum.reverse([content | acc])
  end

  defp do_chunk(content, chunk_size, acc) do
    <<chunk::binary-size(chunk_size), rest::binary>> = content
    do_chunk(rest, chunk_size, [chunk | acc])
  end

  # Parses multipart upload URLs from the LFS action header.
  #
  # HF's response uses pure decimal string keys ("1", "2", ... or zero-padded
  # like "00001") that map to S3 presigned PUT URLs. See:
  # https://github.com/huggingface/huggingface_hub/blob/main/src/huggingface_hub/lfs.py
  defp parse_part_urls(headers) when is_map(headers) do
    headers
    |> Enum.flat_map(fn
      {k, v} when is_binary(k) and is_binary(v) ->
        case Integer.parse(k) do
          {n, ""} when n >= 1 -> [{n, v}]
          _ -> []
        end

      _ ->
        []
    end)
    |> Enum.sort_by(fn {n, _} -> n end)
    |> Enum.map(fn {_, url} -> url end)
  end

  # Uploads a single part and returns the ETag
  defp upload_part(url, chunk, _part_num, opts) do
    case Req.put(url,
           body: chunk,
           receive_timeout: lfs_upload_timeout(opts),
           pool_timeout: lfs_pool_timeout(opts)
         ) do
      {:ok, %{status: 200, headers: headers}} ->
        etag = get_header(headers, "etag")
        {:ok, etag}

      {:ok, %{status: status}} ->
        {:error, {:part_upload_failed, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Gets a header value from a `Req` response.
  #
  # `Req` >= 0.4 normalizes response headers into a `%{name => [value, ...]}`
  # map with downcased names. The fast path is a direct `Map.get/2`. The
  # case-insensitive fall-back exists so an out-of-spec Req upgrade that ever
  # ships a casing variant for a single header doesn't silently break the
  # multipart etag round-trip.
  defp get_header(headers, name) when is_map(headers) do
    case Map.get(headers, name) do
      [value | _] when is_binary(value) -> value
      value when is_binary(value) -> value
      _ -> Enum.find_value(headers, &match_header(&1, name))
    end
  end

  # Returns the value if the map entry matches `name` case-insensitively.
  defp match_header({key, [value | _]}, name)
       when is_binary(key) and is_binary(value),
       do: header_value(key, value, name)

  defp match_header({key, value}, name)
       when is_binary(key) and is_binary(value),
       do: header_value(key, value, name)

  defp match_header(_, _), do: nil

  defp header_value(key, value, name) do
    if String.downcase(key) == name, do: value
  end

  # Completes a multipart upload against the Hub's completion endpoint.
  #
  # Payload shape must match `_get_completion_payload` in huggingface_hub's
  # `lfs.py`: `{"oid": <sha256 hex>, "parts": [%{"partNumber": n, "etag": ...}]}`.
  # The required LFS content-type/accept headers come from `HfHub.LFS.lfs_headers/0`.
  defp complete_multipart(href, etags, oid, opts) do
    body = %{
      "oid" => oid,
      "parts" =>
        etags
        |> Enum.with_index(1)
        |> Enum.map(fn {etag, num} ->
          %{"partNumber" => num, "etag" => etag}
        end)
    }

    case Req.post(href,
           json: body,
           headers: LFS.lfs_headers(),
           receive_timeout: lfs_upload_timeout(opts),
           pool_timeout: lfs_pool_timeout(opts)
         ) do
      {:ok, %{status: status}} when status in [200, 201] ->
        :ok

      {:ok, %{status: status, body: resp_body}} ->
        {:error, {:complete_failed, status, resp_body}}

      {:error, reason} ->
        {:error, {:lfs_upload_error, reason}}
    end
  end

  # Verifies an upload if a verify action was provided
  defp maybe_verify(nil, _operation, _opts), do: :ok

  defp maybe_verify(verify_action, operation, opts) do
    href = verify_action["href"]
    headers = verify_action["header"] || %{}

    body = %{
      "oid" => LFS.oid(operation.upload_info),
      "size" => operation.upload_info.size
    }

    req_headers =
      headers
      |> Map.put("Content-Type", "application/json")
      |> headers_to_list()

    case Req.post(href,
           json: body,
           headers: req_headers,
           receive_timeout: lfs_upload_timeout(opts),
           pool_timeout: lfs_pool_timeout(opts)
         ) do
      {:ok, %{status: status}} when status in [200, 201] ->
        :ok

      {:ok, %{status: status}} ->
        {:error, {:verify_failed, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp lfs_upload_timeout(opts) do
    Keyword.get(opts, :lfs_upload_timeout, @default_lfs_upload_timeout)
  end

  defp lfs_task_timeout(opts) do
    Keyword.get(opts, :lfs_task_timeout, lfs_upload_timeout(opts) + 60_000)
  end

  defp lfs_pool_timeout(opts) do
    Keyword.get(opts, :pool_timeout, Config.http_opts()[:pool_timeout] || 5_000)
  end

  # Converts headers map to list format for Req
  defp headers_to_list(headers) when is_map(headers) do
    Enum.map(headers, fn {k, v} -> {k, v} end)
  end

  # Builds the LFS batch API path
  defp lfs_batch_path(repo_id, repo_type) do
    prefix =
      case repo_type do
        :model -> ""
        :dataset -> "datasets/"
        :space -> "spaces/"
      end

    "/#{prefix}#{HubPath.encode_repo_id(repo_id)}.git/info/lfs/objects/batch"
  end
end
