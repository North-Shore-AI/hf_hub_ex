defmodule HfHub.Discussions.TitleChange do
  @moduledoc """
  Represents a title change event in a discussion's history.
  """

  @derive Jason.Encoder
  defstruct [
    :id,
    :author,
    :old_title,
    :new_title,
    :created_at
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          author: String.t(),
          old_title: String.t(),
          new_title: String.t(),
          created_at: DateTime.t() | nil
        }

  @doc """
  Creates a TitleChange from API response.
  """
  @spec from_response(map()) :: t()
  def from_response(response) do
    %__MODULE__{
      id: response["id"],
      author: response["author"],
      old_title: response["oldTitle"],
      new_title: response["newTitle"],
      created_at: parse_datetime(response["createdAt"])
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
