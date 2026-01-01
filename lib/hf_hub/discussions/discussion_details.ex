defmodule HfHub.Discussions.DiscussionDetails do
  @moduledoc """
  Detailed information about a discussion or pull request.

  Includes the full event history (comments, status changes, title changes).
  """

  alias HfHub.Discussions.{Comment, StatusChange, TitleChange}

  @derive Jason.Encoder
  defstruct [
    :num,
    :title,
    :author,
    :status,
    :is_pull_request,
    :created_at,
    :updated_at,
    :events,
    :target_branch,
    :head_sha,
    :merge_commit_oid
  ]

  @type status :: :open | :closed | :merged | :draft

  @type event :: Comment.t() | StatusChange.t() | TitleChange.t()

  @type t :: %__MODULE__{
          num: non_neg_integer(),
          title: String.t(),
          author: String.t(),
          status: status(),
          is_pull_request: boolean(),
          created_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil,
          events: [event()],
          target_branch: String.t() | nil,
          head_sha: String.t() | nil,
          merge_commit_oid: String.t() | nil
        }

  @doc """
  Creates DiscussionDetails from API response.
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
      events: parse_events(response["events"] || []),
      target_branch: response["targetBranch"],
      head_sha: response["headSha"],
      merge_commit_oid: response["mergeCommitOid"]
    }
  end

  defp parse_status("open"), do: :open
  defp parse_status("closed"), do: :closed
  defp parse_status("merged"), do: :merged
  defp parse_status("draft"), do: :draft
  defp parse_status(_), do: :open

  defp parse_events(events) when is_list(events) do
    Enum.map(events, &parse_event/1)
  end

  defp parse_events(_), do: []

  defp parse_event(%{"type" => "comment"} = event), do: Comment.from_response(event)
  defp parse_event(%{"type" => "status-change"} = event), do: StatusChange.from_response(event)
  defp parse_event(%{"type" => "title-change"} = event), do: TitleChange.from_response(event)

  # Fall back to comment for unknown types with content
  defp parse_event(%{"content" => _} = event), do: Comment.from_response(event)

  # Default fallback
  defp parse_event(event), do: Comment.from_response(event)

  defp parse_datetime(nil), do: nil

  defp parse_datetime(datetime_string) when is_binary(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, _} -> datetime
      _ -> nil
    end
  end

  defp parse_datetime(_), do: nil
end
