defmodule HfHub.InferenceEndpoints do
  @moduledoc """
  Inference Endpoints API for dedicated model hosting.

  Provides management of HuggingFace Inference Endpoints - dedicated infrastructure
  for model inference with auto-scaling and GPU support.

  ## Accelerator Options

    * `:cpu` - CPU-based inference
    * `:gpu` - GPU-based inference

  ## Instance Sizes

    * `:x1` - 1x resources
    * `:x2` - 2x resources
    * `:x4` - 4x resources
    * `:x8` - 8x resources

  ## Cloud Vendors

    * `:aws` - Amazon Web Services
    * `:azure` - Microsoft Azure
    * `:gcp` - Google Cloud Platform

  ## Endpoint Types

    * `:public` - Publicly accessible
    * `:protected` - Requires authentication (default)
    * `:private` - Private VPC endpoint

  ## Examples

      # List all endpoints
      {:ok, endpoints} = HfHub.InferenceEndpoints.list()

      # Create a GPU endpoint
      {:ok, endpoint} = HfHub.InferenceEndpoints.create("my-endpoint",
        repository: "bert-base-uncased",
        accelerator: :gpu,
        instance_size: :x1,
        instance_type: "g5.xlarge",
        region: "us-east-1",
        vendor: :aws,
        task: "text-classification"
      )

      # Pause endpoint to save costs
      {:ok, endpoint} = HfHub.InferenceEndpoints.pause("my-endpoint")

      # Resume when needed
      {:ok, endpoint} = HfHub.InferenceEndpoints.resume("my-endpoint")
  """

  alias HfHub.{Auth, HTTP}
  alias HfHub.InferenceEndpoints.Endpoint

  # Auth is used for get_token only

  @type accelerator :: :cpu | :gpu
  @type instance_size :: :x1 | :x2 | :x4 | :x8
  @type vendor :: :aws | :azure | :gcp
  @type endpoint_type :: :public | :protected | :private

  # List endpoints

  @doc """
  Lists all inference endpoints.

  ## Options

    * `:namespace` - Organization namespace (default: current user)
    * `:token` - Authentication token

  ## Examples

      {:ok, endpoints} = HfHub.InferenceEndpoints.list()
      {:ok, endpoints} = HfHub.InferenceEndpoints.list(namespace: "my-org")
  """
  @spec list(keyword()) :: {:ok, [Endpoint.t()]} | {:error, term()}
  def list(opts \\ []) do
    token = opts[:token] || get_token_value()
    namespace = opts[:namespace] || get_default_namespace(token)

    case namespace do
      {:error, reason} ->
        {:error, reason}

      namespace ->
        case HTTP.get("/api/inference-endpoints/#{namespace}", token: token) do
          {:ok, %{"items" => endpoints}} ->
            {:ok, Enum.map(endpoints, &Endpoint.from_response/1)}

          {:ok, endpoints} when is_list(endpoints) ->
            {:ok, Enum.map(endpoints, &Endpoint.from_response/1)}

          error ->
            error
        end
    end
  end

  # Get endpoint

  @doc """
  Gets an endpoint by name.

  ## Arguments

    * `name` - Endpoint name

  ## Options

    * `:namespace` - Organization namespace (default: current user)
    * `:token` - Authentication token

  ## Examples

      {:ok, endpoint} = HfHub.InferenceEndpoints.get("my-endpoint")
      {:ok, endpoint} = HfHub.InferenceEndpoints.get("my-endpoint", namespace: "my-org")
  """
  @spec get(String.t(), keyword()) :: {:ok, Endpoint.t()} | {:error, term()}
  def get(name, opts \\ []) do
    token = opts[:token] || get_token_value()
    namespace = opts[:namespace] || get_default_namespace(token)

    case namespace do
      {:error, reason} ->
        {:error, reason}

      namespace ->
        case HTTP.get("/api/inference-endpoints/#{namespace}/#{name}", token: token) do
          {:ok, response} -> {:ok, Endpoint.from_response(response)}
          error -> error
        end
    end
  end

  # Create endpoint

  @doc """
  Creates a new inference endpoint.

  ## Arguments

    * `name` - Endpoint name

  ## Required Options

    * `:repository` - Model repository ID (e.g., "bert-base-uncased")
    * `:accelerator` - `:cpu` or `:gpu`
    * `:instance_size` - `:x1`, `:x2`, `:x4`, or `:x8`
    * `:instance_type` - Instance type (e.g., "g5.xlarge")
    * `:region` - Cloud region (e.g., "us-east-1")
    * `:vendor` - Cloud vendor: `:aws`, `:azure`, or `:gcp`

  ## Optional

    * `:framework` - "pytorch", "tensorflow", etc. (default: "pytorch")
    * `:task` - ML task (e.g., "text-classification")
    * `:namespace` - Organization namespace (default: current user)
    * `:min_replica` - Minimum replicas (default: 0)
    * `:max_replica` - Maximum replicas (default: 1)
    * `:scale_to_zero_timeout` - Seconds before scaling to zero
    * `:type` - `:public`, `:protected`, or `:private` (default: `:protected`)
    * `:custom_image` - Custom Docker image configuration
    * `:token` - Authentication token

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

      {:ok, endpoint} = HfHub.InferenceEndpoints.create("my-endpoint",
        repository: "sentence-transformers/all-MiniLM-L6-v2",
        accelerator: :cpu,
        instance_size: :x2,
        instance_type: "c6i.xlarge",
        region: "eu-west-1",
        vendor: :aws,
        min_replica: 1,
        max_replica: 4,
        scale_to_zero_timeout: 300
      )
  """
  @spec create(String.t(), keyword()) :: {:ok, Endpoint.t()} | {:error, term()}
  def create(name, opts) do
    token = opts[:token] || get_token_value()
    namespace = opts[:namespace] || get_default_namespace(token)

    case namespace do
      {:error, reason} ->
        {:error, reason}

      namespace ->
        body = build_create_body(name, opts)

        case HTTP.post("/api/inference-endpoints/#{namespace}", body, token: token) do
          {:ok, response} -> {:ok, Endpoint.from_response(response)}
          error -> error
        end
    end
  end

  # Update endpoint

  @doc """
  Updates an existing endpoint.

  Only provided options are updated; others remain unchanged.

  ## Arguments

    * `name` - Endpoint name

  ## Options

    * `:namespace` - Organization namespace
    * `:accelerator` - `:cpu` or `:gpu`
    * `:instance_size` - `:x1`, `:x2`, `:x4`, or `:x8`
    * `:instance_type` - Instance type
    * `:min_replica` - Minimum replicas
    * `:max_replica` - Maximum replicas
    * `:scale_to_zero_timeout` - Seconds before scaling to zero
    * `:repository` - Model repository ID
    * `:framework` - Framework ("pytorch", "tensorflow", etc.)
    * `:revision` - Model revision
    * `:task` - ML task
    * `:token` - Authentication token

  ## Examples

      {:ok, endpoint} = HfHub.InferenceEndpoints.update("my-endpoint",
        instance_size: :x2,
        max_replica: 4
      )

      {:ok, endpoint} = HfHub.InferenceEndpoints.update("my-endpoint",
        repository: "bert-large-uncased"
      )
  """
  @spec update(String.t(), keyword()) :: {:ok, Endpoint.t()} | {:error, term()}
  def update(name, opts \\ []) do
    token = opts[:token] || get_token_value()
    namespace = opts[:namespace] || get_default_namespace(token)

    case namespace do
      {:error, reason} ->
        {:error, reason}

      namespace ->
        body = build_update_body(opts)

        case HTTP.put("/api/inference-endpoints/#{namespace}/#{name}", body, token: token) do
          {:ok, response} -> {:ok, Endpoint.from_response(response)}
          error -> error
        end
    end
  end

  # Delete endpoint

  @doc """
  Deletes an endpoint.

  **Warning**: This is destructive and cannot be undone.

  ## Arguments

    * `name` - Endpoint name

  ## Options

    * `:namespace` - Organization namespace
    * `:token` - Authentication token

  ## Examples

      :ok = HfHub.InferenceEndpoints.delete("my-endpoint")
  """
  @spec delete(String.t(), keyword()) :: :ok | {:error, term()}
  def delete(name, opts \\ []) do
    token = opts[:token] || get_token_value()
    namespace = opts[:namespace] || get_default_namespace(token)

    case namespace do
      {:error, reason} ->
        {:error, reason}

      namespace ->
        HTTP.delete("/api/inference-endpoints/#{namespace}/#{name}", token: token)
    end
  end

  # Pause endpoint

  @doc """
  Pauses an endpoint.

  Paused endpoints don't incur compute costs but retain configuration.
  They must be resumed before they can serve requests.

  ## Arguments

    * `name` - Endpoint name

  ## Options

    * `:namespace` - Organization namespace
    * `:token` - Authentication token

  ## Examples

      {:ok, endpoint} = HfHub.InferenceEndpoints.pause("my-endpoint")
  """
  @spec pause(String.t(), keyword()) :: {:ok, Endpoint.t()} | {:error, term()}
  def pause(name, opts \\ []) do
    token = opts[:token] || get_token_value()
    namespace = opts[:namespace] || get_default_namespace(token)

    case namespace do
      {:error, reason} ->
        {:error, reason}

      namespace ->
        case HTTP.post("/api/inference-endpoints/#{namespace}/#{name}/pause", nil, token: token) do
          {:ok, response} -> {:ok, Endpoint.from_response(response)}
          error -> error
        end
    end
  end

  # Resume endpoint

  @doc """
  Resumes a paused endpoint.

  ## Arguments

    * `name` - Endpoint name

  ## Options

    * `:namespace` - Organization namespace
    * `:token` - Authentication token

  ## Examples

      {:ok, endpoint} = HfHub.InferenceEndpoints.resume("my-endpoint")
  """
  @spec resume(String.t(), keyword()) :: {:ok, Endpoint.t()} | {:error, term()}
  def resume(name, opts \\ []) do
    token = opts[:token] || get_token_value()
    namespace = opts[:namespace] || get_default_namespace(token)

    case namespace do
      {:error, reason} ->
        {:error, reason}

      namespace ->
        case HTTP.post("/api/inference-endpoints/#{namespace}/#{name}/resume", nil, token: token) do
          {:ok, response} -> {:ok, Endpoint.from_response(response)}
          error -> error
        end
    end
  end

  # Scale to zero

  @doc """
  Scales endpoint to zero replicas.

  Different from pause: the endpoint can auto-wake on incoming requests,
  while a paused endpoint must be explicitly resumed.

  ## Arguments

    * `name` - Endpoint name

  ## Options

    * `:namespace` - Organization namespace
    * `:token` - Authentication token

  ## Examples

      {:ok, endpoint} = HfHub.InferenceEndpoints.scale_to_zero("my-endpoint")
  """
  @spec scale_to_zero(String.t(), keyword()) :: {:ok, Endpoint.t()} | {:error, term()}
  def scale_to_zero(name, opts \\ []) do
    token = opts[:token] || get_token_value()
    namespace = opts[:namespace] || get_default_namespace(token)

    case namespace do
      {:error, reason} ->
        {:error, reason}

      namespace ->
        case HTTP.post(
               "/api/inference-endpoints/#{namespace}/#{name}/scale-to-zero",
               nil,
               token: token
             ) do
          {:ok, response} -> {:ok, Endpoint.from_response(response)}
          error -> error
        end
    end
  end

  # Private helpers

  defp get_token_value do
    case Auth.get_token() do
      {:ok, token} -> token
      {:error, _} -> nil
    end
  end

  defp get_default_namespace(nil), do: {:error, :no_token}

  defp get_default_namespace(token) do
    case HTTP.get("/api/whoami-v2", token: token) do
      {:ok, data} -> Map.get(data, "name")
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_create_body(name, opts) do
    %{
      "name" => name,
      "model" => build_model_config(opts),
      "compute" => build_compute_config(opts),
      "provider" => %{
        "vendor" => vendor_to_string(opts[:vendor]),
        "region" => opts[:region]
      },
      "type" => type_to_string(opts[:type] || :protected)
    }
    |> maybe_add_custom_image(opts)
  end

  defp build_model_config(opts) do
    %{
      "repository" => opts[:repository],
      "framework" => opts[:framework] || "pytorch",
      "task" => opts[:task]
    }
    |> reject_nil_values()
  end

  defp build_compute_config(opts) do
    config = %{
      "accelerator" => accelerator_to_string(opts[:accelerator]),
      "instanceSize" => instance_size_to_string(opts[:instance_size]),
      "instanceType" => opts[:instance_type]
    }

    scaling = build_scaling_config(opts)

    if map_size(scaling) > 0 do
      Map.put(config, "scaling", scaling)
    else
      config
    end
  end

  defp build_scaling_config(opts) do
    %{}
    |> maybe_put("minReplica", opts[:min_replica])
    |> maybe_put("maxReplica", opts[:max_replica])
    |> maybe_put("scaleToZeroTimeout", opts[:scale_to_zero_timeout])
  end

  defp maybe_add_custom_image(body, opts) do
    case opts[:custom_image] do
      nil -> body
      image -> Map.put(body, "custom_image", image)
    end
  end

  defp build_update_body(opts) do
    %{}
    |> maybe_add_compute_update(opts)
    |> maybe_add_model_update(opts)
  end

  defp maybe_add_compute_update(body, opts) do
    compute =
      %{}
      |> maybe_put("accelerator", opts[:accelerator] && accelerator_to_string(opts[:accelerator]))
      |> maybe_put(
        "instanceSize",
        opts[:instance_size] && instance_size_to_string(opts[:instance_size])
      )
      |> maybe_put("instanceType", opts[:instance_type])

    scaling =
      %{}
      |> maybe_put("minReplica", opts[:min_replica])
      |> maybe_put("maxReplica", opts[:max_replica])
      |> maybe_put("scaleToZeroTimeout", opts[:scale_to_zero_timeout])

    compute =
      if map_size(scaling) > 0 do
        Map.put(compute, "scaling", scaling)
      else
        compute
      end

    if map_size(compute) > 0, do: Map.put(body, "compute", compute), else: body
  end

  defp maybe_add_model_update(body, opts) do
    model =
      %{}
      |> maybe_put("repository", opts[:repository])
      |> maybe_put("framework", opts[:framework])
      |> maybe_put("revision", opts[:revision])
      |> maybe_put("task", opts[:task])

    if map_size(model) > 0, do: Map.put(body, "model", model), else: body
  end

  defp accelerator_to_string(:cpu), do: "cpu"
  defp accelerator_to_string(:gpu), do: "gpu"
  defp accelerator_to_string(nil), do: nil

  defp instance_size_to_string(:x1), do: "x1"
  defp instance_size_to_string(:x2), do: "x2"
  defp instance_size_to_string(:x4), do: "x4"
  defp instance_size_to_string(:x8), do: "x8"
  defp instance_size_to_string(nil), do: nil

  defp vendor_to_string(:aws), do: "aws"
  defp vendor_to_string(:azure), do: "azure"
  defp vendor_to_string(:gcp), do: "gcp"
  defp vendor_to_string(nil), do: nil

  defp type_to_string(:public), do: "public"
  defp type_to_string(:protected), do: "protected"
  defp type_to_string(:private), do: "private"

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp reject_nil_values(map) do
    map
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()
  end
end
