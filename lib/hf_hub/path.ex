defmodule HfHub.Path do
  @moduledoc false

  @doc false
  @spec encode_repo_id(String.t()) :: String.t()
  def encode_repo_id(repo_id) when is_binary(repo_id) do
    repo_id
    |> String.split("/", parts: 2)
    |> Enum.map_join("/", &encode_segment/1)
  end

  @doc false
  @spec encode_segment(String.t()) :: String.t()
  def encode_segment(segment) when is_binary(segment) do
    URI.encode(segment, &URI.char_unreserved?/1)
  end

  @doc false
  @spec encode_path(String.t()) :: String.t()
  def encode_path(path) when is_binary(path) do
    path
    |> String.split("/")
    |> Enum.map_join("/", &encode_segment/1)
  end
end
