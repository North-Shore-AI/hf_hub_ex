defmodule HfHub.AccessRequests.AccessRequest do
  @moduledoc """
  Represents an access request for a gated repository.

  This struct contains information about a user's request to access
  a gated model, dataset, or space.
  """

  @derive Jason.Encoder
  defstruct [:user, :fullname, :email, :status, :timestamp, :fields]

  @type status :: :pending | :accepted | :rejected

  @type t :: %__MODULE__{
          user: String.t(),
          fullname: String.t() | nil,
          email: String.t() | nil,
          status: status(),
          timestamp: DateTime.t() | nil,
          fields: map()
        }

  @doc """
  Creates an AccessRequest from API response.
  """
  @spec from_response(map(), status()) :: t()
  def from_response(response, status) do
    %__MODULE__{
      user: response["user"] || response["username"],
      fullname: response["fullname"],
      email: response["email"],
      status: status,
      timestamp: parse_datetime(response["timestamp"]),
      fields: response["fields"] || %{}
    }
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(datetime_string) when is_binary(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, _} -> datetime
      _ -> nil
    end
  end

  defp parse_datetime(_), do: nil
end
