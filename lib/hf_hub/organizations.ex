defmodule HfHub.Organizations do
  @moduledoc """
  Organization profile API.

  Provides functions to interact with HuggingFace Hub organization profiles
  and member listings.

  ## Examples

      # Get organization profile
      {:ok, org} = HfHub.Organizations.get("huggingface")
      IO.inspect(org.num_models)

      # List members
      {:ok, members} = HfHub.Organizations.list_members("huggingface")
  """

  alias HfHub.HTTP
  alias HfHub.Users.{Organization, User}

  @doc """
  Gets an organization's public profile.

  ## Arguments

    * `org_name` - The organization name

  ## Options

    * `:token` - Authentication token

  ## Examples

      {:ok, org} = HfHub.Organizations.get("huggingface")
      IO.inspect(org.name)         # "huggingface"
      IO.inspect(org.num_models)   # 1000+
  """
  @spec get(String.t(), keyword()) :: {:ok, Organization.t()} | {:error, term()}
  def get(org_name, opts \\ []) do
    token = opts[:token]

    case HTTP.get("/api/organizations/#{encode(org_name)}", token: token) do
      {:ok, response} -> {:ok, Organization.from_response(response)}
      error -> error
    end
  end

  @doc """
  Lists members of an organization.

  ## Arguments

    * `org_name` - The organization name

  ## Options

    * `:token` - Authentication token

  ## Examples

      {:ok, members} = HfHub.Organizations.list_members("huggingface")
      Enum.each(members, &IO.inspect(&1.username))
  """
  @spec list_members(String.t(), keyword()) :: {:ok, [User.t()]} | {:error, term()}
  def list_members(org_name, opts \\ []) do
    token = opts[:token]

    case HTTP.get("/api/organizations/#{encode(org_name)}/members", token: token) do
      {:ok, members} when is_list(members) ->
        {:ok, Enum.map(members, &User.from_response/1)}

      {:ok, _} ->
        {:error, :invalid_response}

      error ->
        error
    end
  end

  # Private helpers

  defp encode(s), do: URI.encode(s, &URI.char_unreserved?/1)
end
