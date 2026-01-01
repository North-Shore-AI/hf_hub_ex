defmodule HfHub.Git do
  @moduledoc """
  Git operations for HuggingFace Hub repositories.

  Provides branch, tag, and commit management.

  ## Examples

      # Create a branch
      {:ok, info} = HfHub.Git.create_branch("my-org/my-model", "feature-branch")

      # Create a tag with a message
      {:ok, info} = HfHub.Git.create_tag("my-model", "v1.0", message: "Release v1.0")

      # List all refs
      {:ok, refs} = HfHub.Git.list_refs("bert-base-uncased")

      # List commits
      {:ok, commits} = HfHub.Git.list_commits("bert-base-uncased")

      # Super squash (destructive)
      :ok = HfHub.Git.super_squash("my-model", message: "Squashed history")
  """

  alias HfHub.{Auth, HTTP}
  alias HfHub.Git.{BranchInfo, CommitInfo, GitRefs, TagInfo}

  @type repo_type :: :model | :dataset | :space

  # Branch operations

  @doc """
  Creates a new branch in a repository.

  ## Options

    * `:token` - Authentication token
    * `:repo_type` - Repository type (:model, :dataset, :space). Defaults to :model.
    * `:revision` - Source revision to branch from. Defaults to "main".
    * `:exist_ok` - Don't error if branch exists. Defaults to false.

  ## Examples

      {:ok, info} = HfHub.Git.create_branch("my-model", "feature-branch")
      {:ok, info} = HfHub.Git.create_branch("my-model", "hotfix", revision: "v1.0")
      {:ok, info} = HfHub.Git.create_branch("my-model", "dev", exist_ok: true)
  """
  @spec create_branch(String.t(), String.t(), keyword()) ::
          {:ok, BranchInfo.t()} | {:error, term()}
  def create_branch(repo_id, branch, opts \\ []) do
    token = opts[:token] || Auth.get_token()
    repo_type = opts[:repo_type] || :model
    revision = opts[:revision] || "main"
    exist_ok = Keyword.get(opts, :exist_ok, false)

    body = %{"startingPoint" => revision}
    path = branch_path(repo_id, repo_type, branch)

    case HTTP.post(path, body, token: token) do
      {:ok, response} ->
        {:ok, BranchInfo.from_response(response)}

      {:error, {:conflict, _}} when exist_ok ->
        {:ok, %BranchInfo{name: branch}}

      error ->
        error
    end
  end

  @doc """
  Deletes a branch from a repository.

  ## Options

    * `:token` - Authentication token
    * `:repo_type` - Repository type. Defaults to :model.

  ## Examples

      :ok = HfHub.Git.delete_branch("my-model", "old-branch")
  """
  @spec delete_branch(String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def delete_branch(repo_id, branch, opts \\ []) do
    token = opts[:token] || Auth.get_token()
    repo_type = opts[:repo_type] || :model

    path = branch_path(repo_id, repo_type, branch)

    case HTTP.delete(path, token: token) do
      :ok -> :ok
      {:ok, _} -> :ok
      error -> error
    end
  end

  # Tag operations

  @doc """
  Creates a new tag in a repository.

  ## Options

    * `:token` - Authentication token
    * `:repo_type` - Repository type. Defaults to :model.
    * `:revision` - Revision to tag. Defaults to "main".
    * `:message` - Optional tag message (creates annotated tag).
    * `:exist_ok` - Don't error if tag exists. Defaults to false.

  ## Examples

      {:ok, info} = HfHub.Git.create_tag("my-model", "v1.0")
      {:ok, info} = HfHub.Git.create_tag("my-model", "v2.0",
        revision: "abc123", message: "Release v2.0")
  """
  @spec create_tag(String.t(), String.t(), keyword()) ::
          {:ok, TagInfo.t()} | {:error, term()}
  def create_tag(repo_id, tag, opts \\ []) do
    token = opts[:token] || Auth.get_token()
    repo_type = opts[:repo_type] || :model
    revision = opts[:revision] || "main"
    exist_ok = Keyword.get(opts, :exist_ok, false)

    body =
      %{"ref" => "refs/heads/#{revision}"}
      |> maybe_add_message(opts[:message])

    path = tag_path(repo_id, repo_type, tag)

    case HTTP.post(path, body, token: token) do
      {:ok, response} ->
        {:ok, TagInfo.from_response(response)}

      {:error, {:conflict, _}} when exist_ok ->
        {:ok, %TagInfo{name: tag}}

      error ->
        error
    end
  end

  @doc """
  Deletes a tag from a repository.

  ## Options

    * `:token` - Authentication token
    * `:repo_type` - Repository type. Defaults to :model.

  ## Examples

      :ok = HfHub.Git.delete_tag("my-model", "old-tag")
  """
  @spec delete_tag(String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def delete_tag(repo_id, tag, opts \\ []) do
    token = opts[:token] || Auth.get_token()
    repo_type = opts[:repo_type] || :model

    path = tag_path(repo_id, repo_type, tag)

    case HTTP.delete(path, token: token) do
      :ok -> :ok
      {:ok, _} -> :ok
      error -> error
    end
  end

  # Ref listing

  @doc """
  Lists all refs (branches, tags) in a repository.

  ## Options

    * `:token` - Authentication token
    * `:repo_type` - Repository type. Defaults to :model.
    * `:include_pull_requests` - Include PR refs. Defaults to false.

  ## Examples

      {:ok, refs} = HfHub.Git.list_refs("bert-base-uncased")
      refs.branches  # [%BranchInfo{name: "main", ...}]
      refs.tags      # [%TagInfo{name: "v1.0", ...}]
  """
  @spec list_refs(String.t(), keyword()) :: {:ok, GitRefs.t()} | {:error, term()}
  def list_refs(repo_id, opts \\ []) do
    token = opts[:token]
    repo_type = opts[:repo_type] || :model
    include_prs = Keyword.get(opts, :include_pull_requests, false)

    path = refs_path(repo_id, repo_type)
    params = if include_prs, do: [include_pull_requests: "true"], else: []

    case HTTP.get(path, token: token, params: params) do
      {:ok, response} -> {:ok, GitRefs.from_response(response)}
      error -> error
    end
  end

  # Commit history

  @doc """
  Lists commits in a repository.

  ## Options

    * `:token` - Authentication token
    * `:repo_type` - Repository type. Defaults to :model.
    * `:revision` - Branch/tag/commit to list from. Defaults to "main".

  ## Examples

      {:ok, commits} = HfHub.Git.list_commits("bert-base-uncased")
      Enum.take(commits, 10)  # First 10 commits
  """
  @spec list_commits(String.t(), keyword()) ::
          {:ok, [CommitInfo.t()]} | {:error, term()}
  def list_commits(repo_id, opts \\ []) do
    token = opts[:token]
    repo_type = opts[:repo_type] || :model
    revision = opts[:revision] || "main"

    path = commits_path(repo_id, repo_type, revision)

    case HTTP.get(path, token: token) do
      {:ok, commits} when is_list(commits) ->
        {:ok, Enum.map(commits, &CommitInfo.from_response/1)}

      {:ok, %{"commits" => commits}} when is_list(commits) ->
        {:ok, Enum.map(commits, &CommitInfo.from_response/1)}

      {:ok, _} ->
        {:ok, []}

      error ->
        error
    end
  end

  # Super squash (destructive)

  @doc """
  Squashes all commits into a single commit.

  WARNING: This is a destructive operation. Use with caution.

  ## Options

    * `:token` - Authentication token (required)
    * `:repo_type` - Repository type. Defaults to :model.
    * `:branch` - Branch to squash. Defaults to "main".
    * `:message` - Commit message for squashed commit.

  ## Examples

      :ok = HfHub.Git.super_squash("my-model", message: "Squashed history")
  """
  @spec super_squash(String.t(), keyword()) :: :ok | {:error, term()}
  def super_squash(repo_id, opts \\ []) do
    token = opts[:token] || Auth.get_token()
    repo_type = opts[:repo_type] || :model

    body =
      %{"branch" => opts[:branch] || "main"}
      |> maybe_add_message(opts[:message])

    path = squash_path(repo_id, repo_type)
    HTTP.post_action(path, body, token: token)
  end

  # Path helpers

  defp branch_path(repo_id, repo_type, branch) do
    "/api/#{type_prefix(repo_type)}/#{encode(repo_id)}/branch/#{encode(branch)}"
  end

  defp tag_path(repo_id, repo_type, tag) do
    "/api/#{type_prefix(repo_type)}/#{encode(repo_id)}/tag/#{encode(tag)}"
  end

  defp refs_path(repo_id, repo_type) do
    "/api/#{type_prefix(repo_type)}/#{encode(repo_id)}/refs"
  end

  defp commits_path(repo_id, repo_type, revision) do
    "/api/#{type_prefix(repo_type)}/#{encode(repo_id)}/commits/#{encode(revision)}"
  end

  defp squash_path(repo_id, repo_type) do
    "/api/#{type_prefix(repo_type)}/#{encode(repo_id)}/super-squash"
  end

  defp type_prefix(:model), do: "models"
  defp type_prefix(:dataset), do: "datasets"
  defp type_prefix(:space), do: "spaces"

  defp encode(s), do: URI.encode(s, &URI.char_unreserved?/1)

  defp maybe_add_message(body, nil), do: body
  defp maybe_add_message(body, message), do: Map.put(body, "message", message)
end
