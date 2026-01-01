defmodule HfHub.Collections.Collection do
  @moduledoc """
  Represents a collection on HuggingFace Hub.

  Collections enable organizing and curating lists of models, datasets, and spaces.
  """

  alias HfHub.Collections.CollectionItem

  @derive Jason.Encoder
  defstruct [
    :slug,
    :title,
    :description,
    :owner,
    :private,
    :items,
    :upvotes,
    :created_at,
    :updated_at,
    :theme,
    :position
  ]

  @type t :: %__MODULE__{
          slug: String.t(),
          title: String.t(),
          description: String.t() | nil,
          owner: String.t(),
          private: boolean(),
          items: [CollectionItem.t()],
          upvotes: non_neg_integer(),
          created_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil,
          theme: String.t() | nil,
          position: non_neg_integer() | nil
        }

  @doc """
  Creates a Collection from API response.
  """
  @spec from_response(map()) :: t()
  def from_response(response) do
    %__MODULE__{
      slug: response["slug"],
      title: response["title"],
      description: response["description"],
      owner: get_owner(response),
      private: response["private"] || false,
      items: parse_items(response["items"]),
      upvotes: response["upvotes"] || 0,
      created_at: parse_datetime(response["createdAt"]),
      updated_at: parse_datetime(response["updatedAt"]),
      theme: response["theme"],
      position: response["position"]
    }
  end

  defp get_owner(%{"owner" => %{"name" => name}}), do: name
  defp get_owner(%{"owner" => owner}) when is_binary(owner), do: owner
  defp get_owner(_), do: nil

  defp parse_items(nil), do: []
  defp parse_items(items) when is_list(items), do: Enum.map(items, &CollectionItem.from_response/1)

  defp parse_datetime(nil), do: nil

  defp parse_datetime(datetime_string) when is_binary(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, _} -> datetime
      _ -> nil
    end
  end

  defp parse_datetime(_), do: nil
end
