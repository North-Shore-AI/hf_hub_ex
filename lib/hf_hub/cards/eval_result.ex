defmodule HfHub.Cards.EvalResult do
  @moduledoc """
  Represents an evaluation result from a Model Card.
  """

  defstruct [
    :task_type,
    :task_name,
    :dataset_type,
    :dataset_name,
    :dataset_config,
    :dataset_split,
    :metric_type,
    :metric_name,
    :metric_value,
    :verified
  ]

  @type t :: %__MODULE__{
          task_type: String.t(),
          task_name: String.t() | nil,
          dataset_type: String.t(),
          dataset_name: String.t(),
          dataset_config: String.t() | nil,
          dataset_split: String.t() | nil,
          metric_type: String.t(),
          metric_name: String.t() | nil,
          metric_value: number(),
          verified: boolean()
        }

  @doc """
  Creates an EvalResult struct from a parsed map.
  """
  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      task_type: get_nested(map, ["task", "type"]) || map["task_type"],
      task_name: get_nested(map, ["task", "name"]) || map["task_name"],
      dataset_type: get_nested(map, ["dataset", "type"]) || map["dataset_type"],
      dataset_name: get_nested(map, ["dataset", "name"]) || map["dataset_name"],
      dataset_config: get_nested(map, ["dataset", "config"]) || map["dataset_config"],
      dataset_split: get_nested(map, ["dataset", "split"]) || map["dataset_split"],
      metric_type: get_metric_type(map),
      metric_name: get_metric_name(map),
      metric_value: get_metric_value(map),
      verified: map["verified"] || false
    }
  end

  def from_map(_), do: %__MODULE__{}

  defp get_nested(map, keys) do
    Enum.reduce_while(keys, map, fn key, acc ->
      case acc do
        %{^key => value} -> {:cont, value}
        _ -> {:halt, nil}
      end
    end)
  end

  defp get_metric_type(map) do
    case map["metrics"] do
      [%{"type" => type} | _] -> type
      _ -> map["metric_type"]
    end
  end

  defp get_metric_name(map) do
    case map["metrics"] do
      [%{"name" => name} | _] -> name
      _ -> map["metric_name"]
    end
  end

  defp get_metric_value(map) do
    case map["metrics"] do
      [%{"value" => value} | _] -> value
      _ -> map["metric_value"]
    end
  end
end
