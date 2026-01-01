defmodule HfHub.Spaces do
  @moduledoc """
  Space management API for HuggingFace Spaces.

  Provides runtime control, secrets, variables, and hardware configuration.

  ## Hardware Options

    * `:cpu_basic` - Free CPU
    * `:cpu_upgrade` - Upgraded CPU
    * `:t4_small` - T4 GPU (small)
    * `:t4_medium` - T4 GPU (medium)
    * `:a10g_small` - A10G GPU (small)
    * `:a10g_large` - A10G GPU (large)
    * `:a100_large` - A100 GPU
    * `:zero_a10g` - ZeroGPU A10G

  ## Storage Options

    * `:small` - Small persistent storage
    * `:medium` - Medium persistent storage
    * `:large` - Large persistent storage

  ## Examples

      # Get runtime info
      {:ok, runtime} = HfHub.Spaces.get_runtime("user/my-space")

      # Request GPU hardware
      {:ok, runtime} = HfHub.Spaces.request_hardware("user/my-space", :t4_small)

      # Add a secret
      :ok = HfHub.Spaces.add_secret("user/my-space", "API_KEY", "secret_value")

      # Pause and restart
      {:ok, _} = HfHub.Spaces.pause("user/my-space")
      {:ok, _} = HfHub.Spaces.restart("user/my-space")
  """

  alias HfHub.{Auth, HTTP}
  alias HfHub.Repo.RepoUrl
  alias HfHub.Spaces.{SpaceRuntime, SpaceVariable}

  @type hardware ::
          :cpu_basic
          | :cpu_upgrade
          | :t4_small
          | :t4_medium
          | :a10g_small
          | :a10g_large
          | :a100_large
          | :zero_a10g

  @type storage :: :small | :medium | :large

  # Runtime

  @doc """
  Gets runtime information for a Space.

  ## Arguments

    * `repo_id` - Repository ID (e.g., "user/my-space")
    * `opts` - Request options

  ## Options

    * `:token` - Authentication token

  ## Examples

      {:ok, runtime} = HfHub.Spaces.get_runtime("user/my-space")
      runtime.stage  # => :running
      runtime.hardware  # => "cpu-basic"
  """
  @spec get_runtime(String.t(), keyword()) :: {:ok, SpaceRuntime.t()} | {:error, term()}
  def get_runtime(repo_id, opts \\ []) do
    token = opts[:token]

    case HTTP.get("/api/spaces/#{encode(repo_id)}/runtime", token: token) do
      {:ok, response} -> {:ok, SpaceRuntime.from_response(response)}
      error -> error
    end
  end

  @doc """
  Gets all variables for a Space.

  ## Arguments

    * `repo_id` - Repository ID
    * `opts` - Request options

  ## Options

    * `:token` - Authentication token

  ## Examples

      {:ok, vars} = HfHub.Spaces.get_variables("user/my-space")
      vars["MY_VAR"].value  # => "some_value"
  """
  @spec get_variables(String.t(), keyword()) ::
          {:ok, %{String.t() => SpaceVariable.t()}} | {:error, term()}
  def get_variables(repo_id, opts \\ []) do
    token = opts[:token]

    case HTTP.get("/api/spaces/#{encode(repo_id)}/variables", token: token) do
      {:ok, response} ->
        vars = for {k, v} <- response, into: %{}, do: {k, SpaceVariable.from_response(k, v)}
        {:ok, vars}

      error ->
        error
    end
  end

  # Secrets

  @doc """
  Adds or updates a secret.

  Secrets are encrypted and not visible after creation.

  ## Arguments

    * `repo_id` - Repository ID
    * `key` - Secret name
    * `value` - Secret value
    * `opts` - Request options

  ## Options

    * `:token` - Authentication token
    * `:description` - Optional description

  ## Examples

      :ok = HfHub.Spaces.add_secret("user/my-space", "API_KEY", "secret_value")
      :ok = HfHub.Spaces.add_secret("user/my-space", "API_KEY", "value",
              description: "API key for external service")
  """
  @spec add_secret(String.t(), String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def add_secret(repo_id, key, value, opts \\ []) do
    token = opts[:token] || get_token_value()

    body =
      %{
        "key" => key,
        "value" => value,
        "description" => opts[:description]
      }
      |> reject_nil_values()

    HTTP.post_action("/api/spaces/#{encode(repo_id)}/secrets", body, token: token)
  end

  @doc """
  Deletes a secret.

  ## Arguments

    * `repo_id` - Repository ID
    * `key` - Secret name to delete
    * `opts` - Request options

  ## Options

    * `:token` - Authentication token

  ## Examples

      :ok = HfHub.Spaces.delete_secret("user/my-space", "API_KEY")
  """
  @spec delete_secret(String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def delete_secret(repo_id, key, opts \\ []) do
    token = opts[:token] || get_token_value()
    HTTP.delete("/api/spaces/#{encode(repo_id)}/secrets/#{encode(key)}", token: token)
  end

  # Variables

  @doc """
  Adds or updates a variable.

  Variables are visible in the Space settings.

  ## Arguments

    * `repo_id` - Repository ID
    * `key` - Variable name
    * `value` - Variable value
    * `opts` - Request options

  ## Options

    * `:token` - Authentication token
    * `:description` - Optional description

  ## Examples

      {:ok, var} = HfHub.Spaces.add_variable("user/my-space", "DEBUG", "true")
  """
  @spec add_variable(String.t(), String.t(), String.t(), keyword()) ::
          {:ok, SpaceVariable.t()} | {:error, term()}
  def add_variable(repo_id, key, value, opts \\ []) do
    token = opts[:token] || get_token_value()

    body =
      %{
        "key" => key,
        "value" => value,
        "description" => opts[:description]
      }
      |> reject_nil_values()

    case HTTP.post("/api/spaces/#{encode(repo_id)}/variables", body, token: token) do
      {:ok, response} -> {:ok, SpaceVariable.from_response(key, response)}
      error -> error
    end
  end

  @doc """
  Deletes a variable.

  ## Arguments

    * `repo_id` - Repository ID
    * `key` - Variable name to delete
    * `opts` - Request options

  ## Options

    * `:token` - Authentication token

  ## Examples

      :ok = HfHub.Spaces.delete_variable("user/my-space", "DEBUG")
  """
  @spec delete_variable(String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def delete_variable(repo_id, key, opts \\ []) do
    token = opts[:token] || get_token_value()
    HTTP.delete("/api/spaces/#{encode(repo_id)}/variables/#{encode(key)}", token: token)
  end

  # Hardware

  @doc """
  Requests hardware upgrade or downgrade.

  ## Arguments

    * `repo_id` - Repository ID
    * `hardware` - Hardware type (see module docs)
    * `opts` - Request options

  ## Options

    * `:token` - Authentication token
    * `:sleep_time` - Auto-sleep timeout in seconds

  ## Examples

      {:ok, runtime} = HfHub.Spaces.request_hardware("user/my-space", :t4_small)
      {:ok, runtime} = HfHub.Spaces.request_hardware("user/my-space", :cpu_basic,
                         sleep_time: 300)
  """
  @spec request_hardware(String.t(), hardware(), keyword()) ::
          {:ok, SpaceRuntime.t()} | {:error, term()}
  def request_hardware(repo_id, hardware, opts \\ []) do
    token = opts[:token] || get_token_value()

    body =
      %{
        "hardware" => hardware_to_string(hardware),
        "sleepTime" => opts[:sleep_time]
      }
      |> reject_nil_values()

    case HTTP.post("/api/spaces/#{encode(repo_id)}/hardware", body, token: token) do
      {:ok, response} -> {:ok, SpaceRuntime.from_response(response)}
      error -> error
    end
  end

  @doc """
  Sets the auto-sleep timeout.

  ## Arguments

    * `repo_id` - Repository ID
    * `seconds` - Timeout in seconds, or -1 to disable (requires paid hardware)
    * `opts` - Request options

  ## Options

    * `:token` - Authentication token

  ## Examples

      {:ok, runtime} = HfHub.Spaces.set_sleep_time("user/my-space", 300)
      {:ok, runtime} = HfHub.Spaces.set_sleep_time("user/my-space", -1)  # Never sleep
  """
  @spec set_sleep_time(String.t(), integer(), keyword()) ::
          {:ok, SpaceRuntime.t()} | {:error, term()}
  def set_sleep_time(repo_id, seconds, opts \\ []) do
    token = opts[:token] || get_token_value()

    body = %{"sleepTime" => seconds}

    case HTTP.post("/api/spaces/#{encode(repo_id)}/sleeptime", body, token: token) do
      {:ok, response} -> {:ok, SpaceRuntime.from_response(response)}
      error -> error
    end
  end

  # Storage

  @doc """
  Requests persistent storage.

  ## Arguments

    * `repo_id` - Repository ID
    * `storage` - Storage tier (`:small`, `:medium`, or `:large`)
    * `opts` - Request options

  ## Options

    * `:token` - Authentication token

  ## Examples

      {:ok, runtime} = HfHub.Spaces.request_storage("user/my-space", :small)
  """
  @spec request_storage(String.t(), storage(), keyword()) ::
          {:ok, SpaceRuntime.t()} | {:error, term()}
  def request_storage(repo_id, storage, opts \\ []) do
    token = opts[:token] || get_token_value()

    body = %{"storage" => Atom.to_string(storage)}

    case HTTP.post("/api/spaces/#{encode(repo_id)}/storage", body, token: token) do
      {:ok, response} -> {:ok, SpaceRuntime.from_response(response)}
      error -> error
    end
  end

  @doc """
  Deletes persistent storage.

  **Warning**: This is destructive and cannot be undone.

  ## Arguments

    * `repo_id` - Repository ID
    * `opts` - Request options

  ## Options

    * `:token` - Authentication token

  ## Examples

      {:ok, runtime} = HfHub.Spaces.delete_storage("user/my-space")
  """
  @spec delete_storage(String.t(), keyword()) :: {:ok, SpaceRuntime.t()} | {:error, term()}
  def delete_storage(repo_id, opts \\ []) do
    token = opts[:token] || get_token_value()

    case HTTP.delete("/api/spaces/#{encode(repo_id)}/storage", token: token) do
      {:ok, response} -> {:ok, SpaceRuntime.from_response(response)}
      :ok -> get_runtime(repo_id, opts)
      error -> error
    end
  end

  # Lifecycle

  @doc """
  Pauses a running Space.

  A paused Space stops using resources but retains its configuration.

  ## Arguments

    * `repo_id` - Repository ID
    * `opts` - Request options

  ## Options

    * `:token` - Authentication token

  ## Examples

      {:ok, runtime} = HfHub.Spaces.pause("user/my-space")
  """
  @spec pause(String.t(), keyword()) :: {:ok, SpaceRuntime.t()} | {:error, term()}
  def pause(repo_id, opts \\ []) do
    token = opts[:token] || get_token_value()

    case HTTP.post("/api/spaces/#{encode(repo_id)}/pause", nil, token: token) do
      {:ok, response} -> {:ok, SpaceRuntime.from_response(response)}
      error -> error
    end
  end

  @doc """
  Restarts a Space.

  ## Arguments

    * `repo_id` - Repository ID
    * `opts` - Request options

  ## Options

    * `:token` - Authentication token
    * `:factory_reboot` - Full factory reset (default: false)

  ## Examples

      {:ok, runtime} = HfHub.Spaces.restart("user/my-space")
      {:ok, runtime} = HfHub.Spaces.restart("user/my-space", factory_reboot: true)
  """
  @spec restart(String.t(), keyword()) :: {:ok, SpaceRuntime.t()} | {:error, term()}
  def restart(repo_id, opts \\ []) do
    token = opts[:token] || get_token_value()

    body = if opts[:factory_reboot], do: %{"factoryReboot" => true}, else: nil

    case HTTP.post("/api/spaces/#{encode(repo_id)}/restart", body, token: token) do
      {:ok, response} -> {:ok, SpaceRuntime.from_response(response)}
      error -> error
    end
  end

  @doc """
  Duplicates a Space to a new repository.

  ## Arguments

    * `from_id` - Source Space repository ID
    * `opts` - Request options

  ## Options

    * `:token` - Authentication token
    * `:to_id` - Target repository ID (default: same name in user namespace)
    * `:private` - Make duplicate private (default: false)
    * `:hardware` - Hardware for duplicate
    * `:storage` - Storage for duplicate
    * `:secrets` - List of secrets to copy (maps with "key" and "value")
    * `:variables` - List of variables to copy (maps with "key" and "value")

  ## Examples

      {:ok, repo_url} = HfHub.Spaces.duplicate("gradio/hello_world")
      {:ok, repo_url} = HfHub.Spaces.duplicate("gradio/hello_world",
                          to_id: "user/my-copy", private: true)
  """
  @spec duplicate(String.t(), keyword()) :: {:ok, RepoUrl.t()} | {:error, term()}
  def duplicate(from_id, opts \\ []) do
    token = opts[:token] || get_token_value()

    body =
      %{
        "toId" => opts[:to_id],
        "private" => opts[:private],
        "hardware" => opts[:hardware] && hardware_to_string(opts[:hardware]),
        "storage" => opts[:storage] && Atom.to_string(opts[:storage]),
        "secrets" => opts[:secrets],
        "variables" => opts[:variables]
      }
      |> reject_nil_values()

    case HTTP.post("/api/spaces/#{encode(from_id)}/duplicate", body, token: token) do
      {:ok, response} -> {:ok, RepoUrl.from_response(response, :space)}
      error -> error
    end
  end

  # Helpers

  defp encode(s), do: URI.encode(s, &URI.char_unreserved?/1)

  defp reject_nil_values(map) do
    map
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp get_token_value do
    case Auth.get_token() do
      {:ok, token} -> token
      {:error, _} -> nil
    end
  end

  defp hardware_to_string(:cpu_basic), do: "cpu-basic"
  defp hardware_to_string(:cpu_upgrade), do: "cpu-upgrade"
  defp hardware_to_string(:t4_small), do: "t4-small"
  defp hardware_to_string(:t4_medium), do: "t4-medium"
  defp hardware_to_string(:a10g_small), do: "a10g-small"
  defp hardware_to_string(:a10g_large), do: "a10g-large"
  defp hardware_to_string(:a100_large), do: "a100-large"
  defp hardware_to_string(:zero_a10g), do: "zero-a10g"
end
