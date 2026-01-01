defmodule HfHub.Spaces.SpaceVariable do
  @moduledoc """
  A Space environment variable.
  """

  @derive Jason.Encoder
  defstruct [:key, :value, :description, :updated_at]

  @type t :: %__MODULE__{
          key: String.t(),
          value: String.t() | nil,
          description: String.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @doc """
  Create a SpaceVariable struct from an API response.
  """
  @spec from_response(String.t(), map() | String.t()) :: t()
  def from_response(key, response) when is_map(response) do
    %__MODULE__{
      key: key,
      value: response["value"],
      description: response["description"],
      updated_at: parse_datetime(response["updatedAt"])
    }
  end

  def from_response(key, value) when is_binary(value) do
    %__MODULE__{
      key: key,
      value: value,
      description: nil,
      updated_at: nil
    }
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(datetime_string) when is_binary(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, _offset} -> datetime
      _ -> nil
    end
  end
end
