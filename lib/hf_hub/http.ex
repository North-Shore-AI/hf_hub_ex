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
  @spec post(String.t(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def post(path, body, opts \\ []) do
    url = build_url(path)
    headers = build_headers(opts)

    http_opts = Config.http_opts()

    req_opts = [
      json: body,
      headers: headers,
      receive_timeout: http_opts[:receive_timeout],
      decode_json: [keys: :strings]
    ]

    case Req.post(url, req_opts) do
      {:ok, %Req.Response{status: status, body: response_body}} when status in 200..299 ->
        {:ok, response_body}

      {:ok, %Req.Response{status: 404}} ->
        {:error, :not_found}

      {:ok, %Req.Response{status: 401}} ->
        {:error, :unauthorized}

      {:ok, %Req.Response{status: status, body: response_body}} ->
        {:error, {:http_error, status, response_body}}

      {:error, reason} ->
        {:error, reason}
    end
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
    * `:progress_callback` - Function called with download progress

  ## Examples

      :ok = HfHub.HTTP.download_file(
        "https://huggingface.co/bert-base-uncased/resolve/main/config.json",
        "/tmp/config.json"
      )
  """
  @spec download_file(String.t(), Path.t(), keyword()) :: :ok | {:error, term()}
  def download_file(url, destination, opts \\ []) do
    headers = build_headers(opts)
    resume = Keyword.get(opts, :resume, false)

    # Ensure parent directory exists
    with :ok <- destination |> Path.dirname() |> File.mkdir_p(),
         {:ok, {headers, output_mode}} <- prepare_resume(headers, resume, destination) do
      do_download(url, destination, headers, output_mode)
    end
  end

  defp prepare_resume(headers, true, destination) do
    case File.stat(destination) do
      {:ok, %File.Stat{size: file_size}} ->
        range_header = {"range", "bytes=#{file_size}-"}
        {:ok, {[range_header | headers], :append}}

      {:error, :enoent} ->
        {:ok, {headers, :write}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp prepare_resume(headers, false, _destination) do
    {:ok, {headers, :write}}
  end

  @spec do_download(String.t(), Path.t(), list(), atom()) :: :ok | {:error, term()}
  defp do_download(url, destination, headers, output_mode) do
    http_opts = Config.http_opts()
    file_modes = [:binary, output_mode]

    with {:ok, file} <- File.open(destination, file_modes),
         result <- do_req_download(url, headers, file, http_opts),
         :ok <- File.close(file) do
      result
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp do_req_download(url, headers, file, http_opts) do
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

  # Private helpers

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
