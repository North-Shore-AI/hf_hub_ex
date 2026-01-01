defmodule HfHub.Cards.DatasetCardData do
  @moduledoc """
  Structured metadata for Dataset Cards.

  Contains fields from the YAML frontmatter of a dataset's README.md.
  """

  defstruct [
    :language,
    :license,
    :annotations_creators,
    :language_creators,
    :multilinguality,
    :size_categories,
    :source_datasets,
    :task_categories,
    :task_ids,
    :pretty_name,
    :configs,
    :tags,
    :extra
  ]

  @type t :: %__MODULE__{
          language: String.t() | [String.t()] | nil,
          license: String.t() | nil,
          annotations_creators: [String.t()] | nil,
          language_creators: [String.t()] | nil,
          multilinguality: String.t() | nil,
          size_categories: [String.t()] | nil,
          source_datasets: [String.t()] | nil,
          task_categories: [String.t()] | nil,
          task_ids: [String.t()] | nil,
          pretty_name: String.t() | nil,
          configs: [map()] | nil,
          tags: [String.t()] | nil,
          extra: map()
        }

  @known_fields ~w[
    language license annotations_creators language_creators
    multilinguality size_categories source_datasets
    task_categories task_ids pretty_name configs tags
  ]

  @doc """
  Creates a DatasetCardData struct from a parsed YAML frontmatter map.
  """
  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      language: map["language"],
      license: map["license"],
      annotations_creators: map["annotations_creators"],
      language_creators: map["language_creators"],
      multilinguality: map["multilinguality"],
      size_categories: map["size_categories"],
      source_datasets: map["source_datasets"],
      task_categories: map["task_categories"],
      task_ids: map["task_ids"],
      pretty_name: map["pretty_name"],
      configs: map["configs"],
      tags: map["tags"],
      extra: Map.drop(map, @known_fields)
    }
  end

  def from_map(_), do: %__MODULE__{extra: %{}}
end
