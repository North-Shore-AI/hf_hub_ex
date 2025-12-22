defmodule HfHub.DatasetFiles do
  @moduledoc """
  Resolve dataset file paths by config and split.
  """

  @type tree_entry :: %{
          type: :file | :folder,
          path: String.t(),
          size: non_neg_integer() | nil,
          lfs: map() | nil,
          oid: String.t() | nil
        }

  @known_splits ["train", "test", "validation", "valid", "val", "dev", "eval"]
  @data_suffixes [
    ".parquet",
    ".jsonl",
    ".json",
    ".csv",
    ".tsv",
    ".arrow",
    ".txt",
    ".zip",
    ".tar.gz",
    ".tgz",
    ".tar.xz",
    ".tar",
    ".gz"
  ]

  @doc """
  Resolves dataset file paths for a config and split by listing the repo tree.
  """
  @spec resolve(HfHub.repo_id(), String.t(), String.t(), keyword()) ::
          {:ok, [String.t()]} | {:error, term()}
  def resolve(repo_id, config, split, opts \\ []) do
    repo_type = Keyword.get(opts, :repo_type, :dataset)
    revision = Keyword.get(opts, :revision, "main")
    token = Keyword.get(opts, :token)

    with {:ok, tree} <-
           HfHub.Api.list_repo_tree(repo_id,
             repo_type: repo_type,
             revision: revision,
             token: token,
             recursive: true
           ) do
      resolve_from_tree(tree, config, split)
    end
  end

  @doc """
  Resolves dataset file paths from a pre-fetched repo tree.
  """
  @spec resolve_from_tree([tree_entry()], String.t(), String.t()) ::
          {:ok, [String.t()]} | {:error, :no_files_found}
  def resolve_from_tree(tree, config, split) do
    paths =
      tree
      |> Enum.filter(&file_entry?/1)
      |> Enum.map(& &1.path)
      |> Enum.filter(&data_file?/1)

    matches = match_split_paths(paths, config, split)

    case matches do
      [] -> {:error, :no_files_found}
      _ -> {:ok, Enum.sort(matches)}
    end
  end

  @doc """
  Infers available split names from a repo tree for a config.
  """
  @spec splits_from_tree([tree_entry()], String.t()) :: [String.t()]
  def splits_from_tree(tree, config) do
    paths =
      tree
      |> Enum.filter(&file_entry?/1)
      |> Enum.map(& &1.path)
      |> Enum.filter(&data_file?/1)

    splits = splits_from_paths(paths, config)
    Enum.sort(splits)
  end

  @doc """
  Infers dataset config names from a repo tree.
  """
  @spec configs_from_tree([tree_entry()]) :: [String.t()]
  def configs_from_tree(tree) do
    tree
    |> Enum.filter(&file_entry?/1)
    |> Enum.map(& &1.path)
    |> Enum.filter(&data_file?/1)
    |> Enum.map(&config_from_path/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp file_entry?(%{type: :file}), do: true
  defp file_entry?(_), do: false

  defp data_file?(path) when is_binary(path) do
    down = String.downcase(path)
    Enum.any?(@data_suffixes, &String.ends_with?(down, &1))
  end

  defp data_file?(_), do: false

  defp match_split_paths(paths, config, split) do
    paths
    |> match_paths_with_prefixes(config_prefixes(config), split)
    |> fallback_to_root_if_empty(paths, config, split)
  end

  defp match_paths_with_prefixes(paths, prefixes, split) do
    prefixes
    |> Enum.flat_map(fn prefix ->
      Enum.flat_map(paths, fn path ->
        if String.starts_with?(path, prefix) do
          relative = String.replace_prefix(path, prefix, "")

          if split_match?(relative, split) do
            [path]
          else
            []
          end
        else
          []
        end
      end)
    end)
    |> Enum.uniq()
  end

  defp fallback_to_root_if_empty([], paths, config, split) when config not in [nil, "default"] do
    match_paths_with_prefixes(paths, [""], split)
  end

  defp fallback_to_root_if_empty(matches, _paths, _config, _split), do: matches

  defp split_match?(path, split) do
    case path do
      "data/" <> rest -> split_match_rest?(rest, split)
      _ -> split_match_rest?(path, split)
    end
  end

  defp split_match_rest?(path, split) do
    String.starts_with?(path, "#{split}-") or
      String.starts_with?(path, "#{split}.") or
      String.starts_with?(path, "#{split}/") or
      path == split
  end

  defp splits_from_paths(paths, config) do
    prefixes = config_prefixes(config)

    splits =
      prefixes
      |> Enum.flat_map(fn prefix ->
        Enum.flat_map(paths, fn path ->
          if String.starts_with?(path, prefix) do
            relative = String.replace_prefix(path, prefix, "")
            split = split_from_path(relative)

            if split in @known_splits do
              [split]
            else
              []
            end
          else
            []
          end
        end)
      end)
      |> Enum.uniq()

    if splits == [] and config not in [nil, "default"] do
      splits_from_paths(paths, nil)
    else
      splits
    end
  end

  defp split_from_path(path) when is_binary(path) do
    path =
      if String.starts_with?(path, "data/"),
        do: String.replace_prefix(path, "data/", ""),
        else: path

    path
    |> String.split("/", parts: 2)
    |> List.first()
    |> case do
      nil ->
        nil

      segment ->
        segment
        |> String.split("-", parts: 2)
        |> List.first()
        |> String.split(".", parts: 2)
        |> List.first()
    end
  end

  defp config_from_path(path) when is_binary(path) do
    segments = String.split(path, "/")

    case segments do
      [file] ->
        split = split_from_path(file)
        if split in @known_splits, do: "default"

      ["data" | rest] ->
        split = split_from_path(Enum.join(rest, "/"))
        if split in @known_splits, do: "default"

      [config | rest] ->
        split = split_from_path(Enum.join(rest, "/"))
        if split in @known_splits, do: config

      _ ->
        nil
    end
  end

  defp config_from_path(_), do: nil

  defp config_prefixes(nil), do: [""]
  defp config_prefixes("default"), do: [""]
  defp config_prefixes(config), do: ["#{config}/"]
end
