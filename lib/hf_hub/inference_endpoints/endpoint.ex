defmodule HfHub.InferenceEndpoints.Endpoint do
  @moduledoc """
  Inference Endpoint information.

  Represents a deployed inference endpoint with its configuration and status.
  """

  alias HfHub.InferenceEndpoints.{ComputeConfig, ModelConfig, ProviderConfig}

  @derive Jason.Encoder
  defstruct [
    :name,
    :namespace,
    :status,
    :url,
    :model,
    :compute,
    :provider,
    :type,
    :created_at,
    :updated_at
  ]

  @type status ::
          :pending
          | :initializing
          | :updating
          | :running
          | :paused
          | :failed
          | :scaled_to_zero

  @type endpoint_type :: :public | :protected | :private

  @type t :: %__MODULE__{
          name: String.t(),
          namespace: String.t() | nil,
          status: status() | nil,
          url: String.t() | nil,
          model: ModelConfig.t() | nil,
          compute: ComputeConfig.t() | nil,
          provider: ProviderConfig.t() | nil,
          type: endpoint_type() | nil,
          created_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @doc """
  Creates an Endpoint struct from an API response.
  """
  @spec from_response(map()) :: t()
  def from_response(response) when is_map(response) do
    %__MODULE__{
      name: response["name"],
      namespace: response["accountId"] || response["namespace"],
      status: parse_status(response["status"]),
      url: response["url"],
      model: parse_model(response["model"]),
      compute: parse_compute(response["compute"]),
      provider: parse_provider(response["provider"]),
      type: parse_type(response["type"]),
      created_at: parse_datetime(response["createdAt"]),
      updated_at: parse_datetime(response["updatedAt"])
    }
  end

  defp parse_status(nil), do: nil
  defp parse_status(%{"state" => state}), do: parse_status_state(state)
  defp parse_status(state) when is_binary(state), do: parse_status_state(state)

  defp parse_status_state("pending"), do: :pending
  defp parse_status_state("initializing"), do: :initializing
  defp parse_status_state("updating"), do: :updating
  defp parse_status_state("running"), do: :running
  defp parse_status_state("paused"), do: :paused
  defp parse_status_state("failed"), do: :failed
  defp parse_status_state("scaledToZero"), do: :scaled_to_zero
  defp parse_status_state(_), do: nil

  defp parse_model(nil), do: nil
  defp parse_model(model) when is_map(model), do: ModelConfig.from_response(model)

  defp parse_compute(nil), do: nil
  defp parse_compute(compute) when is_map(compute), do: ComputeConfig.from_response(compute)

  defp parse_provider(nil), do: nil
  defp parse_provider(provider) when is_map(provider), do: ProviderConfig.from_response(provider)

  defp parse_type(nil), do: nil
  defp parse_type("public"), do: :public
  defp parse_type("protected"), do: :protected
  defp parse_type("private"), do: :private
  defp parse_type(_), do: nil

  defp parse_datetime(nil), do: nil

  defp parse_datetime(datetime) when is_binary(datetime) do
    case DateTime.from_iso8601(datetime) do
      {:ok, dt, _offset} -> dt
      _ -> nil
    end
  end
end
