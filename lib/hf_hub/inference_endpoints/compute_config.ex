defmodule HfHub.InferenceEndpoints.ComputeConfig do
  @moduledoc """
  Compute configuration for an inference endpoint.
  """

  alias HfHub.InferenceEndpoints.ScalingConfig

  @derive Jason.Encoder
  defstruct [:accelerator, :instance_size, :instance_type, :scaling]

  @type accelerator :: :cpu | :gpu

  @type t :: %__MODULE__{
          accelerator: accelerator() | nil,
          instance_size: String.t() | nil,
          instance_type: String.t() | nil,
          scaling: ScalingConfig.t() | nil
        }

  @doc """
  Creates a ComputeConfig struct from an API response.
  """
  @spec from_response(map()) :: t()
  def from_response(response) when is_map(response) do
    %__MODULE__{
      accelerator: parse_accelerator(response["accelerator"]),
      instance_size: response["instanceSize"],
      instance_type: response["instanceType"],
      scaling: parse_scaling(response["scaling"])
    }
  end

  defp parse_accelerator(nil), do: nil
  defp parse_accelerator("cpu"), do: :cpu
  defp parse_accelerator("gpu"), do: :gpu
  defp parse_accelerator(_), do: nil

  defp parse_scaling(nil), do: nil
  defp parse_scaling(scaling) when is_map(scaling), do: ScalingConfig.from_response(scaling)
end
