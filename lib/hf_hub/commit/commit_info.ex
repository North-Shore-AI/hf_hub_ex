defmodule HfHub.Commit.CommitInfo do
  @moduledoc """
  Information about a completed commit.

  Returned after successfully committing changes to a repository.
  """

  @derive Jason.Encoder
  defstruct [
    :commit_url,
    :commit_message,
    :commit_description,
    :oid,
    :pr_url,
    :pr_num,
    :pr_revision,
    :repo_url
  ]

  @type t :: %__MODULE__{
          commit_url: String.t(),
          commit_message: String.t(),
          commit_description: String.t() | nil,
          oid: String.t(),
          pr_url: String.t() | nil,
          pr_num: non_neg_integer() | nil,
          pr_revision: String.t() | nil,
          repo_url: String.t()
        }

  @doc """
  Creates CommitInfo from API response.
  """
  @spec from_response(map()) :: t()
  def from_response(response) do
    %__MODULE__{
      commit_url: response["commitUrl"],
      commit_message: response["commitMessage"],
      commit_description: response["commitDescription"],
      oid: response["commitOid"],
      pr_url: get_in(response, ["pullRequest", "url"]),
      pr_num: get_in(response, ["pullRequest", "num"]),
      pr_revision: get_in(response, ["pullRequest", "revision"]),
      repo_url: response["repoUrl"]
    }
  end
end
