defmodule HfHub.Commit.Preupload do
  @moduledoc """
  Hub `preupload` preflight: ask the server how each file should be uploaded
  (regular base64 blob vs. Git-LFS) before sending the commit.

  This is the canonical equivalent of `_fetch_upload_modes` in
  `huggingface_hub/_commit_api.py`. The Hub consults the repo's
  `.gitattributes` (which by default tracks `*.safetensors`, `*.bin`, etc.
  as LFS regardless of size) and tells us, per path, which mode to use.

  Sending an LFS-tracked file as a base64 "regular" blob produces:

      400 Bad Request: "Your push was rejected because it contains binary
      files. Please use ... to store binary files."

  Always call this before building the commit ndjson so we honour the repo's
  declared storage policy instead of a local size threshold.
  """

  alias HfHub.{HTTP, LFS}
  alias HfHub.Path, as: HubPath

  @type repo_type :: :model | :dataset | :space
  @type upload_mode :: :regular | :lfs

  @type addition :: %{
          required(:path_in_repo) => String.t(),
          required(:upload_info) => LFS.UploadInfo.t(),
          optional(any) => any
        }

  @doc """
  Returns `{:ok, %{path_in_repo => :regular | :lfs}}` for each given addition,
  or `{:error, reason}` if the Hub rejects the preflight.

  ## Options

    * `:repo_type` — `:model` (default), `:dataset`, or `:space`.
    * `:revision`  — defaults to `"main"`. Encoded per HF's URL contract.
    * `:create_pr` — when `true`, the request is scoped to a PR branch.
  """
  @spec fetch_upload_modes(String.t(), [addition()], String.t(), keyword()) ::
          {:ok, %{String.t() => upload_mode()}} | {:error, term()}
  def fetch_upload_modes(repo_id, additions, token, opts \\ []) do
    repo_type = opts[:repo_type] || :model
    revision = opts[:revision] || "main"
    create_pr = Keyword.get(opts, :create_pr, false)

    path = preupload_path(repo_id, repo_type, revision)
    params = if create_pr, do: [create_pr: "1"], else: []

    payload = %{"files" => Enum.map(additions, &file_entry/1)}

    with {:ok, response} <- HTTP.post(path, payload, token: token, params: params),
         {:ok, modes} <- parse_modes(response) do
      {:ok, override_empty_files_to_regular(modes, additions)}
    end
  end

  defp file_entry(%{path_in_repo: path, upload_info: %LFS.UploadInfo{} = info}) do
    %{
      "path" => path,
      "sample" => Base.encode64(info.sample || <<>>),
      "size" => info.size
    }
  end

  defp parse_modes(%{"files" => entries}) when is_list(entries) do
    {:ok,
     Map.new(entries, fn %{"path" => p, "uploadMode" => m} ->
       {p, decode_mode(m)}
     end)}
  end

  defp parse_modes(other), do: {:error, {:malformed_preupload_response, other}}

  defp decode_mode("lfs"), do: :lfs
  defp decode_mode("regular"), do: :regular
  # The Hub may in future return new modes (e.g. "xet"). Treat unknown values
  # as `:lfs` rather than `:regular` because `:regular` is the failure mode
  # that produced the original "binary files" rejection.
  defp decode_mode(_other), do: :lfs

  # S3-backed LFS cannot accept zero-byte objects (S3 returns 501 Not
  # Implemented). Force empty additions to `:regular` so users can still
  # commit empty placeholder files. Mirrors the Python implementation.
  defp override_empty_files_to_regular(modes, additions) do
    Enum.reduce(additions, modes, fn
      %{path_in_repo: path, upload_info: %LFS.UploadInfo{size: 0}}, acc ->
        Map.put(acc, path, :regular)

      _, acc ->
        acc
    end)
  end

  defp preupload_path(repo_id, repo_type, revision) do
    "/api/#{type_prefix(repo_type)}/#{HubPath.encode_repo_id(repo_id)}/preupload/#{HubPath.encode_segment(revision)}"
  end

  defp type_prefix(:model), do: "models"
  defp type_prefix(:dataset), do: "datasets"
  defp type_prefix(:space), do: "spaces"
end
