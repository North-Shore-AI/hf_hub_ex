defmodule HfHub.Spaces.SpaceRuntime do
  @moduledoc """
  Runtime information for a HuggingFace Space.
  """

  @derive Jason.Encoder
  defstruct [
    :stage,
    :hardware,
    :requested_hardware,
    :sleep_time,
    :sdk,
    :sdk_version,
    :storage,
    :raw_logs
  ]

  @type stage ::
          :building | :running | :paused | :sleeping | :stopped | :runtime_error | :no_app_file

  @type t :: %__MODULE__{
          stage: stage() | nil,
          hardware: String.t() | nil,
          requested_hardware: String.t() | nil,
          sleep_time: integer() | nil,
          sdk: String.t() | nil,
          sdk_version: String.t() | nil,
          storage: String.t() | nil,
          raw_logs: boolean() | nil
        }

  @doc """
  Create a SpaceRuntime struct from an API response.
  """
  @spec from_response(map()) :: t()
  def from_response(response) when is_map(response) do
    %__MODULE__{
      stage: parse_stage(response["stage"]),
      hardware: get_in(response, ["hardware", "current"]),
      requested_hardware: get_in(response, ["hardware", "requested"]),
      sleep_time: response["gcTimeout"],
      sdk: response["sdk"],
      sdk_version: response["sdkVersion"],
      storage: response["storage"],
      raw_logs: response["rawLogs"]
    }
  end

  defp parse_stage("BUILDING"), do: :building
  defp parse_stage("RUNNING"), do: :running
  defp parse_stage("PAUSED"), do: :paused
  defp parse_stage("SLEEPING"), do: :sleeping
  defp parse_stage("STOPPED"), do: :stopped
  defp parse_stage("RUNTIME_ERROR"), do: :runtime_error
  defp parse_stage("NO_APP_FILE"), do: :no_app_file
  defp parse_stage(_), do: nil
end
