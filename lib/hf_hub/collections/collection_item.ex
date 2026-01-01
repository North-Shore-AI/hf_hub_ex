defmodule HfHub.Collections.CollectionItem do
  @moduledoc """
  Represents an item within a collection.

  Items can be models, datasets, spaces, or papers.
  """

  @derive Jason.Encoder
  defstruct [:id, :item_id, :item_type, :note, :position, :added_at]

  @type item_type :: :model | :dataset | :space | :paper

  @type t :: %__MODULE__{
          id: String.t(),
          item_id: String.t(),
          item_type: item_type(),
          note: String.t() | nil,
          position: non_neg_integer(),
          added_at: DateTime.t() | nil
        }

  @doc """
  Creates a CollectionItem from API response.
  """
  @spec from_response(map()) :: t()
  def from_response(response) do
    %__MODULE__{
      id: response["_id"] || response["id"],
      item_id: response["itemId"] || response["item_id"],
      item_type: parse_item_type(response["itemType"] || response["item_type"] || response["type"]),
      note: response["note"],
      position: response["position"] || 0,
      added_at: parse_datetime(response["addedAt"] || response["createdAt"])
    }
  end

  defp parse_item_type("model"), do: :model
  defp parse_item_type("dataset"), do: :dataset
  defp parse_item_type("space"), do: :space
  defp parse_item_type("paper"), do: :paper
  defp parse_item_type(_), do: :model

  defp parse_datetime(nil), do: nil

  defp parse_datetime(datetime_string) when is_binary(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, _} -> datetime
      _ -> nil
    end
  end

  defp parse_datetime(_), do: nil
end
