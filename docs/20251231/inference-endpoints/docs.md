# Inference Endpoints API

## Overview

Inference Endpoints provide dedicated infrastructure for model inference with auto-scaling and GPU support.

## Python Reference

### Source File
`huggingface_hub/src/huggingface_hub/hf_api.py`

### Functions

#### list_inference_endpoints

```python
def list_inference_endpoints(
    *,
    namespace: Optional[str] = None,
    token: Optional[str] = None,
) -> List[InferenceEndpoint]
```

**API Endpoint**: `GET /api/inference-endpoints/{namespace}`

---

#### create_inference_endpoint

```python
def create_inference_endpoint(
    name: str,
    *,
    repository: str,
    framework: str,  # "pytorch", "tensorflow", etc.
    accelerator: str,  # "cpu", "gpu"
    instance_size: str,  # "x1", "x2", "x4", "x8"
    instance_type: str,  # "c6i", "g5", etc.
    region: str,  # "us-east-1", "eu-west-1", etc.
    vendor: str,  # "aws", "azure", "gcp"
    task: Optional[str] = None,
    namespace: Optional[str] = None,
    min_replica: int = 0,
    max_replica: int = 1,
    scale_to_zero_timeout: Optional[int] = None,
    type: str = "protected",  # "public", "protected", "private"
    custom_image: Optional[Dict] = None,
    token: Optional[str] = None,
) -> InferenceEndpoint
```

**API Endpoint**: `POST /api/inference-endpoints/{namespace}`

**Request Body**:
```json
{
  "name": "my-endpoint",
  "model": {
    "repository": "bert-base-uncased",
    "framework": "pytorch",
    "task": "text-classification"
  },
  "compute": {
    "accelerator": "gpu",
    "instanceSize": "x1",
    "instanceType": "g5.xlarge",
    "scaling": {
      "minReplica": 0,
      "maxReplica": 2,
      "scaleToZeroTimeout": 300
    }
  },
  "provider": {
    "vendor": "aws",
    "region": "us-east-1"
  },
  "type": "protected"
}
```

---

#### get_inference_endpoint

```python
def get_inference_endpoint(
    name: str,
    *,
    namespace: Optional[str] = None,
    token: Optional[str] = None,
) -> InferenceEndpoint
```

**API Endpoint**: `GET /api/inference-endpoints/{namespace}/{name}`

---

#### update_inference_endpoint

```python
def update_inference_endpoint(
    name: str,
    *,
    namespace: Optional[str] = None,
    accelerator: Optional[str] = None,
    instance_size: Optional[str] = None,
    instance_type: Optional[str] = None,
    min_replica: Optional[int] = None,
    max_replica: Optional[int] = None,
    scale_to_zero_timeout: Optional[int] = None,
    repository: Optional[str] = None,
    framework: Optional[str] = None,
    revision: Optional[str] = None,
    task: Optional[str] = None,
    token: Optional[str] = None,
) -> InferenceEndpoint
```

**API Endpoint**: `PUT /api/inference-endpoints/{namespace}/{name}`

---

#### delete_inference_endpoint

```python
def delete_inference_endpoint(
    name: str,
    *,
    namespace: Optional[str] = None,
    token: Optional[str] = None,
) -> None
```

**API Endpoint**: `DELETE /api/inference-endpoints/{namespace}/{name}`

---

#### pause_inference_endpoint

```python
def pause_inference_endpoint(
    name: str,
    *,
    namespace: Optional[str] = None,
    token: Optional[str] = None,
) -> InferenceEndpoint
```

**API Endpoint**: `POST /api/inference-endpoints/{namespace}/{name}/pause`

---

#### resume_inference_endpoint

```python
def resume_inference_endpoint(
    name: str,
    *,
    namespace: Optional[str] = None,
    token: Optional[str] = None,
) -> InferenceEndpoint
```

**API Endpoint**: `POST /api/inference-endpoints/{namespace}/{name}/resume`

---

#### scale_to_zero_inference_endpoint

```python
def scale_to_zero_inference_endpoint(
    name: str,
    *,
    namespace: Optional[str] = None,
    token: Optional[str] = None,
) -> InferenceEndpoint
```

**API Endpoint**: `POST /api/inference-endpoints/{namespace}/{name}/scale-to-zero`

---

## Elixir Implementation Spec

### Module: `HfHub.InferenceEndpoints`

