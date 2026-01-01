# Prompt 10: Space Management API

## Context

You are implementing Space management for `hf_hub_ex`. This provides runtime control, secrets, variables, and hardware configuration.

**Prerequisites**: Prompts 01-02 must be completed.

## Required Reading

```
lib/hf_hub/http.ex
docs/20251231/spaces/docs.md
```

## Task

Create `HfHub.Spaces` module.

## Implementation

### Create `lib/hf_hub/spaces.ex`

```elixir
defmodule HfHub.Spaces do
  @moduledoc """
  Space management API for HuggingFace Spaces.
  """

  alias HfHub.{HTTP, Auth}
  alias HfHub.Spaces.{SpaceRuntime, SpaceVariable}

  @type hardware :: :cpu_basic | :cpu_upgrade | :t4_small | :t4_medium |
                    :a10g_small | :a10g_large | :a100_large | :zero_a10g
  @type storage :: :small | :medium | :large

  # Runtime

  @spec get_runtime(String.t(), keyword()) :: {:ok, SpaceRuntime.t()} | {:error, term()}
  def get_runtime(repo_id, opts \\ []) do
    token = opts[:token]

    case HTTP.get("/api/spaces/#{encode(repo_id)}/runtime", token: token) do
      {:ok, response} -> {:ok, SpaceRuntime.from_response(response)}
      error -> error
    end
  end

  @spec get_variables(String.t(), keyword()) ::
    {:ok, %{String.t() => SpaceVariable.t()}} | {:error, term()}
  def get_variables(repo_id, opts \\ []) do
    token = opts[:token]

    case HTTP.get("/api/spaces/#{encode(repo_id)}/variables", token: token) do
      {:ok, response} ->
        vars = for {k, v} <- response, into: %{}, do: {k, SpaceVariable.from_response(k, v)}
        {:ok, vars}
      error -> error
    end
  end

  # Secrets

  @spec add_secret(String.t(), String.t(), String.t(), keyword()) ::
    :ok | {:error, term()}
  def add_secret(repo_id, key, value, opts \\ []) do
    token = opts[:token] || Auth.get_token()

    body = %{
      "key" => key,
      "value" => value,
      "description" => opts[:description]
    } |> Enum.reject(fn {_, v} -> is_nil(v) end) |> Map.new()

    HTTP.post_action("/api/spaces/#{encode(repo_id)}/secrets", body, token: token)
  end

  @spec delete_secret(String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def delete_secret(repo_id, key, opts \\ []) do
    token = opts[:token] || Auth.get_token()
    HTTP.delete("/api/spaces/#{encode(repo_id)}/secrets/#{encode(key)}", token: token)
  end

  # Variables

  @spec add_variable(String.t(), String.t(), String.t(), keyword()) ::
    {:ok, SpaceVariable.t()} | {:error, term()}
  def add_variable(repo_id, key, value, opts \\ []) do
    token = opts[:token] || Auth.get_token()

    body = %{
      "key" => key,
      "value" => value,
      "description" => opts[:description]
    } |> Enum.reject(fn {_, v} -> is_nil(v) end) |> Map.new()

    case HTTP.post("/api/spaces/#{encode(repo_id)}/variables", body, token: token) do
      {:ok, response} -> {:ok, SpaceVariable.from_response(key, response)}
      error -> error
    end
  end

  @spec delete_variable(String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def delete_variable(repo_id, key, opts \\ []) do
    token = opts[:token] || Auth.get_token()
    HTTP.delete("/api/spaces/#{encode(repo_id)}/variables/#{encode(key)}", token: token)
  end

  # Hardware

  @spec request_hardware(String.t(), hardware(), keyword()) ::
    {:ok, SpaceRuntime.t()} | {:error, term()}
  def request_hardware(repo_id, hardware, opts \\ []) do
    token = opts[:token] || Auth.get_token()

    body = %{
      "hardware" => hardware_to_string(hardware),
      "sleepTime" => opts[:sleep_time]
    } |> Enum.reject(fn {_, v} -> is_nil(v) end) |> Map.new()

    case HTTP.post("/api/spaces/#{encode(repo_id)}/hardware", body, token: token) do
      {:ok, response} -> {:ok, SpaceRuntime.from_response(response)}
      error -> error
    end
  end

  @spec set_sleep_time(String.t(), integer(), keyword()) ::
    {:ok, SpaceRuntime.t()} | {:error, term()}
  def set_sleep_time(repo_id, seconds, opts \\ []) do
    token = opts[:token] || Auth.get_token()

    body = %{"sleepTime" => seconds}

    case HTTP.post("/api/spaces/#{encode(repo_id)}/sleeptime", body, token: token) do
      {:ok, response} -> {:ok, SpaceRuntime.from_response(response)}
      error -> error
    end
  end

  # Storage

  @spec request_storage(String.t(), storage(), keyword()) ::
    {:ok, SpaceRuntime.t()} | {:error, term()}
  def request_storage(repo_id, storage, opts \\ []) do
    token = opts[:token] || Auth.get_token()

    body = %{"storage" => Atom.to_string(storage)}

    case HTTP.post("/api/spaces/#{encode(repo_id)}/storage", body, token: token) do
      {:ok, response} -> {:ok, SpaceRuntime.from_response(response)}
      error -> error
    end
  end

  @spec delete_storage(String.t(), keyword()) ::
    {:ok, SpaceRuntime.t()} | {:error, term()}
  def delete_storage(repo_id, opts \\ []) do
    token = opts[:token] || Auth.get_token()

    case HTTP.delete("/api/spaces/#{encode(repo_id)}/storage", token: token) do
      {:ok, response} -> {:ok, SpaceRuntime.from_response(response)}
      :ok -> get_runtime(repo_id, opts)
      error -> error
    end
  end

  # Lifecycle

  @spec pause(String.t(), keyword()) :: {:ok, SpaceRuntime.t()} | {:error, term()}
  def pause(repo_id, opts \\ []) do
    token = opts[:token] || Auth.get_token()

    case HTTP.post("/api/spaces/#{encode(repo_id)}/pause", nil, token: token) do
      {:ok, response} -> {:ok, SpaceRuntime.from_response(response)}
      error -> error
    end
  end

  @spec restart(String.t(), keyword()) :: {:ok, SpaceRuntime.t()} | {:error, term()}
  def restart(repo_id, opts \\ []) do
    token = opts[:token] || Auth.get_token()

    body = if opts[:factory_reboot], do: %{"factoryReboot" => true}, else: nil

    case HTTP.post("/api/spaces/#{encode(repo_id)}/restart", body, token: token) do
      {:ok, response} -> {:ok, SpaceRuntime.from_response(response)}
      error -> error
    end
  end

  @spec duplicate(String.t(), keyword()) ::
    {:ok, HfHub.Repo.RepoUrl.t()} | {:error, term()}
  def duplicate(from_id, opts \\ []) do
    token = opts[:token] || Auth.get_token()

    body = %{
      "toId" => opts[:to_id],
      "private" => opts[:private],
      "hardware" => opts[:hardware] && hardware_to_string(opts[:hardware]),
      "storage" => opts[:storage] && Atom.to_string(opts[:storage]),
      "secrets" => opts[:secrets],
      "variables" => opts[:variables]
    } |> Enum.reject(fn {_, v} -> is_nil(v) end) |> Map.new()

    case HTTP.post("/api/spaces/#{encode(from_id)}/duplicate", body, token: token) do
      {:ok, response} -> {:ok, HfHub.Repo.RepoUrl.from_response(response, :space)}
      error -> error
    end
  end

  # Helpers
  defp encode(s), do: URI.encode(s, &URI.char_unreserved?/1)

  defp hardware_to_string(:cpu_basic), do: "cpu-basic"
  defp hardware_to_string(:cpu_upgrade), do: "cpu-upgrade"
  defp hardware_to_string(:t4_small), do: "t4-small"
  defp hardware_to_string(:t4_medium), do: "t4-medium"
  defp hardware_to_string(:a10g_small), do: "a10g-small"
  defp hardware_to_string(:a10g_large), do: "a10g-large"
  defp hardware_to_string(:a100_large), do: "a100-large"
  defp hardware_to_string(:zero_a10g), do: "zero-a10g"
end
```

### Create Data Structures

`lib/hf_hub/spaces/space_runtime.ex` and `lib/hf_hub/spaces/space_variable.ex`

## Changelog Entry

```markdown
### Added
- `HfHub.Spaces` module
  - Runtime: `get_runtime/2`
  - Variables: `get_variables/2`, `add_variable/4`, `delete_variable/3`
  - Secrets: `add_secret/4`, `delete_secret/3`
  - Hardware: `request_hardware/3`, `set_sleep_time/3`
  - Storage: `request_storage/3`, `delete_storage/2`
  - Lifecycle: `pause/2`, `restart/2`, `duplicate/2`
```

## Completion Checklist

- [ ] `HfHub.Spaces` module created
- [ ] All operations implemented
- [ ] Tests pass
- [ ] Quality checks pass
- [ ] CHANGELOG updated
