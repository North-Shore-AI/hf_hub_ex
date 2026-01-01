defmodule HfHub.Git.GitRefs do
  @moduledoc """
  Collection of Git refs (branches, tags, converts, pull requests) in a repository.
  """

  alias HfHub.Git.{BranchInfo, TagInfo}

  defstruct branches: [], tags: [], converts: [], pull_requests: []

  @type t :: %__MODULE__{
          branches: [BranchInfo.t()],
          tags: [TagInfo.t()],
          converts: [map()],
          pull_requests: [map()]
        }

  @doc """
  Creates a GitRefs struct from an API response.
  """
  @spec from_response(map()) :: t()
  def from_response(response) when is_map(response) do
    %__MODULE__{
      branches: parse_branches(Map.get(response, "branches", [])),
      tags: parse_tags(Map.get(response, "tags", [])),
      converts: Map.get(response, "converts", []),
      pull_requests: Map.get(response, "pullRequests", [])
    }
  end

  defp parse_branches(branches) when is_list(branches) do
    Enum.map(branches, &BranchInfo.from_response/1)
  end

  defp parse_branches(_), do: []

  defp parse_tags(tags) when is_list(tags) do
    Enum.map(tags, &TagInfo.from_response/1)
  end

  defp parse_tags(_), do: []
end
