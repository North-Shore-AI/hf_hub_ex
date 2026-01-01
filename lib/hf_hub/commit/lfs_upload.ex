defmodule HfHub.Commit.LfsUpload do
  @moduledoc """
  Git LFS upload protocol implementation.

  Handles uploading large files (>= 10MB) using the Git LFS batch API.
  Supports both single-part and multipart uploads based on server response.
  """

  alias HfHub.Commit.Operation
  alias HfHub.{HTTP, LFS}

  @doc """
  Uploads multiple LFS files in batch.

  Requests batch upload info from the server, uploads each file that
  needs uploading, and verifies uploads if required.

  ## Options

  - `:repo_type` - Repository type: :model, :dataset, :space (default: :model)
  - `:max_workers` - Maximum concurrent uploads (default: 4)

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
         :ok <- upload_all_concurrent(operations, batch_response, token, max_workers) do
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
  defp upload_all_concurrent(operations, batch_response, token, max_workers) do
    objects = batch_response["objects"] || []

    # Create a map from OID to operation for quick lookup
    ops_by_oid =
      Map.new(operations, fn op ->
        {LFS.oid(op.upload_info), op}
      end)

    # Upload each object that has an upload action (concurrently)
    results =
      objects
      |> Task.async_stream(
        fn obj ->
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
        end,
        max_concurrency: max_workers,
        # 5 minute timeout per file
        timeout: 300_000
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

  # Uploads a single LFS object
  defp upload_single(operation, upload_action, verify_action, _token) do
    href = upload_action["href"]
    headers = upload_action["header"] || %{}

    with {:ok, content} <- Operation.get_content(operation),
         :ok <- do_upload(href, content, headers) do
      maybe_verify(verify_action, operation)
    end
  end

  # Determines upload type (single or multipart) and uploads
  defp do_upload(href, content, headers) do
    # Check if multipart upload is needed based on headers
    case Map.get(headers, "x-amz-meta-chunk-size") do
      nil ->
        # Single part upload
        single_part_upload(href, content, headers)

      _chunk_size ->
        # Multipart upload
        multipart_upload(href, content, headers)
    end
  end

  # Performs a single-part PUT upload
  defp single_part_upload(href, content, headers) do
    req_headers = headers_to_list(headers)

    case Req.put(href, body: content, headers: req_headers) do
      {:ok, %{status: status}} when status in [200, 201] ->
        :ok

      {:ok, %{status: status, body: body}} ->
        {:error, {:lfs_upload_failed, status, body}}

      {:error, reason} ->
        {:error, {:lfs_upload_error, reason}}
    end
  end

  # Performs a multipart upload (for very large files)
  defp multipart_upload(href, content, headers) do
    # Parse chunk size from headers
    chunk_size = String.to_integer(headers["x-amz-meta-chunk-size"] || "67108864")

    chunks = chunk_content(content, chunk_size)
    part_urls = parse_part_urls(headers)

    # Upload all chunks
    etag_results =
      chunks
      |> Enum.with_index(1)
      |> Enum.map(fn {chunk, part_num} ->
        url = Enum.at(part_urls, part_num - 1)
        upload_part(url, chunk, part_num)
      end)

    case Enum.all?(etag_results, &match?({:ok, _}, &1)) do
      true ->
        etags = Enum.map(etag_results, fn {:ok, etag} -> etag end)
        complete_multipart(href, etags)

      false ->
        {:error, :multipart_upload_failed}
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

  # Parses multipart upload URLs from headers
  defp parse_part_urls(headers) do
    # Part URLs are in x-amz-meta-part-1-url, x-amz-meta-part-2-url, etc.
    headers
    |> Enum.filter(fn {k, _} -> String.match?(k, ~r/x-amz-meta-part-\d+-url/) end)
    |> Enum.sort_by(fn {k, _} ->
      case Regex.run(~r/part-(\d+)-url/, k) do
        [_, num] -> String.to_integer(num)
        _ -> 0
      end
    end)
    |> Enum.map(fn {_, v} -> v end)
  end

  # Uploads a single part and returns the ETag
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

  # Gets a header value from response headers
  # Req returns headers as a list of tuples
  defp get_header(headers, name) do
    headers
    |> Enum.find_value(fn
      {key, value} when is_binary(key) ->
        if String.downcase(key) == name, do: value

      _ ->
        nil
    end)
  end

  # Completes a multipart upload
  defp complete_multipart(href, etags) do
    body = %{
      "parts" =>
        etags
        |> Enum.with_index(1)
        |> Enum.map(fn {etag, num} ->
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

  # Verifies an upload if a verify action was provided
  defp maybe_verify(nil, _operation), do: :ok

  defp maybe_verify(verify_action, operation) do
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

    case Req.post(href, json: body, headers: req_headers) do
      {:ok, %{status: status}} when status in [200, 201] ->
        :ok

      {:ok, %{status: status}} ->
        {:error, {:verify_failed, status}}

      {:error, reason} ->
        {:error, reason}
    end
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

    encoded = URI.encode(repo_id, &URI.char_unreserved?/1)
    "/#{prefix}#{encoded}.git/info/lfs/objects/batch"
  end
end
