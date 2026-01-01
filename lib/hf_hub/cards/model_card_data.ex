defmodule HfHub.Cards.ModelCardData do
  @moduledoc """
  Structured metadata for Model Cards.

  Contains fields from the YAML frontmatter of a model's README.md.
  """

  alias HfHub.Cards.EvalResult

  defstruct [
    :language,
    :license,
    :license_name,
    :license_link,
    :library_name,
    :tags,
    :datasets,
    :metrics,
    :eval_results,
    :model_name,
    :base_model,
    :pipeline_tag,
    :widget,
    :inference,
    :co2_eq_emissions,
    :extra
  ]

  @type t :: %__MODULE__{
          language: String.t() | [String.t()] | nil,
          license: String.t() | nil,
          license_name: String.t() | nil,
          license_link: String.t() | nil,
          library_name: String.t() | nil,
          tags: [String.t()] | nil,
          datasets: [String.t()] | nil,
          metrics: [String.t()] | nil,
          eval_results: [HfHub.Cards.EvalResult.t()] | nil,
          model_name: String.t() | nil,
          base_model: String.t() | [String.t()] | nil,
          pipeline_tag: String.t() | nil,
          widget: [map()] | nil,
          inference: boolean() | map() | nil,
          co2_eq_emissions: map() | nil,
          extra: map()
        }

  @known_fields ~w[
    language license license_name license_link library_name
    tags datasets metrics eval_results model_name model-name
    base_model pipeline_tag widget inference co2_eq_emissions
  ]

  @doc """
  Creates a ModelCardData struct from a parsed YAML frontmatter map.
  """
  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      language: map["language"],
      license: map["license"],
      license_name: map["license_name"],
      license_link: map["license_link"],
      library_name: map["library_name"],
      tags: map["tags"],
      datasets: map["datasets"],
      metrics: map["metrics"],
      eval_results: parse_eval_results(map["eval_results"]),
      model_name: map["model_name"] || map["model-name"],
      base_model: map["base_model"],
      pipeline_tag: map["pipeline_tag"],
      widget: map["widget"],
      inference: map["inference"],
      co2_eq_emissions: map["co2_eq_emissions"],
      extra: Map.drop(map, @known_fields)
    }
  end

  def from_map(_), do: %__MODULE__{extra: %{}}

  defp parse_eval_results(nil), do: nil

  defp parse_eval_results(results) when is_list(results) do
    Enum.map(results, &EvalResult.from_map/1)
  end

  defp parse_eval_results(_), do: nil
end
