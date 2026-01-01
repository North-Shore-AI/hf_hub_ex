defmodule HfHub.Users.Organization do
  @moduledoc """
  Represents a HuggingFace Hub organization profile.
  """

  defstruct [
    :name,
    :fullname,
    :avatar_url,
    :details,
    :num_members,
    :num_models,
    :num_datasets,
    :num_spaces
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          fullname: String.t() | nil,
          avatar_url: String.t() | nil,
          details: String.t() | nil,
          num_members: non_neg_integer(),
          num_models: non_neg_integer(),
          num_datasets: non_neg_integer(),
          num_spaces: non_neg_integer()
        }

  @doc """
  Creates an Organization struct from an API response map.
  """
  @spec from_response(map()) :: t()
  def from_response(response) when is_map(response) do
    %__MODULE__{
      name: get_string(response, ["name", "id"]),
      fullname: response["fullname"],
      avatar_url: get_string(response, ["avatarUrl", "avatar_url"]),
      details: response["details"],
      num_members: get_int(response, ["numMembers", "num_members"]),
      num_models: get_int(response, ["numModels", "num_models"]),
      num_datasets: get_int(response, ["numDatasets", "num_datasets"]),
      num_spaces: get_int(response, ["numSpaces", "num_spaces"])
    }
  end

  defp get_string(map, keys) do
    Enum.find_value(keys, fn key -> map[key] end)
  end

  defp get_int(map, keys) do
    Enum.find_value(keys, 0, fn key -> map[key] end)
  end
end
