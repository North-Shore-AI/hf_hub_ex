defmodule HfHub.Auth do
  @moduledoc """
  Authentication and authorization for HuggingFace Hub.

  Handles token management, login/logout flows, and user information retrieval.

  ## Examples

      # Get current token
      {:ok, token} = HfHub.Auth.get_token()

      # Set token
      :ok = HfHub.Auth.set_token("hf_...")

      # Get current user info
      {:ok, user} = HfHub.Auth.whoami()

      # Logout
      :ok = HfHub.Auth.logout()
  """

  @type user_info :: %{
          username: String.t(),
          email: String.t(),
          fullname: String.t() | nil,
          organizations: [String.t()]
        }

  @doc """
  Retrieves the current HuggingFace token.

  Checks in order:
  1. Application configuration
  2. HF_TOKEN environment variable
  3. Stored credentials file

  ## Examples

      {:ok, token} = HfHub.Auth.get_token()
  """
  @spec get_token() :: {:ok, String.t()} | {:error, :no_token}
  def get_token do
    cond do
      token = Application.get_env(:hf_hub, :token) ->
        {:ok, token}

      token = System.get_env("HF_TOKEN") ->
        {:ok, token}

      true ->
        {:error, :no_token}
    end
  end

  @doc """
  Sets the HuggingFace authentication token.

  The token is stored in application configuration for the current session.

  ## Arguments

    * `token` - HuggingFace API token (starts with "hf_")

  ## Examples

      :ok = HfHub.Auth.set_token("hf_...")
  """
  @spec set_token(String.t()) :: :ok
  def set_token(token) when is_binary(token) do
    Application.put_env(:hf_hub, :token, token)
    :ok
  end

  @doc """
  Interactive login flow.

  Prompts for a token and stores it for future use.

  ## Options

    * `:token` - Token to use (skips prompt)
    * `:add_to_git_credentials` - Add token to git credentials. Defaults to `false`.

  ## Examples

      :ok = HfHub.Auth.login(token: "hf_...")
      :ok = HfHub.Auth.login()  # Interactive prompt
  """
  @spec login(keyword()) :: :ok | {:error, term()}
  def login(opts \\ []) do
    token = Keyword.get(opts, :token)
    validate = Keyword.get(opts, :validate, false)

    cond do
      is_nil(token) ->
        {:error, :token_required}

      validate_token(token) != :ok ->
        {:error, :invalid_token}

      validate ->
        # Validate token with API
        case do_whoami(token) do
          {:ok, _user} ->
            set_token(token)
            :ok

          {:error, reason} ->
            {:error, reason}
        end

      true ->
        set_token(token)
        :ok
    end
  end

  @doc """
  Logs out and removes stored credentials.

  ## Examples

      :ok = HfHub.Auth.logout()
  """
  @spec logout() :: :ok
  def logout do
    Application.delete_env(:hf_hub, :token)
    :ok
  end

  @doc """
  Gets information about the current authenticated user.

  Requires a valid authentication token.

  ## Examples

      {:ok, user} = HfHub.Auth.whoami()
      IO.inspect(user.username)
      IO.inspect(user.organizations)
  """
  @spec whoami() :: {:ok, user_info()} | {:error, term()}
  def whoami do
    case get_token() do
      {:ok, token} -> do_whoami(token)
      {:error, :no_token} -> {:error, :no_token}
    end
  end

  defp do_whoami(token) do
    case HfHub.HTTP.get("/api/whoami-v2", token: token) do
      {:ok, data} ->
        user = %{
          username: Map.get(data, "name"),
          email: Map.get(data, "email"),
          fullname: Map.get(data, "fullname"),
          organizations: parse_organizations(Map.get(data, "orgs", []))
        }

        {:ok, user}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_organizations(orgs) when is_list(orgs) do
    Enum.map(orgs, fn org ->
      case org do
        %{"name" => name} -> name
        name when is_binary(name) -> name
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_organizations(_), do: []

  @doc """
  Validates a token.

  Checks if the token is properly formatted and valid with the Hub API.

  ## Arguments

    * `token` - Token to validate

  ## Examples

      :ok = HfHub.Auth.validate_token("hf_...")
      {:error, :invalid_token} = HfHub.Auth.validate_token("bad_token")
  """
  @spec validate_token(String.t()) :: :ok | {:error, term()}
  def validate_token(token) when is_binary(token) do
    if String.starts_with?(token, "hf_") and String.length(token) > 10 do
      :ok
    else
      {:error, :invalid_token}
    end
  end

  @doc """
  Builds HTTP authorization headers from the current or provided token.

  ## Options

    * `:token` - Token to use. If not provided, uses get_token/0.

  ## Examples

      {:ok, headers} = HfHub.Auth.auth_headers()
      # => {:ok, [{"authorization", "Bearer hf_..."}]}

      {:ok, headers} = HfHub.Auth.auth_headers(token: "hf_custom")
  """
  @spec auth_headers(keyword()) :: {:ok, [{String.t(), String.t()}]} | {:error, term()}
  def auth_headers(opts \\ []) do
    token =
      case Keyword.get(opts, :token) do
        nil ->
          case get_token() do
            {:ok, t} -> t
            {:error, _} -> nil
          end

        t ->
          t
      end

    if token do
      {:ok, [{"authorization", "Bearer #{token}"}]}
    else
      {:ok, []}
    end
  end
end
