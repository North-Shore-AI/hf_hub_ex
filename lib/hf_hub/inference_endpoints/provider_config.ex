defmodule HfHub.InferenceEndpoints.ProviderConfig do
  @moduledoc """
  Cloud provider configuration for an inference endpoint.
  """

  @derive Jason.Encoder
  defstruct [:vendor, :region]

  @type vendor :: :aws | :azure | :gcp

  @type t :: %__MODULE__{
          vendor: vendor() | nil,
          region: String.t() | nil
        }

  @doc """
  Creates a ProviderConfig struct from an API response.
  """
  @spec from_response(map()) :: t()
  def from_response(response) when is_map(response) do
    %__MODULE__{
      vendor: parse_vendor(response["vendor"]),
      region: response["region"]
    }
  end

  defp parse_vendor(nil), do: nil
  defp parse_vendor("aws"), do: :aws
  defp parse_vendor("azure"), do: :azure
  defp parse_vendor("gcp"), do: :gcp
  defp parse_vendor(_), do: nil
end
