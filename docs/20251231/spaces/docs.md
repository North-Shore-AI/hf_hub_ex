# Space Management API

## Overview

Space management provides runtime control, secrets, variables, and hardware configuration for HuggingFace Spaces.

## Python Reference

### Source File
`huggingface_hub/src/huggingface_hub/hf_api.py`

### Functions

#### get_space_runtime

```python
def get_space_runtime(
    repo_id: str,
    *,
    token: Optional[str] = None,
) -> SpaceRuntime
```

**API Endpoint**: `GET /api/spaces/{repo_id}/runtime`

**Response**:
```json
{
  "stage": "RUNNING",
  "hardware": {"current": "cpu-basic", "requested": "cpu-basic"},
  "gcTimeout": 300,
  "rawLogs": true,
  "sdk": "gradio",
  "sdkVersion": "4.0.0"
}
```

---

#### get_space_variables

```python
def get_space_variables(
    repo_id: str,
    *,
    token: Optional[str] = None,
) -> Dict[str, SpaceVariable]
```

**API Endpoint**: `GET /api/spaces/{repo_id}/variables`

---

#### add_space_secret

```python
def add_space_secret(
    repo_id: str,
    key: str,
    value: str,
    *,
    description: Optional[str] = None,
    token: Optional[str] = None,
) -> None
```

**API Endpoint**: `POST /api/spaces/{repo_id}/secrets`

---

#### delete_space_secret

```python
def delete_space_secret(
    repo_id: str,
    key: str,
    *,
    token: Optional[str] = None,
) -> None
```

**API Endpoint**: `DELETE /api/spaces/{repo_id}/secrets/{key}`

---

#### add_space_variable

```python
def add_space_variable(
    repo_id: str,
    key: str,
    value: str,
    *,
    description: Optional[str] = None,
    token: Optional[str] = None,
) -> SpaceVariable
```

**API Endpoint**: `POST /api/spaces/{repo_id}/variables`

---

#### delete_space_variable

```python
def delete_space_variable(
    repo_id: str,
    key: str,
    *,
    token: Optional[str] = None,
) -> None
```

**API Endpoint**: `DELETE /api/spaces/{repo_id}/variables/{key}`

---

#### request_space_hardware

```python
def request_space_hardware(
    repo_id: str,
    hardware: SpaceHardware,  # "cpu-basic", "gpu-t4-small", etc.
    *,
    sleep_time: Optional[int] = None,
    token: Optional[str] = None,
) -> SpaceRuntime
```

**API Endpoint**: `POST /api/spaces/{repo_id}/hardware`

---

#### set_space_sleep_time

```python
def set_space_sleep_time(
    repo_id: str,
    sleep_time: int,  # seconds, -1 for never
    *,
    token: Optional[str] = None,
) -> SpaceRuntime
```

**API Endpoint**: `POST /api/spaces/{repo_id}/sleeptime`

---

#### pause_space

```python
def pause_space(
    repo_id: str,
    *,
    token: Optional[str] = None,
) -> SpaceRuntime
```

**API Endpoint**: `POST /api/spaces/{repo_id}/pause`

---

#### restart_space

```python
def restart_space(
    repo_id: str,
    *,
    token: Optional[str] = None,
    factory_reboot: bool = False,
) -> SpaceRuntime
```

**API Endpoint**: `POST /api/spaces/{repo_id}/restart`

---

#### duplicate_space

```python
def duplicate_space(
    from_id: str,
    *,
    to_id: Optional[str] = None,
    private: bool = False,
    hardware: Optional[SpaceHardware] = None,
    storage: Optional[SpaceStorage] = None,
    secrets: Optional[List[Dict[str, str]]] = None,
    variables: Optional[List[Dict[str, str]]] = None,
    token: Optional[str] = None,
) -> RepoUrl
```

**API Endpoint**: `POST /api/spaces/{from_id}/duplicate`

---

#### request_space_storage

```python
def request_space_storage(
    repo_id: str,
    storage: SpaceStorage,  # "small", "medium", "large"
    *,
    token: Optional[str] = None,
) -> SpaceRuntime
```

**API Endpoint**: `POST /api/spaces/{repo_id}/storage`

---

#### delete_space_storage

```python
def delete_space_storage(
    repo_id: str,
    *,
    token: Optional[str] = None,
) -> SpaceRuntime
```

**API Endpoint**: `DELETE /api/spaces/{repo_id}/storage`

---

## Elixir Implementation Spec

### Module: `HfHub.Spaces`

