defmodule HfHub.Discussions.Discussion do
  @moduledoc """
  Represents a discussion or pull request summary.

  This struct contains basic information about a discussion as returned
  from the list endpoint.
  """

  @derive Jason.Encoder
  defstruct [
    :num,
    :title,
    :author,
    :status,
    :is_pull_request,
    :created_at,
    :updated_at,
    :num_comments
  ]

  @type status :: :open | :closed | :merged | :draft

  @type t :: %__MODULE__{
          num: non_neg_integer(),
          title: String.t(),
          author: String.t(),
          status: status(),
          is_pull_request: boolean(),
          created_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil,
          num_comments: non_neg_integer()
        }

  @doc """
  Creates a Discussion from API response.
  """
  @spec from_response(map()) :: t()
  def from_response(response) do
    %__MODULE__{
      num: response["num"],
      title: response["title"],
      author: response["author"],
      status: parse_status(response["status"]),
      is_pull_request: response["isPullRequest"] || response["is_pull_request"] || false,
      created_at: parse_datetime(response["createdAt"]),
      updated_at: parse_datetime(response["updatedAt"]),
      num_comments: response["numComments"] || 0
    }
  end

  defp parse_status("open"), do: :open
  defp parse_status("closed"), do: :closed
  defp parse_status("merged"), do: :merged
  defp parse_status("draft"), do: :draft
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
