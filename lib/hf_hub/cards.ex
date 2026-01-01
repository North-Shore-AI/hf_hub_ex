defmodule HfHub.Cards do
  @moduledoc """
  Model and Dataset card parsing and creation.

  Cards are structured documentation files (README.md) that contain YAML frontmatter
  with metadata and markdown content for documentation.

  ## Examples

      # Load and parse cards from repositories
      {:ok, card} = HfHub.Cards.load_model_card("bert-base-uncased")
      card.data.license  # "apache-2.0"

      # Parse from content
      {:ok, card} = HfHub.Cards.parse_model_card(readme_content)

      # Create and render cards
      card = HfHub.Cards.create_model_card(%{
        language: "en",
        license: "mit",
        tags: ["text-classification"]
      })
      markdown = HfHub.Cards.render(card)
  """

  alias HfHub.Cards.{DatasetCard, DatasetCardData, ModelCard, ModelCardData}
  alias HfHub.Download

  @doc """
  Loads a model card from a repository.

  Downloads the README.md file and parses its frontmatter and content.

  ## Arguments

    * `repo_id` - Repository ID (e.g., "bert-base-uncased")

  ## Options

    * `:revision` - Git revision. Defaults to `"main"`.
    * `:token` - Authentication token.
    * `:cache_dir` - Local cache directory.

  ## Examples

      {:ok, card} = HfHub.Cards.load_model_card("bert-base-uncased")
      card.data.license  # "apache-2.0"
      card.data.tags     # ["pytorch", "bert", "fill-mask"]
  """
  @spec load_model_card(String.t(), keyword()) :: {:ok, ModelCard.t()} | {:error, term()}
  def load_model_card(repo_id, opts \\ []) do
    download_opts =
      opts
      |> Keyword.put(:repo_id, repo_id)
      |> Keyword.put(:filename, "README.md")
      |> Keyword.put(:repo_type, :model)

    with {:ok, readme_path} <- Download.hf_hub_download(download_opts),
         {:ok, content} <- File.read(readme_path) do
      parse_model_card(content)
    end
  end

  @doc """
  Loads a dataset card from a repository.

  Downloads the README.md file and parses its frontmatter and content.

  ## Arguments

    * `repo_id` - Dataset repository ID (e.g., "squad")

  ## Options

    * `:revision` - Git revision. Defaults to `"main"`.
    * `:token` - Authentication token.
    * `:cache_dir` - Local cache directory.

  ## Examples

      {:ok, card} = HfHub.Cards.load_dataset_card("squad")
      card.data.task_categories  # ["question-answering"]
  """
  @spec load_dataset_card(String.t(), keyword()) :: {:ok, DatasetCard.t()} | {:error, term()}
  def load_dataset_card(repo_id, opts \\ []) do
    download_opts =
      opts
      |> Keyword.put(:repo_id, repo_id)
      |> Keyword.put(:filename, "README.md")
      |> Keyword.put(:repo_type, :dataset)

    with {:ok, readme_path} <- Download.hf_hub_download(download_opts),
         {:ok, content} <- File.read(readme_path) do
      parse_dataset_card(content)
    end
  end

  @doc """
  Parses a model card from markdown content.

  Extracts YAML frontmatter and remaining markdown content.

  ## Arguments

    * `content` - Raw markdown content with optional YAML frontmatter

  ## Examples

      content = \"""
      ---
      license: mit
      tags:
        - bert
      ---

      # My Model
      \"""

      {:ok, card} = HfHub.Cards.parse_model_card(content)
      card.data.license  # "mit"
      card.content       # "# My Model"
  """
  @spec parse_model_card(String.t()) :: {:ok, ModelCard.t()} | {:error, term()}
  def parse_model_card(content) when is_binary(content) do
    case extract_frontmatter(content) do
      {:ok, {frontmatter, body}} ->
        {:ok,
         %ModelCard{
           data: ModelCardData.from_map(frontmatter),
           content: body
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Parses a dataset card from markdown content.

  Extracts YAML frontmatter and remaining markdown content.

  ## Arguments

    * `content` - Raw markdown content with optional YAML frontmatter

  ## Examples

      {:ok, card} = HfHub.Cards.parse_dataset_card(content)
      card.data.task_categories  # ["question-answering"]
  """
  @spec parse_dataset_card(String.t()) :: {:ok, DatasetCard.t()} | {:error, term()}
  def parse_dataset_card(content) when is_binary(content) do
    case extract_frontmatter(content) do
      {:ok, {frontmatter, body}} ->
        {:ok,
         %DatasetCard{
           data: DatasetCardData.from_map(frontmatter),
           content: body
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Creates a model card from data.

  ## Arguments

    * `data` - Map or keyword list with card data fields

  ## Examples

      card = HfHub.Cards.create_model_card(%{
        language: "en",
        license: "mit",
        tags: ["text-classification"]
      })
  """
  @spec create_model_card(map() | keyword()) :: ModelCard.t()
  def create_model_card(data) when is_map(data) do
    %ModelCard{
      data: struct(ModelCardData, Map.put(data, :extra, %{})),
      content: ""
    }
  end

  def create_model_card(data) when is_list(data) do
    create_model_card(Map.new(data))
  end

  @doc """
  Creates a dataset card from data.

  ## Arguments

    * `data` - Map or keyword list with card data fields

  ## Examples

      card = HfHub.Cards.create_dataset_card(%{
        language: "en",
        license: "cc-by-4.0",
        task_categories: ["question-answering"]
      })
  """
  @spec create_dataset_card(map() | keyword()) :: DatasetCard.t()
  def create_dataset_card(data) when is_map(data) do
    %DatasetCard{
      data: struct(DatasetCardData, Map.put(data, :extra, %{})),
      content: ""
    }
  end

  def create_dataset_card(data) when is_list(data) do
    create_dataset_card(Map.new(data))
  end

  @doc """
  Renders a card to markdown string with YAML frontmatter.

  ## Arguments

    * `card` - A ModelCard or DatasetCard struct

  ## Examples

      card = HfHub.Cards.create_model_card(%{license: "mit"})
      markdown = HfHub.Cards.render(card)
      # => \"\"\"
      # ---
      # license: "mit"
      # ---
      #
      # \"\"\"
  """
  @spec render(ModelCard.t() | DatasetCard.t()) :: String.t()
  def render(%{data: data, content: content}) do
    yaml =
      data
      |> Map.from_struct()
      |> Enum.reject(fn {k, v} -> is_nil(v) or k == :extra or v == %{} end)
      |> Map.new()
      |> Map.merge(Map.get(data, :extra) || %{})
      |> to_yaml()

    if yaml == "" do
      content
    else
      """
      ---
      #{yaml}---

      #{content}
      """
    end
  end

  # Frontmatter parsing

  @doc false
  @spec extract_frontmatter(String.t()) :: {:ok, {map(), String.t()}} | {:error, term()}
  def extract_frontmatter(content) when is_binary(content) do
    # Handle empty frontmatter (---\n---) separately
    case Regex.run(~r/\A---\r?\n---\r?\n?(.*)/s, content) do
      [_, body] ->
        {:ok, {%{}, String.trim(body)}}

      nil ->
        # Try to match frontmatter with content
        case Regex.run(~r/\A---\r?\n(.*?)\r?\n---\r?\n?(.*)/s, content) do
          [_, yaml, body] ->
            parse_yaml(yaml, body)

          nil ->
            # No frontmatter
            {:ok, {%{}, String.trim(content)}}
        end
    end
  end

  defp parse_yaml(yaml, body) do
    case YamlElixir.read_from_string(yaml) do
      {:ok, frontmatter} when is_map(frontmatter) ->
        {:ok, {frontmatter, String.trim(body)}}

      {:ok, _} ->
        # YAML parsed but not a map
        {:ok, {%{}, String.trim(body)}}

      {:error, reason} ->
        {:error, {:yaml_parse_error, reason}}
    end
  end

  defp to_yaml(map) when map_size(map) == 0, do: ""

  defp to_yaml(map) do
    yaml =
      map
      |> Enum.sort_by(fn {k, _} -> to_string(k) end)
      |> Enum.map_join("\n", fn {k, v} -> "#{k}: #{yaml_value(v)}" end)

    yaml <> "\n"
  end

  defp yaml_value(v) when is_binary(v) do
    if needs_quoting?(v), do: inspect(v), else: v
  end

  defp yaml_value(v) when is_list(v) do
    items = Enum.map_join(v, "\n", &"  - #{yaml_value(&1)}")
    "\n#{items}"
  end

  defp yaml_value(v) when is_boolean(v), do: to_string(v)
  defp yaml_value(v) when is_number(v), do: to_string(v)
  defp yaml_value(v) when is_atom(v), do: to_string(v)
  defp yaml_value(v) when is_map(v), do: inspect(v)

  defp needs_quoting?(s) do
    String.contains?(s, ["\n", ":", "#", "'", "\"", "[", "]", "{", "}"]) or
      String.starts_with?(s, [" ", "-"]) or
      String.ends_with?(s, " ")
  end
end