```elixir
defmodule HfHub.InferenceEndpoints do
  @moduledoc """
  Inference Endpoints API for dedicated model hosting.
  """

  alias HfHub.InferenceEndpoints.{Endpoint, EndpointConfig}

  @type accelerator :: :cpu | :gpu
  @type instance_size :: :x1 | :x2 | :x4 | :x8
  @type vendor :: :aws | :azure | :gcp
  @type endpoint_type :: :public | :protected | :private
  @type status :: :pending | :initializing | :updating | :running | :paused | :failed | :scaled_to_zero

  @doc """
  Lists all inference endpoints.

  ## Options

  - `:namespace` - Organization namespace (default: current user)
  - `:token` - Authentication token
  """
  @spec list(keyword()) :: {:ok, [Endpoint.t()]} | {:error, term()}
  def list(opts \\ [])

  @doc """
  Gets an endpoint by name.
  """
  @spec get(String.t(), keyword()) :: {:ok, Endpoint.t()} | {:error, term()}
  def get(name, opts \\ [])

  @doc """
  Creates a new inference endpoint.

  ## Required Options

  - `:repository` - Model repository ID
  - `:accelerator` - :cpu or :gpu
  - `:instance_size` - :x1, :x2, :x4, or :x8
  - `:instance_type` - Instance type (e.g., "g5.xlarge")
  - `:region` - Cloud region (e.g., "us-east-1")
  - `:vendor` - Cloud vendor: :aws, :azure, or :gcp

  ## Optional

  - `:framework` - "pytorch", "tensorflow", etc.
  - `:task` - ML task (e.g., "text-classification")
  - `:namespace` - Organization namespace
  - `:min_replica` - Minimum replicas (default: 0)
  - `:max_replica` - Maximum replicas (default: 1)
  - `:scale_to_zero_timeout` - Seconds before scaling to zero
  - `:type` - :public, :protected, or :private (default: :protected)
  - `:custom_image` - Custom Docker image config

  ## Examples

      {:ok, endpoint} = HfHub.InferenceEndpoints.create("my-endpoint",
        repository: "bert-base-uncased",
        accelerator: :gpu,
        instance_size: :x1,
        instance_type: "g5.xlarge",
        region: "us-east-1",
        vendor: :aws,
        task: "text-classification"
      )
  """
  @spec create(String.t(), keyword()) :: {:ok, Endpoint.t()} | {:error, term()}
  def create(name, opts)

  @doc """
  Updates an existing endpoint.

  Only provided options are updated; others remain unchanged.
  """
  @spec update(String.t(), keyword()) :: {:ok, Endpoint.t()} | {:error, term()}
  def update(name, opts \\ [])

  @doc """
  Deletes an endpoint.
  """
  @spec delete(String.t(), keyword()) :: :ok | {:error, term()}
  def delete(name, opts \\ [])

  @doc """
  Pauses an endpoint.

  Paused endpoints don't incur compute costs but retain configuration.
  """
  @spec pause(String.t(), keyword()) :: {:ok, Endpoint.t()} | {:error, term()}
  def pause(name, opts \\ [])

  @doc """
  Resumes a paused endpoint.
  """
  @spec resume(String.t(), keyword()) :: {:ok, Endpoint.t()} | {:error, term()}
  def resume(name, opts \\ [])

  @doc """
  Scales endpoint to zero replicas.

  Different from pause: endpoint can auto-wake on requests.
  """
  @spec scale_to_zero(String.t(), keyword()) :: {:ok, Endpoint.t()} | {:error, term()}
  def scale_to_zero(name, opts \\ [])
end
```

### Data Structures

```elixir
defmodule HfHub.InferenceEndpoints.Endpoint do
  defstruct [
    :name,
    :namespace,
    :status,
    :url,
    :model,
    :compute,
    :provider,
    :type,
    :created_at,
    :updated_at
  ]

  @type t :: %__MODULE__{
    name: String.t(),
    namespace: String.t(),
    status: HfHub.InferenceEndpoints.status(),
    url: String.t() | nil,
    model: HfHub.InferenceEndpoints.ModelConfig.t(),
    compute: HfHub.InferenceEndpoints.ComputeConfig.t(),
    provider: HfHub.InferenceEndpoints.ProviderConfig.t(),
    type: :public | :protected | :private,
    created_at: DateTime.t(),
    updated_at: DateTime.t()
  }
end

defmodule HfHub.InferenceEndpoints.ModelConfig do
  defstruct [:repository, :framework, :task, :revision, :image]

  @type t :: %__MODULE__{
    repository: String.t(),
    framework: String.t(),
    task: String.t() | nil,
    revision: String.t() | nil,
    image: map() | nil
  }
end

defmodule HfHub.InferenceEndpoints.ComputeConfig do
  defstruct [:accelerator, :instance_size, :instance_type, :scaling]

  @type t :: %__MODULE__{
    accelerator: :cpu | :gpu,
    instance_size: String.t(),
    instance_type: String.t(),
    scaling: HfHub.InferenceEndpoints.ScalingConfig.t()
  }
end

defmodule HfHub.InferenceEndpoints.ScalingConfig do
  defstruct [:min_replica, :max_replica, :scale_to_zero_timeout]

  @type t :: %__MODULE__{
    min_replica: non_neg_integer(),
    max_replica: pos_integer(),
    scale_to_zero_timeout: non_neg_integer() | nil
  }
end

defmodule HfHub.InferenceEndpoints.ProviderConfig do
  defstruct [:vendor, :region]

  @type t :: %__MODULE__{
    vendor: :aws | :azure | :gcp,
    region: String.t()
  }
end
```

---

## Test Scenarios

1. List endpoints
2. List endpoints for org
3. Get endpoint details
4. Create CPU endpoint
5. Create GPU endpoint
6. Create with scaling config
7. Create with custom image
8. Update instance size
9. Update scaling limits
10. Update model repository
11. Delete endpoint
12. Pause running endpoint
13. Resume paused endpoint
14. Scale to zero
15. Error: invalid region
16. Error: invalid instance type
17. Error: duplicate name
