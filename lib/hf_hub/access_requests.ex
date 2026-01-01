defmodule HfHub.AccessRequests do
  @moduledoc """
  Access request management for gated repositories.

  This module provides functions to manage user access requests for gated
  models, datasets, and spaces on HuggingFace Hub.

  ## Examples

      # List pending access requests
      {:ok, requests} = HfHub.AccessRequests.list_pending("my-gated-model")

      # Accept a request
      :ok = HfHub.AccessRequests.accept("my-gated-model", "username")

      # Grant access directly (without prior request)
      :ok = HfHub.AccessRequests.grant("my-gated-model", "username")
  """

  alias HfHub.AccessRequests.AccessRequest
  alias HfHub.{Auth, HTTP}

  @type status :: :pending | :accepted | :rejected
  @type repo_type :: :model | :dataset | :space

  @doc """
  Lists pending access requests for a repository.

  ## Options

    * `:token` - Authentication token
    * `:repo_type` - Repository type (default: `:model`)

  ## Examples

      {:ok, requests} = HfHub.AccessRequests.list_pending("my-gated-model")
  """
  @spec list_pending(String.t(), keyword()) ::
          {:ok, [AccessRequest.t()]} | {:error, term()}
  def list_pending(repo_id, opts \\ []) do
    list_by_status(repo_id, :pending, opts)
  end

  @doc """
  Lists accepted access requests for a repository.

  ## Options

    * `:token` - Authentication token
    * `:repo_type` - Repository type (default: `:model`)

  ## Examples

      {:ok, requests} = HfHub.AccessRequests.list_accepted("my-gated-model")
  """
  @spec list_accepted(String.t(), keyword()) ::
          {:ok, [AccessRequest.t()]} | {:error, term()}
  def list_accepted(repo_id, opts \\ []) do
    list_by_status(repo_id, :accepted, opts)
  end

  @doc """
  Lists rejected access requests for a repository.

  ## Options

    * `:token` - Authentication token
    * `:repo_type` - Repository type (default: `:model`)

  ## Examples

      {:ok, requests} = HfHub.AccessRequests.list_rejected("my-gated-model")
  """
  @spec list_rejected(String.t(), keyword()) ::
          {:ok, [AccessRequest.t()]} | {:error, term()}
  def list_rejected(repo_id, opts \\ []) do
    list_by_status(repo_id, :rejected, opts)
  end

  @doc """
  Accepts a pending access request.

  ## Options

    * `:token` - Authentication token (required)
    * `:repo_type` - Repository type (default: `:model`)

  ## Examples

      :ok = HfHub.AccessRequests.accept("my-gated-model", "username")
  """
  @spec accept(String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def accept(repo_id, user, opts \\ []) do
    handle_request(repo_id, user, :accept, opts)
  end

  @doc """
  Rejects a pending access request.

  ## Options

    * `:token` - Authentication token (required)
    * `:repo_type` - Repository type (default: `:model`)

  ## Examples

      :ok = HfHub.AccessRequests.reject("my-gated-model", "username")
  """
  @spec reject(String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def reject(repo_id, user, opts \\ []) do
    handle_request(repo_id, user, :reject, opts)
  end

  @doc """
  Cancels/revokes an access request or grant.

  This removes the user's access completely.

  ## Options

    * `:token` - Authentication token (required)
    * `:repo_type` - Repository type (default: `:model`)

  ## Examples

      :ok = HfHub.AccessRequests.cancel("my-gated-model", "username")
  """
  @spec cancel(String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def cancel(repo_id, user, opts \\ []) do
    token = opts[:token] || get_token_value()
    repo_type = opts[:repo_type] || :model

    path =
      "/api/#{type_prefix(repo_type)}/#{encode(repo_id)}/user-access-request/handle?user=#{encode(user)}"

    HTTP.delete(path, token: token)
  end

  @doc """
  Grants access directly without a prior request.

  Use for proactive access grants to specific users.

  ## Options

    * `:token` - Authentication token (required)
    * `:repo_type` - Repository type (default: `:model`)

  ## Examples

      :ok = HfHub.AccessRequests.grant("my-gated-model", "username")
  """
  @spec grant(String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def grant(repo_id, user, opts \\ []) do
    token = opts[:token] || get_token_value()
    repo_type = opts[:repo_type] || :model

    body = %{"user" => user}
    path = "/api/#{type_prefix(repo_type)}/#{encode(repo_id)}/user-access-request/grant"

    HTTP.post_action(path, body, token: token)
  end

  # Private helpers

  defp list_by_status(repo_id, status, opts) do
    token = opts[:token] || get_token_value()
    repo_type = opts[:repo_type] || :model

    path = "/api/#{type_prefix(repo_type)}/#{encode(repo_id)}/user-access-request/#{status}"

    case HTTP.get(path, token: token) do
      {:ok, requests} when is_list(requests) ->
        {:ok, Enum.map(requests, &AccessRequest.from_response(&1, status))}

      {:ok, %{"accessRequests" => requests}} ->
        {:ok, Enum.map(requests, &AccessRequest.from_response(&1, status))}

      error ->
        error
    end
  end

  defp handle_request(repo_id, user, action, opts) do
    token = opts[:token] || get_token_value()
    repo_type = opts[:repo_type] || :model

    body = %{
      "user" => user,
      "status" => if(action == :accept, do: "accepted", else: "rejected")
    }

    path = "/api/#{type_prefix(repo_type)}/#{encode(repo_id)}/user-access-request/handle"

    HTTP.post_action(path, body, token: token)
  end

  defp type_prefix(:model), do: "models"
  defp type_prefix(:dataset), do: "datasets"
  defp type_prefix(:space), do: "spaces"

  defp encode(s), do: URI.encode(s, &URI.char_unreserved?/1)

  defp get_token_value do
    case Auth.get_token() do
      {:ok, token} -> token
      _ -> nil
    end
  end
end