```elixir
defmodule HfHub.Spaces do
  @moduledoc """
  Space management API for HuggingFace Spaces.
  """

  alias HfHub.Spaces.{SpaceRuntime, SpaceVariable}

  @type hardware ::
    :cpu_basic | :cpu_upgrade |
    :t4_small | :t4_medium |
    :a10g_small | :a10g_large |
    :a100_large | :zero_a10g

  @type storage :: :small | :medium | :large
  @type stage :: :building | :running | :paused | :sleeping | :stopped

  @doc """
  Gets runtime information for a Space.
  """
  @spec get_runtime(String.t(), keyword()) ::
    {:ok, SpaceRuntime.t()} | {:error, term()}
  def get_runtime(repo_id, opts \\ [])

  @doc """
  Gets all variables for a Space.
  """
  @spec get_variables(String.t(), keyword()) ::
    {:ok, %{String.t() => SpaceVariable.t()}} | {:error, term()}
  def get_variables(repo_id, opts \\ [])

  # Secrets

  @doc """
  Adds or updates a secret.
  """
  @spec add_secret(String.t(), String.t(), String.t(), keyword()) ::
    :ok | {:error, term()}
  def add_secret(repo_id, key, value, opts \\ [])

  @doc """
  Deletes a secret.
  """
  @spec delete_secret(String.t(), String.t(), keyword()) ::
    :ok | {:error, term()}
  def delete_secret(repo_id, key, opts \\ [])

  # Variables

  @doc """
  Adds or updates a variable.
  """
  @spec add_variable(String.t(), String.t(), String.t(), keyword()) ::
    {:ok, SpaceVariable.t()} | {:error, term()}
  def add_variable(repo_id, key, value, opts \\ [])

  @doc """
  Deletes a variable.
  """
  @spec delete_variable(String.t(), String.t(), keyword()) ::
    :ok | {:error, term()}
  def delete_variable(repo_id, key, opts \\ [])

  # Hardware & Resources

  @doc """
  Requests hardware upgrade/downgrade.

  ## Hardware Options

  - `:cpu_basic` - Free CPU
  - `:cpu_upgrade` - Upgraded CPU
  - `:t4_small` - T4 GPU (small)
  - `:t4_medium` - T4 GPU (medium)
  - `:a10g_small` - A10G GPU (small)
  - `:a10g_large` - A10G GPU (large)
  - `:a100_large` - A100 GPU
  - `:zero_a10g` - ZeroGPU A10G

  ## Examples

      {:ok, runtime} = HfHub.Spaces.request_hardware("my-space", :t4_small)
  """
  @spec request_hardware(String.t(), hardware(), keyword()) ::
    {:ok, SpaceRuntime.t()} | {:error, term()}
  def request_hardware(repo_id, hardware, opts \\ [])

  @doc """
  Sets the sleep timeout.

  - Positive integer: seconds until sleep
  - -1: Never sleep (requires paid hardware)
  """
  @spec set_sleep_time(String.t(), integer(), keyword()) ::
    {:ok, SpaceRuntime.t()} | {:error, term()}
  def set_sleep_time(repo_id, seconds, opts \\ [])

  @doc """
  Requests persistent storage.
  """
  @spec request_storage(String.t(), storage(), keyword()) ::
    {:ok, SpaceRuntime.t()} | {:error, term()}
  def request_storage(repo_id, storage, opts \\ [])

  @doc """
  Deletes persistent storage.
  """
  @spec delete_storage(String.t(), keyword()) ::
    {:ok, SpaceRuntime.t()} | {:error, term()}
  def delete_storage(repo_id, opts \\ [])

  # Lifecycle

  @doc """
  Pauses a running Space.
  """
  @spec pause(String.t(), keyword()) :: {:ok, SpaceRuntime.t()} | {:error, term()}
  def pause(repo_id, opts \\ [])

  @doc """
  Restarts a Space.

  ## Options

  - `:factory_reboot` - Full factory reset (default: false)
  """
  @spec restart(String.t(), keyword()) :: {:ok, SpaceRuntime.t()} | {:error, term()}
  def restart(repo_id, opts \\ [])

  @doc """
  Duplicates a Space to a new repository.

  ## Options

  - `:to_id` - Target repo ID (default: same name in user namespace)
  - `:private` - Make duplicate private (default: false)
  - `:hardware` - Hardware for duplicate
  - `:storage` - Storage for duplicate
  - `:secrets` - Secrets to copy
  - `:variables` - Variables to copy
  """
  @spec duplicate(String.t(), keyword()) ::
    {:ok, HfHub.Repo.RepoUrl.t()} | {:error, term()}
  def duplicate(from_id, opts \\ [])
end
```

### Data Structures

```elixir
defmodule HfHub.Spaces.SpaceRuntime do
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

  @type t :: %__MODULE__{
    stage: :building | :running | :paused | :sleeping | :stopped,
    hardware: String.t(),
    requested_hardware: String.t() | nil,
    sleep_time: integer() | nil,
    sdk: String.t(),
    sdk_version: String.t(),
    storage: String.t() | nil,
    raw_logs: boolean()
  }
end

defmodule HfHub.Spaces.SpaceVariable do
  defstruct [:key, :value, :description, :updated_at]

  @type t :: %__MODULE__{
    key: String.t(),
    value: String.t(),
    description: String.t() | nil,
    updated_at: DateTime.t()
  }
end
```

---

## Test Scenarios

1. Get runtime for running Space
2. Get runtime for paused Space
3. Get variables
4. Add secret
5. Update secret
6. Delete secret
7. Add variable with description
8. Update variable
9. Delete variable
10. Request GPU hardware
11. Downgrade to CPU
12. Set sleep time
13. Disable sleep (-1)
14. Request storage
15. Delete storage
16. Pause Space
17. Restart Space
18. Factory reboot
19. Duplicate Space
20. Duplicate with hardware/storage
21. Error: invalid hardware tier
22. Error: unauthorized
