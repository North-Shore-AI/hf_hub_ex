defmodule HfHub.HTTP do
  @moduledoc """
  HTTP client for HuggingFace Hub API.

  Provides low-level HTTP request functionality with authentication,
  rate limiting, and error handling.
  """

  alias HfHub.{Auth, Config}

  @doc """
  Makes a GET request to the HuggingFace Hub API.

  ## Arguments

    * `path` - API path (e.g., "/api/models/bert-base-uncased")
    * `opts` - Request options

  ## Options

    * `:token` - Authentication token
    * `:headers` - Additional headers
    * `:params` - Query parameters

  ## Examples

      {:ok, response} = HfHub.HTTP.get("/api/models/bert-base-uncased")
  """
  @spec get(String.t(), keyword()) :: {:ok, map() | [map()]} | {:error, term()}
  def get(path, opts \\ []) do
    url = build_url(path)
    headers = build_headers(opts)
    params = Keyword.get(opts, :params, [])

    http_opts = Config.http_opts()

    req_opts = [
      headers: headers,
      params: params,
      receive_timeout: http_opts[:receive_timeout],
      decode_json: [keys: :strings]
    ]

    case Req.get(url, req_opts) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %Req.Response{status: 404}} ->
        {:error, :not_found}

      {:ok, %Req.Response{status: 401}} ->
        {:error, :unauthorized}

      {:ok, %Req.Response{status: 403}} ->
        {:error, :forbidden}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Makes a HEAD request to fetch headers without body.

  Used for ETag-based cache validation.

  ## Arguments

    * `url` - Full URL to request
    * `opts` - Request options

  ## Options

    * `:headers` - Request headers
    * `:follow_redirects` - Whether to follow redirects. Defaults to `true`.

  ## Examples

      {:ok, response} = HfHub.HTTP.head("https://huggingface.co/model/file")
  """
  @spec head(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def head(url, opts \\ []) do
    headers = Keyword.get(opts, :headers, [])
    follow_redirects = Keyword.get(opts, :follow_redirects, true)
    http_opts = Config.http_opts()

    req_opts = [
      headers: headers,
      receive_timeout: http_opts[:receive_timeout],
      redirect: follow_redirects
    ]

    case Req.head(url, req_opts) do
      {:ok, %Req.Response{status: status, headers: resp_headers}} ->
        {:ok, %{status: status, headers: resp_headers}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Makes a paginated GET request and collects all pages.

  Pagination follows the `Link` header with `rel="next"`.

  ## Options

    * `:token` - Authentication token
    * `:headers` - Additional headers
    * `:params` - Query parameters
  """
  @spec get_paginated(String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def get_paginated(path, opts \\ []) do
    url = build_url(path)
    headers = build_headers(opts)
    params = Keyword.get(opts, :params, [])

    http_opts = Config.http_opts()

    req_opts = [
      headers: headers,
      params: params,
      receive_timeout: http_opts[:receive_timeout],
      decode_json: [keys: :strings]
    ]

    do_get_paginated(url, req_opts, [])
  end

  @doc """
  Makes a POST request to the HuggingFace Hub API.

  ## Arguments

    * `path` - API path
    * `body` - Request body (will be JSON-encoded)
    * `opts` - Request options

  ## Examples

      {:ok, response} = HfHub.HTTP.post("/api/endpoint", %{data: "value"})
  """
  @spec post(String.t(), map() | nil, keyword()) :: {:ok, term()} | {:error, term()}
  def post(path, body \\ nil, opts \\ []) do
    request(:post, path, body, opts)
  end

  @doc """
  Performs a PUT request with JSON body.
  """
  @spec put(String.t(), map() | nil, keyword()) :: {:ok, term()} | {:error, term()}
  def put(path, body \\ nil, opts \\ []) do
    request(:put, path, body, opts)
  end

  @doc """
  Performs a PATCH request with JSON body.
  """
  @spec patch(String.t(), map() | nil, keyword()) :: {:ok, term()} | {:error, term()}
  def patch(path, body \\ nil, opts \\ []) do
    request(:patch, path, body, opts)
  end

  @doc """
  Performs a DELETE request.

  DELETE requests typically don't have a body but may return data.
  """
  @spec delete(String.t(), keyword()) :: :ok | {:ok, term()} | {:error, term()}
  def delete(path, opts \\ []) do
    request(:delete, path, nil, opts)
  end

  @doc """
  Performs a DELETE request with a JSON body.

  The Hugging Face repo-deletion endpoint follows this shape.
  """
  @spec delete(String.t(), map() | nil, keyword()) :: :ok | {:ok, term()} | {:error, term()}
  def delete(path, body, opts) do
    request(:delete, path, body, opts)
  end

  @doc """
  Performs a POST request expecting no response body.

  Used for actions that return 200/204 with no content.
  """
  @spec post_action(String.t(), map() | nil, keyword()) :: :ok | {:error, term()}
  def post_action(path, body \\ nil, opts \\ []) do
    case post(path, body, opts) do
      {:ok, _body} -> :ok
      other -> other
    end
  end

  @doc """
  Sends a POST request whose body is `application/x-ndjson` text.

  Used by `HfHub.Commit.create/3` to talk to the Hub's commit endpoint, which
  expects a header line followed by one JSON object per operation, each on its
  own line. See:
  https://github.com/huggingface/huggingface_hub/issues/1085#issuecomment-1265208073

  ## Options

  All options accepted by `post/3`, plus:

    * `:params` — query-string parameters, e.g. `[create_pr: "1"]`.
  """
  @spec post_ndjson(String.t(), iodata(), keyword()) :: {:ok, term()} | {:error, term()}
  def post_ndjson(path, body, opts \\ []) do
    raw_request(:post, path, body, "application/x-ndjson", opts)
  end

  @doc """
  Downloads a file from a URL with streaming support.

  ## Arguments

    * `url` - Full URL to download
    * `destination` - Local file path
    * `opts` - Download options

  ## Options

    * `:token` - Authentication token
    * `:resume` - Resume interrupted download. Defaults to `false`.
    * `:progress_callback` - Function called with download progress.
      The callback receives `(bytes_downloaded, total_bytes)` where
      `total_bytes` may be `nil` if the server doesn't provide Content-Length.

  ## Examples

      :ok = HfHub.HTTP.download_file(
        "https://huggingface.co/bert-base-uncased/resolve/main/config.json",
        "/tmp/config.json"
      )

      # With progress tracking
      :ok = HfHub.HTTP.download_file(
        "https://huggingface.co/bert-base-uncased/resolve/main/model.bin",
        "/tmp/model.bin",
        progress_callback: fn downloaded, total ->
          if total, do: IO.puts("\#{round(downloaded / total * 100)}%")
        end
      )
  """
  @spec download_file(String.t(), Path.t(), keyword()) :: :ok | {:error, term()}
  def download_file(url, destination, opts \\ []) do
    headers = build_headers(opts)
    resume = Keyword.get(opts, :resume, false)
    progress_callback = Keyword.get(opts, :progress_callback)

    with :ok <- destination |> Path.dirname() |> File.mkdir_p(),
         {:ok, {headers, output_mode, download_path}} <-
           prepare_download_target(headers, resume, destination) do
      do_download(url, destination, download_path, headers, output_mode, progress_callback)
    end
  end

  defp prepare_download_target(headers, true, destination) do
    incomplete_path = incomplete_path(destination)

    cond do
      File.exists?(incomplete_path) ->
        add_resume_header(headers, incomplete_path, :append)

      File.exists?(destination) ->
        with :ok <- File.cp(destination, incomplete_path) do
          add_resume_header(headers, incomplete_path, :append)
        end

      true ->
        {:ok, {headers, :write, incomplete_path}}
    end
  end

  defp prepare_download_target(headers, false, destination) do
    incomplete_path = incomplete_path(destination)
    File.rm(incomplete_path)
    {:ok, {headers, :write, incomplete_path}}
  end

  defp add_resume_header(headers, path, output_mode) do
    case File.stat(path) do
      {:ok, %File.Stat{size: file_size}} ->
        range_header = {"range", "bytes=#{file_size}-"}
        {:ok, {[range_header | headers], output_mode, path}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec do_download(String.t(), Path.t(), Path.t(), list(), atom(), function() | nil) ::
          :ok | {:error, term()}
  defp do_download(url, destination, download_path, headers, output_mode, progress_callback) do
    http_opts = Config.http_opts()
    file_modes = [:binary, output_mode]

    case File.open(download_path, file_modes) do
      {:ok, file} ->
        result = do_req_download(url, headers, file, http_opts, progress_callback)
        close_result = File.close(file)
        finalize_download(result, close_result, download_path, destination)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp finalize_download(:ok, :ok, download_path, destination) do
    case File.rename(download_path, destination) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp finalize_download(:ok, {:error, reason}, download_path, _destination) do
    File.rm(download_path)
    {:error, reason}
  end

  defp finalize_download({:error, reason}, _close_result, download_path, _destination) do
    File.rm(download_path)
    {:error, reason}
  end

  defp incomplete_path(destination), do: destination <> ".incomplete"

  defp do_req_download(url, headers, file, http_opts, nil) do
    # No progress callback - use simple streaming
    stream = IO.binstream(file, :line)

    case Req.get(url,
           headers: headers,
           into: stream,
           receive_timeout: http_opts[:receive_timeout]
         ) do
      {:ok, %Req.Response{status: status}} when status in [200, 206] ->
        :ok

      {:ok, %Req.Response{status: 404}} ->
        {:error, :not_found}

      {:ok, %Req.Response{status: 401}} ->
        {:error, :unauthorized}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_req_download(url, headers, file, http_opts, progress_callback) do
    # With progress callback - use chunked streaming with tracking
    case Req.get(url,
           headers: headers,
           into: fn {:data, chunk}, {_req, resp} = acc ->
             IO.binwrite(file, chunk)
             acc_state = get_progress_state(resp)
             new_downloaded = acc_state.downloaded + byte_size(chunk)

             # Call progress callback, catching any errors to not break download
             try do
               progress_callback.(new_downloaded, acc_state.total)
             rescue
               _ -> :ok
             catch
               _, _ -> :ok
             end

             # Update state in process dictionary for next chunk
             Process.put(:hf_download_progress, %{
               downloaded: new_downloaded,
               total: acc_state.total
             })

             {:cont, acc}
           end,
           receive_timeout: http_opts[:receive_timeout]
         ) do
      {:ok, %Req.Response{status: status}} when status in [200, 206] ->
        Process.delete(:hf_download_progress)
        :ok

      {:ok, %Req.Response{status: 404}} ->
        Process.delete(:hf_download_progress)
        {:error, :not_found}

      {:ok, %Req.Response{status: 401}} ->
        Process.delete(:hf_download_progress)
        {:error, :unauthorized}

      {:ok, %Req.Response{status: status}} ->
        Process.delete(:hf_download_progress)
        {:error, {:http_error, status}}

      {:error, reason} ->
        Process.delete(:hf_download_progress)
        {:error, reason}
    end
  end

  defp get_progress_state(resp) do
    case Process.get(:hf_download_progress) do
      nil ->
        # First chunk - initialize state with total from Content-Length header
        total = get_content_length(resp)
        state = %{downloaded: 0, total: total}
        Process.put(:hf_download_progress, state)
        state

      state ->
        state
    end
  end

  defp get_content_length(resp) do
    case Enum.find(resp.headers, fn {key, _} ->
           String.downcase(to_string(key)) == "content-length"
         end) do
      {_, [value | _]} -> String.to_integer(value)
      {_, value} when is_binary(value) -> String.to_integer(value)
      _ -> nil
    end
  end

  # Private helpers

  defp request(method, path, body, opts) do
    url = build_url(path)
    headers = build_headers(opts)
    http_opts = Config.http_opts()

    req_opts = [
      json: body,
      headers: headers,
      receive_timeout: http_opts[:receive_timeout],
      decode_json: [keys: :strings]
    ]

    case method do
      :post -> Req.post(url, req_opts)
      :put -> Req.put(url, req_opts)
      :patch -> Req.patch(url, req_opts)
      :delete -> Req.delete(url, req_opts)
    end
    |> handle_response()
  end

  # POST/PUT with a raw (non-JSON-encoded) body and a caller-supplied
  # content-type. Currently only used for `application/x-ndjson` commit
  # payloads, but written generically so future media types can reuse it.
  defp raw_request(method, path, body, content_type, opts) do
    url = build_url(path)
    base_headers = build_headers(opts)
    headers = [{"content-type", content_type} | base_headers]
    http_opts = Config.http_opts()
    params = Keyword.get(opts, :params, [])

    req_opts = [
      body: body,
      headers: headers,
      params: params,
      receive_timeout: http_opts[:receive_timeout],
      decode_json: [keys: :strings]
    ]

    case method do
      :post -> Req.post(url, req_opts)
    end
    |> handle_response()
  end

  defp handle_response({:ok, %Req.Response{status: 204}}), do: :ok

  defp handle_response({:ok, %Req.Response{status: status, body: body}}) when status in 200..299 do
    {:ok, body}
  end

  defp handle_response({:ok, %Req.Response{status: 400, body: body}}) do
    message = map_error_message(body)
    {:error, %HfHub.Errors.BadRequest{message: message, status: 400}}
  end

  defp handle_response({:ok, %Req.Response{status: 401}}) do
    {:error, :unauthorized}
  end

  defp handle_response({:ok, %Req.Response{status: 403}}) do
    {:error, :forbidden}
  end

  defp handle_response({:ok, %Req.Response{status: 404}}) do
    {:error, :not_found}
  end

  defp handle_response({:ok, %Req.Response{status: 409, body: body}}) do
    {:error, {:conflict, body}}
  end

  defp handle_response({:ok, %Req.Response{status: 422, body: body}}) do
    {:error, {:validation, body}}
  end

  defp handle_response({:ok, %Req.Response{status: status, body: body}}) when status >= 500 do
    {:error, {:server_error, status, body}}
  end

  defp handle_response({:ok, %Req.Response{status: status, body: body}}) do
    {:error, {:http_error, status, body}}
  end

  defp handle_response({:error, reason}), do: {:error, reason}

  defp map_error_message(%{"error" => error}) when is_binary(error), do: error
  defp map_error_message(body), do: inspect(body)

  defp build_url(path) do
    endpoint = Config.endpoint()

    if String.starts_with?(path, "http") do
      path
    else
      URI.merge(endpoint, path) |> URI.to_string()
    end
  end

  defp build_headers(opts) do
    base_headers = [
      {"user-agent", "hf_hub_ex/0.1.1"}
    ]

    custom_headers = Keyword.get(opts, :headers, [])

    {:ok, auth_headers} = Auth.auth_headers(token: Keyword.get(opts, :token))

    base_headers ++ auth_headers ++ custom_headers
  end

  defp do_get_paginated(url, req_opts, acc) do
    case Req.get(url, req_opts) do
      {:ok, %Req.Response{status: status, body: body, headers: headers}} when status in 200..299 ->
        handle_paginated_success(body, headers, req_opts, acc)

      {:ok, %Req.Response{status: 404}} ->
        {:error, :not_found}

      {:ok, %Req.Response{status: 401}} ->
        {:error, :unauthorized}

      {:ok, %Req.Response{status: 403}} ->
        {:error, :forbidden}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp handle_paginated_success(body, headers, req_opts, acc) when is_list(body) do
    next_url = resolve_next_url(headers)
    new_acc = acc ++ body

    case next_url do
      nil -> {:ok, new_acc}
      url -> do_get_paginated(url, Keyword.delete(req_opts, :params), new_acc)
    end
  end

  defp handle_paginated_success(_body, _headers, _req_opts, _acc) do
    {:error, :invalid_response}
  end

  defp resolve_next_url(headers) do
    case next_link(headers) do
      nil -> nil
      url when is_binary(url) -> if String.starts_with?(url, "http"), do: url, else: build_url(url)
    end
  end

  defp next_link(headers) do
    headers
    |> Enum.find_value(fn {key, value} ->
      if String.downcase(to_string(key)) == "link" do
        parse_next_link(value)
      end
    end)
  end

  defp parse_next_link(value) when is_binary(value) do
    value
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.find_value(fn part ->
      [url_part | params] = String.split(part, ";")

      rel =
        params
        |> Enum.map(&String.trim/1)
        |> Enum.find_value(&parse_rel_param/1)

      if rel == "next" do
        extract_link_url(url_part)
      end
    end)
  end

  defp parse_next_link(value) when is_list(value) do
    value
    |> Enum.find_value(&parse_next_link/1)
  end

  defp parse_next_link(_), do: nil

  defp parse_rel_param(param) do
    case String.split(param, "=", parts: 2) do
      ["rel", value] ->
        value
        |> String.trim()
        |> String.trim("\"")
        |> String.downcase()

      _ ->
        nil
    end
  end

  defp extract_link_url("<" <> rest) do
    rest
    |> String.trim()
    |> String.trim_trailing(">")
  end

  defp extract_link_url(value), do: String.trim(value)
end
