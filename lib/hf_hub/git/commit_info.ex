defmodule HfHub.Git.CommitInfo do
  @moduledoc """
  Information about a Git commit in a HuggingFace repository.
  """

  defstruct [:id, :title, :message, :authors, :date]

  @type author :: %{name: String.t(), email: String.t()}

  @type t :: %__MODULE__{
          id: String.t(),
          title: String.t() | nil,
          message: String.t() | nil,
          authors: [author()],
          date: DateTime.t() | nil
        }

  @doc """
  Creates a CommitInfo struct from an API response.
  """
  @spec from_response(map()) :: t()
  def from_response(response) when is_map(response) do
    %__MODULE__{
      id: Map.get(response, "id"),
      title: Map.get(response, "title"),
      message: Map.get(response, "message"),
      authors: parse_authors(Map.get(response, "authors", [])),
      date: parse_datetime(Map.get(response, "date"))
    }
  end

  defp parse_authors(authors) when is_list(authors) do
    Enum.map(authors, fn author ->
      %{
        name: Map.get(author, "name", ""),
        email: Map.get(author, "email", "")
      }
    end)
  end

  defp parse_authors(_), do: []

  defp parse_datetime(nil), do: nil

  defp parse_datetime(datetime_string) when is_binary(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, _} -> datetime
      _ -> nil
    end
  end

  defp parse_datetime(_), do: nil
end
