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

  @type tree_entry :: %{
          type: :file | :folder,
          path: String.t(),
          size: non_neg_integer() | nil,
          lfs: map() | nil,
          oid: String.t() | nil
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
    revision = Keyword.get(opts, :revision)
    token = Keyword.get(opts, :token)

    path = "/api/models/#{repo_id}"
    params = if revision, do: [revision: revision], else: []

    case HfHub.HTTP.get(path, token: token, params: params) do
      {:ok, data} -> {:ok, parse_model_info(data)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_model_info(data) do
    %{
      id: Map.get(data, "id") || Map.get(data, "modelId"),
      author: Map.get(data, "author"),
      sha: Map.get(data, "sha"),
      downloads: Map.get(data, "downloads", 0),
      likes: Map.get(data, "likes", 0),
      tags: Map.get(data, "tags", []),
      pipeline_tag: Map.get(data, "pipeline_tag"),
      siblings: parse_siblings(Map.get(data, "siblings", [])),
      created_at: parse_datetime(Map.get(data, "createdAt")),
      updated_at: parse_datetime(Map.get(data, "lastModified"))
    }
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
    revision = Keyword.get(opts, :revision)
    token = Keyword.get(opts, :token)

    path = "/api/datasets/#{repo_id}"
    params = if revision, do: [revision: revision], else: []

    case HfHub.HTTP.get(path, token: token, params: params) do
      {:ok, data} -> {:ok, parse_dataset_info(data)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_dataset_info(data) do
    %{
      id: Map.get(data, "id"),
      author: Map.get(data, "author"),
      sha: Map.get(data, "sha"),
      downloads: Map.get(data, "downloads", 0),
      likes: Map.get(data, "likes", 0),
      tags: Map.get(data, "tags", []),
      siblings: parse_siblings(Map.get(data, "siblings", [])),
      created_at: parse_datetime(Map.get(data, "createdAt")),
      updated_at: parse_datetime(Map.get(data, "lastModified"))
    }
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
    revision = Keyword.get(opts, :revision)
    token = Keyword.get(opts, :token)

    path = "/api/spaces/#{repo_id}"
    params = if revision, do: [revision: revision], else: []

    case HfHub.HTTP.get(path, token: token, params: params) do
      {:ok, data} -> {:ok, parse_space_info(data)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_space_info(data) do
    %{
      id: Map.get(data, "id"),
      author: Map.get(data, "author"),
      sha: Map.get(data, "sha"),
      likes: Map.get(data, "likes", 0),
      tags: Map.get(data, "tags", []),
      sdk: Map.get(data, "sdk"),
      created_at: parse_datetime(Map.get(data, "createdAt")),
      updated_at: parse_datetime(Map.get(data, "lastModified"))
    }
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
    params = build_list_params(opts)
    token = Keyword.get(opts, :token)

    case HfHub.HTTP.get("/api/models", token: token, params: params) do
      {:ok, models} when is_list(models) ->
        {:ok, Enum.map(models, &parse_model_info/1)}

      {:ok, _} ->
        {:error, :invalid_response}

      {:error, reason} ->
        {:error, reason}
    end
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
    params = build_list_params(opts)
    token = Keyword.get(opts, :token)

    case HfHub.HTTP.get("/api/datasets", token: token, params: params) do
      {:ok, datasets} when is_list(datasets) ->
        {:ok, Enum.map(datasets, &parse_dataset_info/1)}

      {:ok, _} ->
        {:error, :invalid_response}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Lists repository tree entries (files and folders).

  ## Options

    * `:repo_type` - Type of repository (`:model`, `:dataset`, or `:space`). Defaults to `:model`.
    * `:revision` - Git revision. Defaults to `"main"`.
    * `:path_in_repo` - Subdirectory path to list.
    * `:recursive` - List recursively. Defaults to `false`.
    * `:expand` - Request expanded metadata. Defaults to `false`.
    * `:token` - Authentication token.
  """
  @spec list_repo_tree(HfHub.repo_id(), keyword()) :: {:ok, [tree_entry()]} | {:error, term()}
  def list_repo_tree(repo_id, opts \\ []) do
    repo_type = Keyword.get(opts, :repo_type, :model)
    revision = Keyword.get(opts, :revision, "main")
    token = Keyword.get(opts, :token)
    recursive = Keyword.get(opts, :recursive, false)
    expand = Keyword.get(opts, :expand, false)
    path_in_repo = normalize_path_in_repo(Keyword.get(opts, :path_in_repo))

    params = []
    params = if recursive, do: [{:recursive, 1} | params], else: params
    params = if expand, do: [{:expand, 1} | params], else: params
    params = Enum.reverse(params)

    path =
      "/api/#{repo_type}s/#{repo_id}/tree/#{revision}" <>
        if(path_in_repo, do: "/#{path_in_repo}", else: "")

    case HfHub.HTTP.get_paginated(path, token: token, params: params) do
      {:ok, items} ->
        {:ok, Enum.map(items, &parse_tree_entry/1)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Gets the available configuration names for a dataset.

  Configurations (also called subsets) represent different versions or splits
  of a dataset. For example, `openai/gsm8k` has "main" and "socratic" configs.

  ## Options

    * `:token` - Authentication token. If not provided, uses configured token.

  ## Examples

      {:ok, configs} = HfHub.Api.dataset_configs("openai/gsm8k")
      # => {:ok, ["main", "socratic"]}

      {:ok, configs} = HfHub.Api.dataset_configs("imdb")
      # => {:ok, ["plain_text"]}
  """
  @spec dataset_configs(HfHub.repo_id(), keyword()) :: {:ok, [String.t()]} | {:error, term()}
  def dataset_configs(repo_id, opts \\ []) do
    token = Keyword.get(opts, :token)
    revision = Keyword.get(opts, :revision, "main")

    case HfHub.HTTP.get("/api/datasets/#{repo_id}", token: token, params: [revision: revision]) do
      {:ok, data} ->
        card_data = Map.get(data, "cardData")
        configs = extract_config_names(card_data)

        if configs != [] do
          {:ok, configs}
        else
          dataset_configs_fallback(repo_id, revision, token)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Lists available splits for a dataset config.

  ## Options

    * `:config` - Dataset config name (defaults to inferred config).
    * `:revision` - Git revision. Defaults to `"main"`.
    * `:token` - Authentication token.
  """
  @spec dataset_splits(HfHub.repo_id(), keyword()) :: {:ok, [String.t()]} | {:error, term()}
  def dataset_splits(repo_id, opts \\ []) do
    token = Keyword.get(opts, :token)
    revision = Keyword.get(opts, :revision, "main")
    config_opt = Keyword.get(opts, :config)

    case fetch_dataset_infos(repo_id, revision, token) do
      {:ok, infos} ->
        config = config_opt || default_config_from_infos(infos)
        splits = splits_from_infos(infos, config)

        if splits != [] do
          {:ok, splits}
        else
          dataset_splits_from_tree(repo_id, config_opt, revision, token)
        end

      {:error, :not_found} ->
        dataset_splits_from_tree(repo_id, config_opt, revision, token)

      {:error, :invalid_response} ->
        dataset_splits_from_tree(repo_id, config_opt, revision, token)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Extracts configuration names from dataset card_data.

  Handles both the modern "configs" format and legacy "dataset_config_names" format.

  ## Examples

      iex> HfHub.Api.extract_config_names(%{"configs" => [%{"config_name" => "main"}]})
      ["main"]

      iex> HfHub.Api.extract_config_names(%{"dataset_config_names" => ["train", "test"]})
      ["train", "test"]

      iex> HfHub.Api.extract_config_names(nil)
      []
  """
  @spec extract_config_names(map() | nil) :: [String.t()]
  def extract_config_names(nil), do: []

  def extract_config_names(card_data) when is_map(card_data) do
    cond do
      # Modern format: list of config objects with config_name field
      configs = Map.get(card_data, "configs") ->
        configs
        |> Enum.map(&Map.get(&1, "config_name"))
        |> Enum.reject(&is_nil/1)

      # Legacy format: simple list of config names
      config_names = Map.get(card_data, "dataset_config_names") ->
        config_names

      true ->
        []
    end
  end

  def extract_config_names(_), do: []

  @doc """
  Lists files in a repository.

  ## Options

    * `:repo_type` - Type of repository (`:model`, `:dataset`, or `:space`). Defaults to `:model`.
    * `:revision` - Git revision. Defaults to `"main"`.
    * `:recursive` - List files recursively. Defaults to `true` for datasets.
    * `:path_in_repo` - Subdirectory path to list.
    * `:token` - Authentication token.

  ## Examples

      {:ok, files} = HfHub.Api.list_files("bert-base-uncased", repo_type: :model)
  """
  @spec list_files(HfHub.repo_id(), keyword()) :: {:ok, [file_info()]} | {:error, term()}
  def list_files(repo_id, opts \\ []) do
    repo_type = Keyword.get(opts, :repo_type, :model)
    revision = Keyword.get(opts, :revision, "main")
    token = Keyword.get(opts, :token)
    recursive = Keyword.get(opts, :recursive, repo_type == :dataset)
    path_in_repo = Keyword.get(opts, :path_in_repo)

    use_tree = repo_type == :dataset or recursive or not is_nil(path_in_repo)

    if use_tree do
      with {:ok, items} <-
             list_repo_tree(repo_id,
               repo_type: repo_type,
               revision: revision,
               token: token,
               recursive: recursive,
               path_in_repo: path_in_repo
             ) do
        files =
          items
          |> Enum.filter(&(&1.type == :file))
          |> Enum.map(&tree_entry_to_file/1)

        {:ok, files}
      end
    else
      # Get repo info which includes file list
      case repo_info_internal(repo_id, repo_type, revision, token) do
        {:ok, info} ->
          files = Map.get(info, "siblings", []) |> parse_siblings()
          {:ok, files}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  # Private helpers

  defp dataset_configs_fallback(repo_id, revision, token) do
    case fetch_dataset_infos(repo_id, revision, token) do
      {:ok, infos} ->
        configs = infos |> Map.keys() |> Enum.sort()

        if configs != [] do
          {:ok, configs}
        else
          dataset_configs_from_tree(repo_id, revision, token)
        end

      {:error, :not_found} ->
        dataset_configs_from_tree(repo_id, revision, token)

      {:error, :invalid_response} ->
        dataset_configs_from_tree(repo_id, revision, token)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp dataset_configs_from_tree(repo_id, revision, token) do
    with {:ok, tree} <-
           list_repo_tree(repo_id,
             repo_type: :dataset,
             revision: revision,
             token: token,
             recursive: true
           ) do
      configs = HfHub.DatasetFiles.configs_from_tree(tree)
      {:ok, configs}
    end
  end

  defp dataset_splits_from_tree(repo_id, config_opt, revision, token) do
    with {:ok, tree} <-
           list_repo_tree(repo_id,
             repo_type: :dataset,
             revision: revision,
             token: token,
             recursive: true
           ) do
      configs = HfHub.DatasetFiles.configs_from_tree(tree)

      config =
        cond do
          config_opt ->
            config_opt

          "default" in configs ->
            "default"

          configs == [] ->
            "default"

          true ->
            hd(configs)
        end

      splits = HfHub.DatasetFiles.splits_from_tree(tree, config)
      {:ok, splits}
    end
  end

  defp fetch_dataset_infos(repo_id, revision, token) do
    path = "/datasets/#{repo_id}/resolve/#{revision}/dataset_infos.json"

    case HfHub.HTTP.get(path, token: token) do
      {:ok, infos} when is_map(infos) ->
        {:ok, infos}

      {:ok, _} ->
        {:error, :invalid_response}

      {:error, %Jason.DecodeError{}} ->
        {:error, :invalid_response}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp default_config_from_infos(infos) when is_map(infos) do
    configs = infos |> Map.keys() |> Enum.sort()

    cond do
      "default" in configs -> "default"
      configs == [] -> "default"
      true -> hd(configs)
    end
  end

  defp splits_from_infos(infos, config) when is_map(infos) and is_binary(config) do
    case Map.get(infos, config) do
      %{"splits" => splits} when is_map(splits) ->
        splits |> Map.keys() |> Enum.sort()

      %{"splits" => splits} when is_list(splits) ->
        splits
        |> Enum.map(&Map.get(&1, "name"))
        |> Enum.reject(&is_nil/1)
        |> Enum.sort()

      _ ->
        []
    end
  end

  defp splits_from_infos(_, _), do: []

  defp normalize_path_in_repo(nil), do: nil
  defp normalize_path_in_repo(""), do: nil

  defp normalize_path_in_repo(path) when is_binary(path) do
    String.trim(path, "/")
  end

  defp parse_tree_entry(entry) when is_map(entry) do
    %{
      type: parse_tree_type(Map.get(entry, "type")),
      path: Map.get(entry, "path"),
      size: Map.get(entry, "size"),
      lfs: Map.get(entry, "lfs"),
      oid: Map.get(entry, "oid")
    }
  end

  defp parse_tree_entry(_), do: %{type: :file, path: nil, size: nil, lfs: nil, oid: nil}

  defp parse_tree_type("file"), do: :file
  defp parse_tree_type("directory"), do: :folder
  defp parse_tree_type("dir"), do: :folder
  defp parse_tree_type(_), do: :file

  defp tree_entry_to_file(entry) do
    %{
      rfilename: Map.get(entry, :path),
      size: Map.get(entry, :size, 0) || 0,
      lfs: Map.get(entry, :lfs)
    }
  end

  defp repo_info_internal(repo_id, repo_type, revision, token) do
    path =
      case repo_type do
        :model -> "/api/models/#{repo_id}"
        :dataset -> "/api/datasets/#{repo_id}"
        :space -> "/api/spaces/#{repo_id}"
      end

    params = if revision, do: [revision: revision], else: []
    HfHub.HTTP.get(path, token: token, params: params)
  end

  defp build_list_params(opts) do
    params = []

    params =
      if filter = Keyword.get(opts, :filter) do
        [{:filter, filter} | params]
      else
        params
      end

    params =
      if sort = Keyword.get(opts, :sort) do
        [{:sort, sort} | params]
      else
        params
      end

    params =
      if direction = Keyword.get(opts, :direction) do
        [{:direction, Atom.to_string(direction)} | params]
      else
        params
      end

    params =
      if limit = Keyword.get(opts, :limit) do
        [{:limit, limit} | params]
      else
        params
      end

    params =
      if author = Keyword.get(opts, :author) do
        [{:author, author} | params]
      else
        params
      end

    params
  end

  defp parse_siblings(siblings) when is_list(siblings) do
    Enum.map(siblings, fn sibling ->
      %{
        rfilename: Map.get(sibling, "rfilename"),
        size: Map.get(sibling, "size", 0),
        lfs: Map.get(sibling, "lfs")
      }
    end)
  end

  defp parse_siblings(_), do: []

  defp parse_datetime(nil), do: nil

  defp parse_datetime(datetime_string) when is_binary(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, _} -> datetime
      _ -> nil
    end
  end

  defp parse_datetime(_), do: nil
end
