defmodule HfHub.Webhooks.WatchedItem do
  @moduledoc """
  Represents a watched item in a webhook configuration.

  A watched item specifies a repository or entity to monitor for events.
  """

  @derive Jason.Encoder
  defstruct [:type, :name]

  @type item_type :: :model | :dataset | :space | :user | :org
  @type t :: %__MODULE__{
          type: item_type(),
          name: String.t()
        }

  @doc """
  Creates a WatchedItem from API response.
  """
  @spec from_response(map()) :: t()
  def from_response(response) do
    %__MODULE__{
      type: parse_type(response["type"]),
      name: response["name"]
    }
  end

  defp parse_type(type) when is_binary(type), do: String.to_atom(type)
  defp parse_type(_), do: nil
end
