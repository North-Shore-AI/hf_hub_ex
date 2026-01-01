defmodule HfHub.Discussions.StatusChange do
  @moduledoc """
  Represents a status change event in a discussion's history.
  """

  @derive Jason.Encoder
  defstruct [
    :id,
    :author,
    :status,
    :comment,
    :created_at
  ]

  @type status :: :open | :closed | :merged

  @type t :: %__MODULE__{
          id: String.t(),
          author: String.t(),
          status: status(),
          comment: String.t() | nil,
          created_at: DateTime.t() | nil
        }

  @doc """
  Creates a StatusChange from API response.
  """
  @spec from_response(map()) :: t()
  def from_response(response) do
    %__MODULE__{
      id: response["id"],
      author: response["author"],
      status: parse_status(response["status"] || response["newStatus"]),
      comment: response["comment"],
      created_at: parse_datetime(response["createdAt"])
    }
  end

  defp parse_status("open"), do: :open
  defp parse_status("closed"), do: :closed
  defp parse_status("merged"), do: :merged
  defp parse_status(_), do: :open

  defp parse_datetime(nil), do: nil

  defp parse_datetime(datetime_string) when is_binary(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, _} -> datetime
      _ -> nil
    end
  end

  defp parse_datetime(_), do: nil
end
