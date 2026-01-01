defmodule HfHub.Users.User do
  @moduledoc """
  Represents a HuggingFace Hub user profile.
  """

  defstruct [
    :username,
    :fullname,
    :avatar_url,
    :details,
    :is_following,
    :num_followers,
    :num_following,
    :num_models,
    :num_datasets,
    :num_spaces,
    :num_likes
  ]

  @type t :: %__MODULE__{
          username: String.t(),
          fullname: String.t() | nil,
          avatar_url: String.t() | nil,
          details: String.t() | nil,
          is_following: boolean() | nil,
          num_followers: non_neg_integer(),
          num_following: non_neg_integer(),
          num_models: non_neg_integer(),
          num_datasets: non_neg_integer(),
          num_spaces: non_neg_integer(),
          num_likes: non_neg_integer()
        }

  @doc """
  Creates a User struct from an API response map.
  """
  @spec from_response(map()) :: t()
  def from_response(response) when is_map(response) do
    %__MODULE__{
      username: get_string(response, ["user", "username", "name"]),
      fullname: response["fullname"],
      avatar_url: get_string(response, ["avatarUrl", "avatar_url"]),
      details: response["details"],
      is_following: get_bool(response, ["isFollowing", "is_following"]),
      num_followers: get_int(response, ["numFollowers", "num_followers"]),
      num_following: get_int(response, ["numFollowing", "num_following"]),
      num_models: get_int(response, ["numModels", "num_models"]),
      num_datasets: get_int(response, ["numDatasets", "num_datasets"]),
      num_spaces: get_int(response, ["numSpaces", "num_spaces"]),
      num_likes: get_int(response, ["numLikes", "num_likes"])
    }
  end

  defp get_string(map, keys) do
    Enum.find_value(keys, fn key -> map[key] end)
  end

  defp get_bool(map, keys) do
    Enum.find_value(keys, fn key -> map[key] end)
  end

  defp get_int(map, keys) do
    Enum.find_value(keys, 0, fn key -> map[key] end)
  end
end
