defmodule HfHub.InferenceEndpoints.ModelConfig do
  @moduledoc """
  Model configuration for an inference endpoint.
  """

  @derive Jason.Encoder
  defstruct [:repository, :framework, :task, :revision, :image]

  @type t :: %__MODULE__{
          repository: String.t() | nil,
          framework: String.t() | nil,
          task: String.t() | nil,
          revision: String.t() | nil,
          image: map() | nil
        }

  @doc """
  Creates a ModelConfig struct from an API response.
  """
  @spec from_response(map()) :: t()
  def from_response(response) when is_map(response) do
    %__MODULE__{
      repository: response["repository"],
      framework: response["framework"],
      task: response["task"],
      revision: response["revision"],
      image: response["image"]
    }
  end
end
