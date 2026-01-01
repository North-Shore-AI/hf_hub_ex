defmodule HfHub.Webhooks.WebhookInfo do
  @moduledoc """
  Represents a webhook configuration on HuggingFace Hub.

  Webhooks enable automated notifications when events occur on repositories.
  """

  alias HfHub.Webhooks.WatchedItem

  @derive Jason.Encoder
  defstruct [
    :id,
    :url,
    :watched,
    :domains,
    :secret,
    :disabled,
    :created_at
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          url: String.t(),
          watched: [WatchedItem.t()],
          domains: [:repo | :discussion],
          secret: String.t() | nil,
          disabled: boolean(),
          created_at: DateTime.t() | nil
        }

  @doc """
  Creates a WebhookInfo from API response.
  """
  @spec from_response(map()) :: t()
  def from_response(response) do
    %__MODULE__{
      id: response["id"],
      url: response["url"],
      watched: parse_watched(response["watched"]),
      domains: parse_domains(response["domains"]),
      secret: response["secret"],
      disabled: response["disabled"] || false,
      created_at: parse_datetime(response["createdAt"])
    }
  end

  defp parse_watched(nil), do: []

  defp parse_watched(watched) when is_list(watched) do
    Enum.map(watched, &WatchedItem.from_response/1)
  end

  defp parse_domains(nil), do: []

  defp parse_domains(domains) when is_list(domains) do
    Enum.map(domains, &String.to_atom/1)
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(datetime_string) when is_binary(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, _} -> datetime
      _ -> nil
    end
  end

  defp parse_datetime(_), do: nil
end
