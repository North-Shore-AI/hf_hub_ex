# Prompt 11: Inference Endpoints API

## Context

You are implementing Inference Endpoints management for `hf_hub_ex`. This provides dedicated infrastructure for model inference.

**Prerequisites**: Prompts 01-02 must be completed.

## Required Reading

```
lib/hf_hub/http.ex
docs/20251231/inference-endpoints/docs.md
```

## Task

Create `HfHub.InferenceEndpoints` module.

## Implementation

### Create `lib/hf_hub/inference_endpoints.ex`

```elixir
defmodule HfHub.InferenceEndpoints do
  @moduledoc """
  Inference Endpoints API for dedicated model hosting.
  """

  alias HfHub.{HTTP, Auth}
  alias HfHub.InferenceEndpoints.Endpoint

  @type accelerator :: :cpu | :gpu
  @type instance_size :: :x1 | :x2 | :x4 | :x8
  @type vendor :: :aws | :azure | :gcp
  @type endpoint_type :: :public | :protected | :private

  @spec list(keyword()) :: {:ok, [Endpoint.t()]} | {:error, term()}
  def list(opts \\ []) do
    token = opts[:token] || Auth.get_token()
    namespace = opts[:namespace] || get_default_namespace(token)

    case HTTP.get("/api/inference-endpoints/#{namespace}", token: token) do
      {:ok, %{"items" => endpoints}} ->
        {:ok, Enum.map(endpoints, &Endpoint.from_response/1)}
      {:ok, endpoints} when is_list(endpoints) ->
        {:ok, Enum.map(endpoints, &Endpoint.from_response/1)}
      error -> error
    end
  end

  @spec get(String.t(), keyword()) :: {:ok, Endpoint.t()} | {:error, term()}
  def get(name, opts \\ []) do
    token = opts[:token] || Auth.get_token()
    namespace = opts[:namespace] || get_default_namespace(token)

    case HTTP.get("/api/inference-endpoints/#{namespace}/#{name}", token: token) do
      {:ok, response} -> {:ok, Endpoint.from_response(response)}
      error -> error
    end
  end

  @spec create(String.t(), keyword()) :: {:ok, Endpoint.t()} | {:error, term()}
  def create(name, opts) do
    token = opts[:token] || Auth.get_token()
    namespace = opts[:namespace] || get_default_namespace(token)

    body = %{
      "name" => name,
      "model" => %{
        "repository" => opts[:repository],
        "framework" => opts[:framework] || "pytorch",
        "task" => opts[:task]
      },
      "compute" => %{
        "accelerator" => Atom.to_string(opts[:accelerator]),
        "instanceSize" => instance_size_to_string(opts[:instance_size]),
        "instanceType" => opts[:instance_type],
        "scaling" => %{
          "minReplica" => opts[:min_replica] || 0,
          "maxReplica" => opts[:max_replica] || 1,
          "scaleToZeroTimeout" => opts[:scale_to_zero_timeout]
        }
      },
      "provider" => %{
        "vendor" => Atom.to_string(opts[:vendor]),
        "region" => opts[:region]
      },
      "type" => Atom.to_string(opts[:type] || :protected)
    }

    case HTTP.post("/api/inference-endpoints/#{namespace}", body, token: token) do
      {:ok, response} -> {:ok, Endpoint.from_response(response)}
      error -> error
    end
  end

  @spec update(String.t(), keyword()) :: {:ok, Endpoint.t()} | {:error, term()}
  def update(name, opts \\ []) do
    token = opts[:token] || Auth.get_token()
    namespace = opts[:namespace] || get_default_namespace(token)

    body = build_update_body(opts)

    case HTTP.put("/api/inference-endpoints/#{namespace}/#{name}", body, token: token) do
      {:ok, response} -> {:ok, Endpoint.from_response(response)}
      error -> error
    end
  end

  @spec delete(String.t(), keyword()) :: :ok | {:error, term()}
  def delete(name, opts \\ []) do
    token = opts[:token] || Auth.get_token()
    namespace = opts[:namespace] || get_default_namespace(token)

    HTTP.delete("/api/inference-endpoints/#{namespace}/#{name}", token: token)
  end

  @spec pause(String.t(), keyword()) :: {:ok, Endpoint.t()} | {:error, term()}
  def pause(name, opts \\ []) do
    token = opts[:token] || Auth.get_token()
    namespace = opts[:namespace] || get_default_namespace(token)

    case HTTP.post("/api/inference-endpoints/#{namespace}/#{name}/pause", nil, token: token) do
      {:ok, response} -> {:ok, Endpoint.from_response(response)}
      error -> error
    end
  end

  @spec resume(String.t(), keyword()) :: {:ok, Endpoint.t()} | {:error, term()}
  def resume(name, opts \\ []) do
    token = opts[:token] || Auth.get_token()
    namespace = opts[:namespace] || get_default_namespace(token)

    case HTTP.post("/api/inference-endpoints/#{namespace}/#{name}/resume", nil, token: token) do
      {:ok, response} -> {:ok, Endpoint.from_response(response)}
      error -> error
    end
  end

  @spec scale_to_zero(String.t(), keyword()) :: {:ok, Endpoint.t()} | {:error, term()}
  def scale_to_zero(name, opts \\ []) do
    token = opts[:token] || Auth.get_token()
    namespace = opts[:namespace] || get_default_namespace(token)

    case HTTP.post("/api/inference-endpoints/#{namespace}/#{name}/scale-to-zero", nil, token: token) do
      {:ok, response} -> {:ok, Endpoint.from_response(response)}
      error -> error
    end
  end

  # Helpers
  defp get_default_namespace(token) do
    case Auth.whoami(token: token) do
      {:ok, %{username: username}} -> username
      _ -> raise "Could not determine namespace. Provide :namespace option."
    end
  end

  defp instance_size_to_string(:x1), do: "x1"
  defp instance_size_to_string(:x2), do: "x2"
  defp instance_size_to_string(:x4), do: "x4"
  defp instance_size_to_string(:x8), do: "x8"

  defp build_update_body(opts) do
    %{}
    |> maybe_add_compute(opts)
    |> maybe_add_model(opts)
    |> maybe_add_scaling(opts)
  end

  defp maybe_add_compute(body, opts) do
    compute = %{}
    |> maybe_put(:accelerator, opts[:accelerator] && Atom.to_string(opts[:accelerator]))
    |> maybe_put(:instanceSize, opts[:instance_size] && instance_size_to_string(opts[:instance_size]))
    |> maybe_put(:instanceType, opts[:instance_type])

    if map_size(compute) > 0, do: Map.put(body, "compute", compute), else: body
  end

  defp maybe_add_model(body, opts) do
    model = %{}
    |> maybe_put(:repository, opts[:repository])
    |> maybe_put(:framework, opts[:framework])
    |> maybe_put(:revision, opts[:revision])
    |> maybe_put(:task, opts[:task])

    if map_size(model) > 0, do: Map.put(body, "model", model), else: body
  end

  defp maybe_add_scaling(body, opts) do
    scaling = %{}
    |> maybe_put(:minReplica, opts[:min_replica])
    |> maybe_put(:maxReplica, opts[:max_replica])
    |> maybe_put(:scaleToZeroTimeout, opts[:scale_to_zero_timeout])

    if map_size(scaling) > 0 do
      compute = Map.get(body, "compute", %{})
      Map.put(body, "compute", Map.put(compute, "scaling", scaling))
    else
      body
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
```

### Create Data Structures

Create `lib/hf_hub/inference_endpoints/endpoint.ex` with nested configs.

## Changelog Entry

```markdown
### Added
- `HfHub.InferenceEndpoints` module
  - `list/1`, `get/2`, `create/2`, `update/2`, `delete/2`
  - `pause/2`, `resume/2`, `scale_to_zero/2`
```

## Completion Checklist

- [ ] `HfHub.InferenceEndpoints` module created
- [ ] Data structures created
- [ ] All operations implemented
- [ ] Tests pass
- [ ] Quality checks pass
- [ ] CHANGELOG updated
