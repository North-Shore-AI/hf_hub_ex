defmodule HfHub.Api do
  @moduledoc """
  HuggingFace Hub API client.

  Provides functions to interact with the HuggingFace Hub API for fetching
  metadata about models, datasets, and spaces.

  ## Examples

      # Get model information
      {:ok, model_info} = HfHub.Api.model_info("bert-base-uncased")

      # Get dataset information
      {:ok, dataset_info} = HfHub.Api.dataset_info("squad")

      # List models with filters
      {:ok, models} = HfHub.Api.list_models(filter: "text-classification", sort: "downloads")

      # List files in a repository
      {:ok, files} = HfHub.Api.list_files("bert-base-uncased", repo_type: :model)
  """

  alias HfHub.HTTP

  @type model_info :: %{
          id: String.t(),
          author: String.t() | nil,
          sha: String.t(),
          downloads: non_neg_integer(),
          likes: non_neg_integer(),
          tags: [String.t()],
          pipeline_tag: String.t() | nil,
          siblings: [file_info()],
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @type dataset_info :: %{
          id: String.t(),
          author: String.t() | nil,
          sha: String.t(),
          downloads: non_neg_integer(),
          likes: non_neg_integer(),
          tags: [String.t()],
          siblings: [file_info()],
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @type space_info :: %{
          id: String.t(),
          author: String.t() | nil,
          sha: String.t(),
          likes: non_neg_integer(),
          tags: [String.t()],
          sdk: String.t(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @type file_info :: %{
          rfilename: String.t(),
          size: non_neg_integer(),
          lfs: map() | nil
        }

  @doc """
  Fetches information about a model from the HuggingFace Hub.

  ## Options

    * `:revision` - Git revision (branch, tag, or commit hash). Defaults to `"main"`.
    * `:token` - Authentication token. If not provided, uses configured token.

  ## Examples

      {:ok, info} = HfHub.Api.model_info("bert-base-uncased")
      {:ok, info} = HfHub.Api.model_info("bert-base-uncased", revision: "main")
  """
  @spec model_info(HfHub.repo_id(), keyword()) :: {:ok, model_info()} | {:error, term()}
  def model_info(repo_id, opts \\ []) do
    # TODO: Implement API call
    {:error, :not_implemented}
  end

  @doc """
  Fetches information about a dataset from the HuggingFace Hub.

  ## Options

    * `:revision` - Git revision (branch, tag, or commit hash). Defaults to `"main"`.
    * `:token` - Authentication token. If not provided, uses configured token.

  ## Examples

      {:ok, info} = HfHub.Api.dataset_info("squad")
      {:ok, info} = HfHub.Api.dataset_info("squad", revision: "main")
  """
  @spec dataset_info(HfHub.repo_id(), keyword()) :: {:ok, dataset_info()} | {:error, term()}
  def dataset_info(repo_id, opts \\ []) do
    # TODO: Implement API call
    {:error, :not_implemented}
  end

  @doc """
  Fetches information about a space from the HuggingFace Hub.

  ## Options

    * `:revision` - Git revision (branch, tag, or commit hash). Defaults to `"main"`.
    * `:token` - Authentication token. If not provided, uses configured token.

  ## Examples

      {:ok, info} = HfHub.Api.space_info("user/space-name")
  """
  @spec space_info(HfHub.repo_id(), keyword()) :: {:ok, space_info()} | {:error, term()}
  def space_info(repo_id, opts \\ []) do
    # TODO: Implement API call
    {:error, :not_implemented}
  end

  @doc """
  Lists models from the HuggingFace Hub with optional filters.

  ## Options

    * `:filter` - Filter by task, library, or other criteria
    * `:sort` - Sort by field (e.g., "downloads", "likes", "updated")
    * `:direction` - Sort direction (`:asc` or `:desc`)
    * `:limit` - Maximum number of results
    * `:author` - Filter by author

  ## Examples

      {:ok, models} = HfHub.Api.list_models(filter: "text-classification", limit: 10)
  """
  @spec list_models(keyword()) :: {:ok, [model_info()]} | {:error, term()}
  def list_models(opts \\ []) do
    # TODO: Implement API call
    {:error, :not_implemented}
  end

  @doc """
  Lists datasets from the HuggingFace Hub with optional filters.

  ## Options

    * `:filter` - Filter by task or other criteria
    * `:sort` - Sort by field (e.g., "downloads", "likes", "updated")
    * `:direction` - Sort direction (`:asc` or `:desc`)
    * `:limit` - Maximum number of results
    * `:author` - Filter by author

  ## Examples

      {:ok, datasets} = HfHub.Api.list_datasets(sort: "downloads", limit: 10)
  """
  @spec list_datasets(keyword()) :: {:ok, [dataset_info()]} | {:error, term()}
  def list_datasets(opts \\ []) do
    # TODO: Implement API call
    {:error, :not_implemented}
  end

  @doc """
  Lists files in a repository.

  ## Options

    * `:repo_type` - Type of repository (`:model`, `:dataset`, or `:space`). Defaults to `:model`.
    * `:revision` - Git revision. Defaults to `"main"`.
    * `:token` - Authentication token.

  ## Examples

      {:ok, files} = HfHub.Api.list_files("bert-base-uncased", repo_type: :model)
  """
  @spec list_files(HfHub.repo_id(), keyword()) :: {:ok, [file_info()]} | {:error, term()}
  def list_files(repo_id, opts \\ []) do
    # TODO: Implement API call
    {:error, :not_implemented}
  end
end
