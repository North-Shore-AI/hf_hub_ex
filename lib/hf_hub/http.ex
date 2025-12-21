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
      {"user-agent", "hf_hub_ex/0.1.0"}
    ]

    custom_headers = Keyword.get(opts, :headers, [])

    {:ok, auth_headers} = Auth.auth_headers(token: Keyword.get(opts, :token))

    base_headers ++ auth_headers ++ custom_headers
  end
end
