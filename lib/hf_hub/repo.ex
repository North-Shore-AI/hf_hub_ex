defmodule HfHub.Repo do
  @moduledoc """
  Repository management operations for HuggingFace Hub.

  Provides create, delete, update, and move operations for repositories
  (models, datasets, and spaces).

  ## Examples

      # Create a new model repository
      {:ok, url} = HfHub.Repo.create("my-org/my-model", private: true)

      # Create a space with Gradio
      {:ok, url} = HfHub.Repo.create("my-space",
        repo_type: :space,
        space_sdk: "gradio"
      )

      # Delete a repository
      :ok = HfHub.Repo.delete("my-org/old-model")

      # Update settings
      :ok = HfHub.Repo.update_settings("my-model", private: true, gated: :auto)

      # Move/rename a repository
      {:ok, url} = HfHub.Repo.move("old-name", "new-org/new-name")
  """

  alias HfHub.{Auth, Config, HTTP}
  alias HfHub.Repo.RepoUrl

  @type repo_type :: :model | :dataset | :space
  @type gated :: :auto | :manual | false
  @type space_sdk :: String.t()
  @type space_hardware :: String.t()

  @doc """
  Creates a new repository on the Hugging Face Hub.

  ## Options

    * `:token` - Authentication token
    * `:repo_type` - Type of repository (:model, :dataset, :space). Defaults to :model.
    * `:private` - Whether the repository should be private. Defaults to false.
    * `:exist_ok` - If true, do not error if repo already exists. Defaults to false.
    * `:space_sdk` - SDK to use for spaces ("gradio", "streamlit", "docker", "static").
    * `:space_hardware` - Hardware to use for spaces.

  ## Examples

      {:ok, url} = HfHub.Repo.create("my-model")
      {:ok, url} = HfHub.Repo.create("my-dataset", repo_type: :dataset)
  """
  @spec create(String.t(), keyword()) :: {:ok, RepoUrl.t()} | {:error, term()}
  def create(repo_id, opts \\ []) do
    token = opts[:token] || Auth.get_token()
    repo_type = opts[:repo_type] || :model

    {name, organization} = parse_repo_id(repo_id)

    body =
      %{
        name: name,
        organization: organization,
        type: repo_type_to_string(repo_type),
        private: opts[:private] || false
      }
      |> maybe_add_space_opts(opts)

    exist_ok = Keyword.get(opts, :exist_ok, false)

    case HTTP.post("/api/repos/create", body, token: token) do
      {:ok, response} ->
        {:ok, RepoUrl.from_response(response, repo_type)}

      {:error, {:conflict, _}} when exist_ok ->
        url = build_repo_url(repo_id, repo_type)
        {:ok, %RepoUrl{url: url, repo_id: repo_id, repo_type: repo_type}}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Deletes a repository.

  ## Options

    * `:token` - Authentication token
    * `:repo_type` - Type of repository. Defaults to :model.
    * `:missing_ok` - If true, do not error if repo does not exist. Defaults to false.
  """
  @spec delete(String.t(), keyword()) :: :ok | {:error, term()}
  def delete(repo_id, opts \\ []) do
    token = opts[:token] || Auth.get_token()
    repo_type = opts[:repo_type] || :model
    prefix = repo_type_plural_prefix(repo_type)
    missing_ok = Keyword.get(opts, :missing_ok, false)

    case HTTP.delete("/api/repos/#{create_delete_path(prefix, repo_id)}", token: token) do
      :ok ->
        :ok

      {:ok, _} ->
        :ok

      {:error, :not_found} when missing_ok ->
        :ok

      {:error, _} = error ->
        error
    end
  end

  defp create_delete_path(prefix, repo_id), do: "#{prefix}/#{encode_repo_id(repo_id)}"

  @doc """
  Updates repository settings.

  ## Options

    * `:token` - Authentication token
    * `:repo_type` - Type of repository. Defaults to :model.
    * `:private` - Set visibility
    * `:gated` - Set gated status (:auto, :manual, false)
  """
  @spec update_settings(String.t(), keyword()) :: :ok | {:error, term()}
  def update_settings(repo_id, opts \\ []) do
    token = opts[:token] || Auth.get_token()
    repo_type = opts[:repo_type] || :model
    prefix = repo_type_plural_prefix(repo_type)

    body = %{}

    body =
      if Keyword.has_key?(opts, :private), do: Map.put(body, :private, opts[:private]), else: body

    body = if Keyword.has_key?(opts, :gated), do: Map.put(body, :gated, opts[:gated]), else: body

    # The prompt says: PUT /api/{type}s/{repo_id}/settings
    # The prefix for models is usually empty in some paths, but for settings endpoint:
    # It is likely /api/models/repo_id/settings or /api/datasets/repo_id/settings
    # Note: `repo_type_plural_prefix` returns "models", "datasets", "spaces"

    path = "/api/#{prefix}/#{encode_repo_id(repo_id)}/settings"

    case HTTP.put(path, body, token: token) do
      {:ok, _} -> :ok
      {:error, _} = error -> error
    end
  end

  @doc """
  Moves (renames) a repository.

  ## Options

    * `:token` - Authentication token
    * `:repo_type` - Type of repository. Defaults to :model.
  """
  @spec move(String.t(), String.t(), keyword()) :: {:ok, RepoUrl.t()} | {:error, term()}
  def move(from_repo, to_repo, opts \\ []) do
    token = opts[:token] || Auth.get_token()
    repo_type = opts[:repo_type] || :model

    body = %{
      fromRepo: from_repo,
      toRepo: to_repo,
      type: repo_type_to_string(repo_type)
    }

    case HTTP.post("/api/repos/move", body, token: token) do
      {:ok, response} ->
        # The response likely contains the new URL
        {:ok, RepoUrl.from_response(response, repo_type)}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Checks if a repository exists.

  Using HEAD request to check existence.
  For models: /repo_id
  For datasets: /datasets/repo_id
  For spaces: /spaces/repo_id
  """
  @spec exists?(String.t(), keyword()) :: boolean()
  def exists?(repo_id, opts \\ []) do
    token = opts[:token] || Auth.get_token()
    repo_type = opts[:repo_type] || :model

    path = build_public_path(repo_id, repo_type)

    # We use empty headers, but token might be needed for private repos
    req_opts = [token: token]

    # HfHub.HTTP.head takes a full URL. We should use HfHub.Config.endpoint to build it
    # or rely on HTTP.head to handle it if we pass a path?
    # HfHub.HTTP.head docs say "url - Full URL to request".
    # But HTTP.get can handle paths.
    # Let's check HTTP.head implementation again. It calls Req.head(url).
    # So we need to build the full URL.

    url = build_full_url(path)

    case HTTP.head(url, req_opts) do
      {:ok, %{status: 200}} -> true
      # If 401, it exists but is private (and we didn't provide valid token or token doesn't have access).
      # Strictly speaking checking existence usually implies we can see it.
      {:ok, %{status: 401}} -> true
      _ -> false
    end
  end

  @doc """
  Checks if a file exists in a repository.
  """
  @spec file_exists?(String.t(), String.t(), keyword()) :: boolean()
  def file_exists?(repo_id, filename, opts \\ []) do
    token = opts[:token] || Auth.get_token()
    repo_type = opts[:repo_type] || :model
    revision = opts[:revision] || "main"

    # "datasets/", "spaces/", or "" for models
    prefix = repo_type_url_prefix(repo_type)

    # URL pattern: /{prefix}{repo_id}/resolve/{rev}/{filename}
    path =
      if prefix == "" do
        "/#{repo_id}/resolve/#{revision}/#{filename}"
      else
        "/#{prefix}/#{repo_id}/resolve/#{revision}/#{filename}"
      end

    url = build_full_url(path)

    req_opts = [token: token, follow_redirects: false]

    case HTTP.head(url, req_opts) do
      {:ok, %{status: status}} when status in 200..299 -> true
      # Redirect means it exists (LFS usually redirects)
      {:ok, %{status: 302}} -> true
      _ -> false
    end
  end

  @doc """
  Checks if a revision exists.

  Uses the repo info endpoint to check for valid revision.
  This is effectively checking if we can get info about a specific revision.
  """
  @spec revision_exists?(String.t(), String.t(), keyword()) :: boolean()
  def revision_exists?(repo_id, revision, opts \\ []) do
    # API call to get repo info with confirmation for revision
    # GET /api/{type}s/{repo_id}/revision/{revision}
    # Or just GET /api/{type}s/{repo_id} with revision param?
    # Python lib typically uses:
    # /api/{type}/{repo_id}/revision/{revision} - this returns 200 if valid, 404 if not.
    # Note: For models, prefix is "models".

    token = opts[:token] || Auth.get_token()
    repo_type = opts[:repo_type] || :model
    prefix = repo_type_plural_prefix(repo_type)

    path = "/api/#{prefix}/#{encode_repo_id(repo_id)}/revision/#{URI.encode(revision)}"

    case HTTP.get(path, token: token) do
      {:ok, _} -> true
      _ -> false
    end
  end

  # Helpers

  defp parse_repo_id(repo_id) do
    case String.split(repo_id, "/", parts: 2) do
      [name] -> {name, nil}
      [org, name] -> {name, org}
    end
  end

  defp maybe_add_space_opts(%{type: "space"} = body, opts) do
    body
    |> Map.put(:sdk, opts[:space_sdk])
    |> maybe_add_hardware(opts)
  end

  defp maybe_add_space_opts(body, _opts), do: body

  defp maybe_add_hardware(body, opts) do
    if hardware = opts[:space_hardware] do
      Map.put(body, :hardware, hardware)
    else
      body
    end
  end

  defp repo_type_to_string(:model), do: "model"
  defp repo_type_to_string(:dataset), do: "dataset"
  defp repo_type_to_string(:space), do: "space"

  # Singular prefix for some constructs (though API mostly uses plural)
  # Actually API seems to use plural "models", "datasets", "spaces" for most endpoints.
  defp repo_type_plural_prefix(:model), do: "models"
  defp repo_type_plural_prefix(:dataset), do: "datasets"
  defp repo_type_plural_prefix(:space), do: "spaces"

  # URL prefix for public pages / resolving files
  defp repo_type_url_prefix(:model), do: ""
  defp repo_type_url_prefix(:dataset), do: "datasets"
  defp repo_type_url_prefix(:space), do: "spaces"

  defp encode_repo_id(repo_id) do
    # Repository IDs can contain slashes (org/name)
    # The API expects them as org/name in the path usually, but some endpoints might want encoded slashes.
    # However, standard practice for HF API in path params:
    # /api/models/org/name -> works
    # /api/models/org%2Fname -> also works and is safer

    # Python code uses `quote(repo_id, safe="")` implies full encoding.
    URI.encode(repo_id, &URI.char_unreserved?/1)
  end

  defp build_public_path(repo_id, :model), do: "/#{repo_id}"
  defp build_public_path(repo_id, :dataset), do: "/datasets/#{repo_id}"
  defp build_public_path(repo_id, :space), do: "/spaces/#{repo_id}"

  defp build_full_url(path) do
    endpoint = Config.endpoint()
    URI.merge(endpoint, path) |> URI.to_string()
  end

  defp build_repo_url(repo_id, repo_type) do
    path = build_public_path(repo_id, repo_type)
    build_full_url(path)
  end
end
