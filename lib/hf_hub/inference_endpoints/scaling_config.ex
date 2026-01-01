defmodule HfHub.InferenceEndpoints.ScalingConfig do
  @moduledoc """
  Scaling configuration for an inference endpoint.
  """

  @derive Jason.Encoder
  defstruct [:min_replica, :max_replica, :scale_to_zero_timeout]

  @type t :: %__MODULE__{
          min_replica: non_neg_integer() | nil,
          max_replica: pos_integer() | nil,
          scale_to_zero_timeout: non_neg_integer() | nil
        }

  @doc """
  Creates a ScalingConfig struct from an API response.
  """
  @spec from_response(map()) :: t()
  def from_response(response) when is_map(response) do
    %__MODULE__{
      min_replica: response["minReplica"],
      max_replica: response["maxReplica"],
      scale_to_zero_timeout: response["scaleToZeroTimeout"]
    }
  end
end
