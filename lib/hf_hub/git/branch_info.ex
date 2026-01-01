defmodule HfHub.Git.BranchInfo do
  @moduledoc """
  Information about a Git branch in a HuggingFace repository.
  """

  defstruct [:name, :ref, :target_commit]

  @type t :: %__MODULE__{
          name: String.t(),
          ref: String.t() | nil,
          target_commit: String.t() | nil
        }

  @doc """
  Creates a BranchInfo struct from an API response.
  """
  @spec from_response(map()) :: t()
  def from_response(response) when is_map(response) do
    %__MODULE__{
      name: Map.get(response, "name"),
      ref: Map.get(response, "ref"),
      target_commit: Map.get(response, "targetCommit")
    }
  end
end
