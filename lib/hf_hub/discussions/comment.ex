defmodule HfHub.Discussions.Comment do
  @moduledoc """
  Represents a comment on a discussion or pull request.
  """

  @derive Jason.Encoder
  defstruct [
    :id,
    :author,
    :content,
    :hidden,
    :created_at,
    :updated_at,
    :edited
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          author: String.t(),
          content: String.t(),
          hidden: boolean(),
          created_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil,
          edited: boolean()
        }

  @doc """
  Creates a Comment from API response.
  """
  @spec from_response(map()) :: t()
  def from_response(response) do
    %__MODULE__{
      id: response["id"],
      author: response["author"],
      content: response["content"],
      hidden: response["hidden"] || false,
      created_at: parse_datetime(response["createdAt"]),
      updated_at: parse_datetime(response["updatedAt"]),
      edited: response["edited"] || false
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
