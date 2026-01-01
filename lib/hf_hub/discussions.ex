defmodule HfHub.Discussions do
  @moduledoc """
  Discussions and Pull Requests API for HuggingFace Hub.

  This module provides functions to interact with discussions and pull requests
  on HuggingFace Hub repositories.

  ## Examples

      # List discussions for a model
      {:ok, discussions} = HfHub.Discussions.list("bert-base-uncased")

      # Get details for a specific discussion
      {:ok, details} = HfHub.Discussions.get("my-model", 42)

      # Create a new discussion
      {:ok, disc} = HfHub.Discussions.create("my-model", "Feature request",
        description: "Please add support for...", token: "hf_xxx")

      # Add a comment
      {:ok, comment} = HfHub.Discussions.comment("my-model", 42, "Thanks!")
  """

  alias HfHub.{Auth, HTTP}
  alias HfHub.Discussions.{Comment, Discussion, DiscussionDetails}

  @type status :: :open | :closed | :merged | :draft | :all
  @type repo_type :: :model | :dataset | :space

  @doc """
  Lists discussions for a repository.

  ## Options

    * `:token` - Authentication token
    * `:repo_type` - Repository type (default: `:model`)
    * `:author` - Filter by author username
    * `:status` - Filter by status (`:open`, `:closed`, `:merged`, `:draft`, `:all`)

  ## Examples

      {:ok, discussions} = HfHub.Discussions.list("bert-base-uncased")
      {:ok, open} = HfHub.Discussions.list("my-model", status: :open)
  """
  @spec list(String.t(), keyword()) ::
          {:ok, [Discussion.t()]} | {:error, term()}
  def list(repo_id, opts \\ []) do
    token = opts[:token]
    repo_type = opts[:repo_type] || :model

    params =
      %{}
      |> maybe_put(:author, opts[:author])
      |> maybe_put(:status, status_to_string(opts[:status]))
      |> Enum.to_list()

    path = "/api/#{type_prefix(repo_type)}/#{encode(repo_id)}/discussions"

    case HTTP.get(path, token: token, params: params) do
      {:ok, %{"discussions" => discussions}} ->
        {:ok, Enum.map(discussions, &Discussion.from_response/1)}

      {:ok, discussions} when is_list(discussions) ->
        {:ok, Enum.map(discussions, &Discussion.from_response/1)}

      error ->
        error
    end
  end

  @doc """
  Gets details for a specific discussion.

  Includes full content and all comments/events.

  ## Options

    * `:token` - Authentication token
    * `:repo_type` - Repository type (default: `:model`)

  ## Examples

      {:ok, details} = HfHub.Discussions.get("my-model", 42)
      details.events  # List of comments, status changes, etc.
  """
  @spec get(String.t(), non_neg_integer(), keyword()) ::
          {:ok, DiscussionDetails.t()} | {:error, term()}
  def get(repo_id, discussion_num, opts \\ []) do
    token = opts[:token]
    repo_type = opts[:repo_type] || :model

    path = "/api/#{type_prefix(repo_type)}/#{encode(repo_id)}/discussions/#{discussion_num}"

    case HTTP.get(path, token: token) do
      {:ok, response} -> {:ok, DiscussionDetails.from_response(response)}
      error -> error
    end
  end

  @doc """
  Creates a new discussion.

  ## Options

    * `:token` - Authentication token (required)
    * `:description` - Discussion body/description
    * `:repo_type` - Repository type (default: `:model`)

  ## Examples

      {:ok, disc} = HfHub.Discussions.create("my-model", "Feature request",
        description: "Please add support for...")
  """
  @spec create(String.t(), String.t(), keyword()) ::
          {:ok, DiscussionDetails.t()} | {:error, term()}
  def create(repo_id, title, opts \\ []) do
    token = opts[:token] || Auth.get_token()
    repo_type = opts[:repo_type] || :model
    pull_request = opts[:pull_request] || false

    body =
      %{
        "title" => title,
        "pullRequest" => pull_request
      }
      |> maybe_put("description", opts[:description])

    path = "/api/#{type_prefix(repo_type)}/#{encode(repo_id)}/discussions"

    case HTTP.post(path, body, token: token) do
      {:ok, response} -> {:ok, DiscussionDetails.from_response(response)}
      error -> error
    end
  end

  @doc """
  Creates a new pull request.

  ## Options

    * `:token` - Authentication token (required)
    * `:description` - Pull request body/description
    * `:repo_type` - Repository type (default: `:model`)

  ## Examples

      {:ok, pr} = HfHub.Discussions.create_pr("my-model", "Add new feature",
        description: "This PR adds...")
  """
  @spec create_pr(String.t(), String.t(), keyword()) ::
          {:ok, DiscussionDetails.t()} | {:error, term()}
  def create_pr(repo_id, title, opts \\ []) do
    create(repo_id, title, Keyword.put(opts, :pull_request, true))
  end

  @doc """
  Adds a comment to a discussion.

  ## Options

    * `:token` - Authentication token (required)
    * `:repo_type` - Repository type (default: `:model`)

  ## Examples

      {:ok, comment} = HfHub.Discussions.comment("my-model", 42, "Thanks for reporting!")
  """
  @spec comment(String.t(), non_neg_integer(), String.t(), keyword()) ::
          {:ok, Comment.t()} | {:error, term()}
  def comment(repo_id, discussion_num, content, opts \\ []) do
    token = opts[:token] || Auth.get_token()
    repo_type = opts[:repo_type] || :model

    body = %{"comment" => content}
    path = "/api/#{type_prefix(repo_type)}/#{encode(repo_id)}/discussions/#{discussion_num}/comment"

    case HTTP.post(path, body, token: token) do
      {:ok, response} -> {:ok, Comment.from_response(response)}
      error -> error
    end
  end

  @doc """
  Edits an existing comment.

  ## Options

    * `:token` - Authentication token (required)
    * `:repo_type` - Repository type (default: `:model`)

  ## Examples

      {:ok, comment} = HfHub.Discussions.edit_comment("my-model", 42, "abc123", "Updated content")
  """
  @spec edit_comment(String.t(), non_neg_integer(), String.t(), String.t(), keyword()) ::
          {:ok, Comment.t()} | {:error, term()}
  def edit_comment(repo_id, discussion_num, comment_id, new_content, opts \\ []) do
    token = opts[:token] || Auth.get_token()
    repo_type = opts[:repo_type] || :model

    body = %{"content" => new_content}

    path =
      "/api/#{type_prefix(repo_type)}/#{encode(repo_id)}/discussions/#{discussion_num}/comment/#{comment_id}"

    case HTTP.put(path, body, token: token) do
      {:ok, response} -> {:ok, Comment.from_response(response)}
      error -> error
    end
  end

  @doc """
  Hides a comment from view.

  ## Options

    * `:token` - Authentication token (required)
    * `:repo_type` - Repository type (default: `:model`)

  ## Examples

      {:ok, comment} = HfHub.Discussions.hide_comment("my-model", 42, "abc123")
  """
  @spec hide_comment(String.t(), non_neg_integer(), String.t(), keyword()) ::
          {:ok, Comment.t()} | {:error, term()}
  def hide_comment(repo_id, discussion_num, comment_id, opts \\ []) do
    token = opts[:token] || Auth.get_token()
    repo_type = opts[:repo_type] || :model

    path =
      "/api/#{type_prefix(repo_type)}/#{encode(repo_id)}/discussions/#{discussion_num}/comment/#{comment_id}/hide"

    case HTTP.put(path, %{}, token: token) do
      {:ok, response} -> {:ok, Comment.from_response(response)}
      error -> error
    end
  end

  @doc """
  Closes a discussion.

  ## Options

    * `:token` - Authentication token (required)
    * `:repo_type` - Repository type (default: `:model`)
    * `:comment` - Optional comment explaining the status change

  ## Examples

      {:ok, disc} = HfHub.Discussions.close("my-model", 42, comment: "Fixed in v2.0")
  """
  @spec close(String.t(), non_neg_integer(), keyword()) ::
          {:ok, Discussion.t()} | {:error, term()}
  def close(repo_id, discussion_num, opts \\ []) do
    change_status(repo_id, discussion_num, :closed, opts)
  end

  @doc """
  Reopens a closed discussion.

  ## Options

    * `:token` - Authentication token (required)
    * `:repo_type` - Repository type (default: `:model`)
    * `:comment` - Optional comment explaining the status change

  ## Examples

      {:ok, disc} = HfHub.Discussions.reopen("my-model", 42)
  """
  @spec reopen(String.t(), non_neg_integer(), keyword()) ::
          {:ok, Discussion.t()} | {:error, term()}
  def reopen(repo_id, discussion_num, opts \\ []) do
    change_status(repo_id, discussion_num, :open, opts)
  end

  @doc """
  Changes the status of a discussion.

  ## Options

    * `:token` - Authentication token (required)
    * `:repo_type` - Repository type (default: `:model`)
    * `:comment` - Optional comment explaining the status change

  ## Examples

      {:ok, disc} = HfHub.Discussions.change_status("my-model", 42, :closed, comment: "Resolved")
  """
  @spec change_status(String.t(), non_neg_integer(), status(), keyword()) ::
          {:ok, Discussion.t()} | {:error, term()}
  def change_status(repo_id, discussion_num, new_status, opts \\ []) do
    token = opts[:token] || Auth.get_token()
    repo_type = opts[:repo_type] || :model

    body =
      %{"status" => status_to_string(new_status)}
      |> maybe_put("comment", opts[:comment])

    path = "/api/#{type_prefix(repo_type)}/#{encode(repo_id)}/discussions/#{discussion_num}/status"

    case HTTP.put(path, body, token: token) do
      {:ok, response} -> {:ok, Discussion.from_response(response)}
      error -> error
    end
  end

  @doc """
  Merges a pull request.

  ## Options

    * `:token` - Authentication token (required)
    * `:repo_type` - Repository type (default: `:model`)
    * `:comment` - Optional merge comment

  ## Examples

      {:ok, pr} = HfHub.Discussions.merge_pr("my-model", 42)
  """
  @spec merge_pr(String.t(), non_neg_integer(), keyword()) ::
          {:ok, Discussion.t()} | {:error, term()}
  def merge_pr(repo_id, discussion_num, opts \\ []) do
    token = opts[:token] || Auth.get_token()
    repo_type = opts[:repo_type] || :model

    body = maybe_put(%{}, "comment", opts[:comment])

    path = "/api/#{type_prefix(repo_type)}/#{encode(repo_id)}/discussions/#{discussion_num}/merge"

    case HTTP.post(path, body, token: token) do
      {:ok, response} -> {:ok, Discussion.from_response(response)}
      error -> error
    end
  end

  @doc """
  Renames a discussion.

  ## Options

    * `:token` - Authentication token (required)
    * `:repo_type` - Repository type (default: `:model`)

  ## Examples

      {:ok, disc} = HfHub.Discussions.rename("my-model", 42, "New Title")
  """
  @spec rename(String.t(), non_neg_integer(), String.t(), keyword()) ::
          {:ok, Discussion.t()} | {:error, term()}
  def rename(repo_id, discussion_num, new_title, opts \\ []) do
    token = opts[:token] || Auth.get_token()
    repo_type = opts[:repo_type] || :model

    body = %{"title" => new_title}
    path = "/api/#{type_prefix(repo_type)}/#{encode(repo_id)}/discussions/#{discussion_num}/title"

    case HTTP.put(path, body, token: token) do
      {:ok, response} -> {:ok, Discussion.from_response(response)}
      error -> error
    end
  end

  # Private helpers

  defp type_prefix(:model), do: "models"
  defp type_prefix(:dataset), do: "datasets"
  defp type_prefix(:space), do: "spaces"

  defp encode(s), do: URI.encode(s, &URI.char_unreserved?/1)

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp status_to_string(nil), do: nil
  defp status_to_string(:open), do: "open"
  defp status_to_string(:closed), do: "closed"
  defp status_to_string(:merged), do: "merged"
  defp status_to_string(:draft), do: "draft"
  defp status_to_string(:all), do: "all"
  defp status_to_string(s) when is_binary(s), do: s
end
