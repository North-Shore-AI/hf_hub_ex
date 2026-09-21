defmodule HfHub.Revision do
  @moduledoc """
  Resolves mutable HuggingFace Hub revisions to immutable commit hashes.

  Hub branches and tags are convenient inputs but are not stable artifact
  identities. `resolve/2` converts a requested revision such as `"main"` or a
  tag into the full commit hash returned by the Hub and records that mapping in
  the local cache under `refs/`.

  Full 40-character commit hashes are already immutable and are returned
  without a network request.

  For reproducible artifact workflows, resolve once and pass `resolved` to all
  subsequent file downloads:

      {:ok, revision} =
        HfHub.Revision.resolve("org/model", revision: "main")

      {:ok, path} =
        HfHub.Download.hf_hub_download(
          repo_id: "org/model",
          filename: "model.safetensors",
          revision: revision.resolved
        )

  When `:local_files_only` is true, or `HfHub.offline_mode?/0` is enabled,
  mutable revisions are resolved only through a previously cached `refs/`
  entry.
  """

  alias HfHub.{Api, FS}

  @commit_hash ~r/\A[0-9a-f]{40}\z/i
  @repo_types [:model, :dataset, :space]

  @enforce_keys [:repo_id, :repo_type, :requested, :resolved]
  defstruct [:repo_id, :repo_type, :requested, :resolved]

  @type t :: %__MODULE__{
          repo_id: HfHub.repo_id(),
          repo_type: HfHub.repo_type(),
          requested: HfHub.revision(),
          resolved: HfHub.revision()
        }

  @doc """
  Resolves a branch, tag, or commit revision to a full immutable commit hash.

  ## Options

    * `:revision` - Requested revision. Defaults to `"main"`.
    * `:repo_type` - `:model`, `:dataset`, or `:space`. Defaults to `:model`.
    * `:token` - Authentication token forwarded to the Hub metadata API.
    * `:local_files_only` - Resolve mutable revisions only from the local
      `refs/` cache. Defaults to `false`; offline mode always implies local-only.
  """
  @spec resolve(HfHub.repo_id(), keyword()) :: {:ok, t()} | {:error, term()}
  def resolve(repo_id, opts \\ [])

  def resolve(repo_id, opts) when is_binary(repo_id) and is_list(opts) do
    requested = Keyword.get(opts, :revision, "main")
    repo_type = Keyword.get(opts, :repo_type, :model)
    local_files_only = HfHub.offline_mode?() or Keyword.get(opts, :local_files_only, false)

    with :ok <- validate_repo_id(repo_id),
         :ok <- validate_repo_type(repo_type),
         :ok <- validate_revision(requested) do
      cond do
        commit_hash?(requested) ->
          {:ok, resolution(repo_id, repo_type, requested, String.downcase(requested))}

        local_files_only ->
          resolve_cached(repo_id, repo_type, requested)

        true ->
          resolve_remote(repo_id, repo_type, requested, Keyword.get(opts, :token))
      end
    end
  end

  def resolve(_repo_id, _opts), do: {:error, :invalid_revision_arguments}

  @doc "Returns whether a revision is a full 40-character hexadecimal commit hash."
  @spec commit_hash?(term()) :: boolean()
  def commit_hash?(revision) when is_binary(revision), do: Regex.match?(@commit_hash, revision)
  def commit_hash?(_revision), do: false

  defp resolve_cached(repo_id, repo_type, requested) do
    case FS.read_ref(repo_id, repo_type, requested) do
      {:ok, resolved} ->
        with {:ok, resolved} <- normalize_resolved(resolved) do
          {:ok, resolution(repo_id, repo_type, requested, resolved)}
        end

      {:error, :enoent} ->
        {:error, {:revision_not_cached, requested}}

      {:error, reason} ->
        {:error, {:revision_cache_error, reason}}
    end
  end

  defp resolve_remote(repo_id, repo_type, requested, token) do
    with {:ok, info} <- repo_info(repo_id, repo_type, requested, token),
         {:ok, resolved} <- normalize_resolved(Map.get(info, :sha)),
         :ok <- FS.write_ref(repo_id, repo_type, requested, resolved) do
      {:ok, resolution(repo_id, repo_type, requested, resolved)}
    end
  end

  defp repo_info(repo_id, :model, revision, token),
    do: Api.model_info(repo_id, revision: revision, token: token)

  defp repo_info(repo_id, :dataset, revision, token),
    do: Api.dataset_info(repo_id, revision: revision, token: token)

  defp repo_info(repo_id, :space, revision, token),
    do: Api.space_info(repo_id, revision: revision, token: token)

  defp normalize_resolved(value) when is_binary(value) do
    value = String.trim(value)

    if commit_hash?(value) do
      {:ok, String.downcase(value)}
    else
      {:error, {:invalid_resolved_revision, value}}
    end
  end

  defp normalize_resolved(value), do: {:error, {:invalid_resolved_revision, value}}

  defp resolution(repo_id, repo_type, requested, resolved) do
    %__MODULE__{
      repo_id: repo_id,
      repo_type: repo_type,
      requested: requested,
      resolved: resolved
    }
  end

  defp validate_repo_id(repo_id) do
    if String.trim(repo_id) == "", do: {:error, :invalid_repo_id}, else: :ok
  end

  defp validate_repo_type(repo_type) do
    if repo_type in @repo_types, do: :ok, else: {:error, {:invalid_repo_type, repo_type}}
  end

  defp validate_revision(revision) when is_binary(revision) do
    if String.trim(revision) == "", do: {:error, :invalid_revision}, else: :ok
  end

  defp validate_revision(_revision), do: {:error, :invalid_revision}
end
