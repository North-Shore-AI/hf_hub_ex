defmodule HfHub.Users do
  @moduledoc """
  User profile and activity API.

  Provides functions to interact with HuggingFace Hub user profiles,
  followers/following relationships, and repository likes.

  ## Examples

      # Get user profile
      {:ok, user} = HfHub.Users.get("username")
      IO.inspect(user.num_followers)

      # List followers
      {:ok, followers} = HfHub.Users.list_followers("username")

      # Like/unlike repos
      :ok = HfHub.Users.like("bert-base-uncased")
      :ok = HfHub.Users.unlike("bert-base-uncased")
  """

  alias HfHub.{Auth, HTTP}
  alias HfHub.Users.User

  @doc """
  Gets a user's public profile.

  ## Arguments

    * `username` - The HuggingFace username

  ## Options

    * `:token` - Authentication token

  ## Examples

      {:ok, user} = HfHub.Users.get("julien-c")
      IO.inspect(user.username)   # "julien-c"
      IO.inspect(user.fullname)   # "Julien Chaumond"
  """
  @spec get(String.t(), keyword()) :: {:ok, User.t()} | {:error, term()}
  def get(username, opts \\ []) do
    token = opts[:token]

    case HTTP.get("/api/users/#{encode(username)}", token: token) do
      {:ok, response} -> {:ok, User.from_response(response)}
      error -> error
    end
  end

  @doc """
  Lists users who follow a user.

  ## Arguments

    * `username` - The HuggingFace username

  ## Options

    * `:token` - Authentication token

  ## Examples

      {:ok, followers} = HfHub.Users.list_followers("julien-c")
      Enum.each(followers, &IO.inspect(&1.username))
  """
  @spec list_followers(String.t(), keyword()) :: {:ok, [User.t()]} | {:error, term()}
  def list_followers(username, opts \\ []) do
    token = opts[:token]

    case HTTP.get("/api/users/#{encode(username)}/followers", token: token) do
      {:ok, users} when is_list(users) ->
        {:ok, Enum.map(users, &User.from_response/1)}

      {:ok, _} ->
        {:error, :invalid_response}

      error ->
        error
    end
  end

  @doc """
  Lists users a user is following.

  ## Arguments

    * `username` - The HuggingFace username

  ## Options

    * `:token` - Authentication token

  ## Examples

      {:ok, following} = HfHub.Users.list_following("julien-c")
  """
  @spec list_following(String.t(), keyword()) :: {:ok, [User.t()]} | {:error, term()}
  def list_following(username, opts \\ []) do
    token = opts[:token]

    case HTTP.get("/api/users/#{encode(username)}/following", token: token) do
      {:ok, users} when is_list(users) ->
        {:ok, Enum.map(users, &User.from_response/1)}

      {:ok, _} ->
        {:error, :invalid_response}

      error ->
        error
    end
  end

  @doc """
  Lists repositories liked by a user.

  ## Arguments

    * `username` - The HuggingFace username

  ## Options

    * `:token` - Authentication token

  ## Examples

      {:ok, liked} = HfHub.Users.list_liked_repos("julien-c")
  """
  @spec list_liked_repos(String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def list_liked_repos(username, opts \\ []) do
    token = opts[:token]

    case HTTP.get("/api/users/#{encode(username)}/likes", token: token) do
      {:ok, %{"likes" => likes}} when is_list(likes) ->
        {:ok, likes}

      {:ok, likes} when is_list(likes) ->
        {:ok, likes}

      {:ok, _} ->
        {:error, :invalid_response}

      error ->
        error
    end
  end

  @doc """
  Likes a repository.

  Requires authentication.

  ## Arguments

    * `repo_id` - Repository ID (e.g., "bert-base-uncased")

  ## Options

    * `:token` - Authentication token. If not provided, uses configured token.
    * `:repo_type` - Type of repository (`:model`, `:dataset`, `:space`). Defaults to `:model`.

  ## Examples

      :ok = HfHub.Users.like("bert-base-uncased")
      :ok = HfHub.Users.like("squad", repo_type: :dataset)
  """
  @spec like(String.t(), keyword()) :: :ok | {:error, term()}
  def like(repo_id, opts \\ []) do
    token = opts[:token] || get_token()
    repo_type = opts[:repo_type] || :model

    path = "/api/#{type_prefix(repo_type)}/#{encode(repo_id)}/like"
    HTTP.post_action(path, nil, token: token)
  end

  @doc """
  Unlikes a repository.

  Requires authentication.

  ## Arguments

    * `repo_id` - Repository ID (e.g., "bert-base-uncased")

  ## Options

    * `:token` - Authentication token. If not provided, uses configured token.
    * `:repo_type` - Type of repository (`:model`, `:dataset`, `:space`). Defaults to `:model`.

  ## Examples

      :ok = HfHub.Users.unlike("bert-base-uncased")
  """
  @spec unlike(String.t(), keyword()) :: :ok | {:error, term()}
  def unlike(repo_id, opts \\ []) do
    token = opts[:token] || get_token()
    repo_type = opts[:repo_type] || :model

    path = "/api/#{type_prefix(repo_type)}/#{encode(repo_id)}/like"
    HTTP.delete(path, token: token)
  end

  @doc """
  Lists users who liked a repository.

  ## Arguments

    * `repo_id` - Repository ID (e.g., "bert-base-uncased")

  ## Options

    * `:token` - Authentication token
    * `:repo_type` - Type of repository (`:model`, `:dataset`, `:space`). Defaults to `:model`.

  ## Examples

      {:ok, likers} = HfHub.Users.list_likers("bert-base-uncased")
  """
  @spec list_likers(String.t(), keyword()) :: {:ok, [User.t()]} | {:error, term()}
  def list_likers(repo_id, opts \\ []) do
    token = opts[:token]
    repo_type = opts[:repo_type] || :model

    path = "/api/#{type_prefix(repo_type)}/#{encode(repo_id)}/likers"

    case HTTP.get(path, token: token) do
      {:ok, users} when is_list(users) ->
        {:ok, Enum.map(users, &User.from_response/1)}

      {:ok, _} ->
        {:error, :invalid_response}

      error ->
        error
    end
  end

  # Private helpers

  defp type_prefix(:model), do: "models"
  defp type_prefix(:dataset), do: "datasets"
  defp type_prefix(:space), do: "spaces"

  defp encode(s), do: URI.encode(s, &URI.char_unreserved?/1)

  defp get_token do
    case Auth.get_token() do
      {:ok, t} -> t
      _ -> nil
    end
  end
end
