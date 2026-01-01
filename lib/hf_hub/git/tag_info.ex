defmodule HfHub.Git.TagInfo do
  @moduledoc """
  Information about a Git tag in a HuggingFace repository.
  """

  defstruct [:name, :ref, :target_commit, :message]

  @type t :: %__MODULE__{
          name: String.t(),
          ref: String.t() | nil,
          target_commit: String.t() | nil,
          message: String.t() | nil
        }

  @doc """
  Creates a TagInfo struct from an API response.
  """
  @spec from_response(map()) :: t()
  def from_response(response) when is_map(response) do
    %__MODULE__{
      name: Map.get(response, "name"),
      ref: Map.get(response, "ref"),
      target_commit: Map.get(response, "targetCommit"),
      message: Map.get(response, "message")
    }
  end
end
