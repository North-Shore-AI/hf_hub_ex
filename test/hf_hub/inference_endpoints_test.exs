defmodule HfHub.InferenceEndpointsTest do
  use ExUnit.Case, async: false

  alias HfHub.InferenceEndpoints

  alias HfHub.InferenceEndpoints.{
    ComputeConfig,
    Endpoint,
    ModelConfig,
    ProviderConfig,
    ScalingConfig
  }

  setup do
    bypass = Bypass.open()

    original_url = Application.get_env(:hf_hub, :endpoint)
    Application.put_env(:hf_hub, :endpoint, "http://localhost:#{bypass.port}")

    on_exit(fn ->
      if original_url do
        Application.put_env(:hf_hub, :endpoint, original_url)
      else
        Application.delete_env(:hf_hub, :endpoint)
      end
    end)

    {:ok, bypass: bypass}
  end

  defp setup_whoami(bypass) do
    Bypass.stub(bypass, "GET", "/api/whoami-v2", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(
        200,
        Jason.encode!(%{
          "name" => "testuser",
          "email" => "test@example.com"
        })
      )
    end)
  end

  defp endpoint_response(name, opts \\ []) do
    %{
      "name" => name,
      "accountId" => Keyword.get(opts, :namespace, "testuser"),
      "status" => %{"state" => Keyword.get(opts, :status, "running")},
      "url" => Keyword.get(opts, :url, "https://#{name}.endpoints.huggingface.cloud"),
      "model" => build_model_config(opts),
      "compute" => build_compute_config(opts),
      "provider" => build_provider_config(opts),
      "type" => Keyword.get(opts, :type, "protected"),
      "createdAt" => "2025-01-15T10:00:00Z",
      "updatedAt" => "2025-01-15T12:00:00Z"
    }
  end

  defp build_model_config(opts) do
    %{
      "repository" => Keyword.get(opts, :repository, "bert-base-uncased"),
      "framework" => Keyword.get(opts, :framework, "pytorch"),
      "task" => Keyword.get(opts, :task, "text-classification")
    }
  end

  defp build_compute_config(opts) do
    %{
      "accelerator" => Keyword.get(opts, :accelerator, "gpu"),
      "instanceSize" => Keyword.get(opts, :instance_size, "x1"),
      "instanceType" => Keyword.get(opts, :instance_type, "g5.xlarge"),
      "scaling" => %{
        "minReplica" => Keyword.get(opts, :min_replica, 0),
        "maxReplica" => Keyword.get(opts, :max_replica, 1),
        "scaleToZeroTimeout" => Keyword.get(opts, :scale_to_zero_timeout)
      }
    }
  end

  defp build_provider_config(opts) do
    %{
      "vendor" => Keyword.get(opts, :vendor, "aws"),
      "region" => Keyword.get(opts, :region, "us-east-1")
    }
  end

  describe "list/1" do
    test "lists endpoints for user", %{bypass: bypass} do
      setup_whoami(bypass)

      Bypass.expect_once(bypass, "GET", "/api/inference-endpoints/testuser", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "items" => [
              endpoint_response("endpoint-1"),
              endpoint_response("endpoint-2", status: "paused")
            ]
          })
        )
      end)

      assert {:ok, endpoints} = InferenceEndpoints.list(token: "test_token")
      assert length(endpoints) == 2

      [e1, e2] = endpoints
      assert e1.name == "endpoint-1"
      assert e1.status == :running

      assert e2.name == "endpoint-2"
      assert e2.status == :paused
    end

    test "lists endpoints for organization", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/inference-endpoints/my-org", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "items" => [
              endpoint_response("org-endpoint", namespace: "my-org")
            ]
          })
        )
      end)

      assert {:ok, endpoints} = InferenceEndpoints.list(namespace: "my-org", token: "test_token")
      assert length(endpoints) == 1
      assert hd(endpoints).namespace == "my-org"
    end

    test "handles empty list response", %{bypass: bypass} do
      setup_whoami(bypass)

      Bypass.expect_once(bypass, "GET", "/api/inference-endpoints/testuser", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"items" => []}))
      end)

      assert {:ok, []} = InferenceEndpoints.list(token: "test_token")
    end

    test "handles list array response", %{bypass: bypass} do
      setup_whoami(bypass)

      Bypass.expect_once(bypass, "GET", "/api/inference-endpoints/testuser", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!([endpoint_response("endpoint-1")]))
      end)

      assert {:ok, endpoints} = InferenceEndpoints.list(token: "test_token")
      assert length(endpoints) == 1
    end

    test "handles 401 unauthorized", %{bypass: bypass} do
      setup_whoami(bypass)

      Bypass.expect_once(bypass, "GET", "/api/inference-endpoints/testuser", fn conn ->
        Plug.Conn.resp(conn, 401, "")
      end)

      assert {:error, :unauthorized} = InferenceEndpoints.list(token: "bad_token")
    end
  end

  describe "get/2" do
    test "gets endpoint details", %{bypass: bypass} do
      setup_whoami(bypass)

      Bypass.expect_once(bypass, "GET", "/api/inference-endpoints/testuser/my-endpoint", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(
            endpoint_response("my-endpoint",
              repository: "sentence-transformers/all-MiniLM-L6-v2",
              task: "feature-extraction",
              accelerator: "gpu",
              instance_size: "x2",
              min_replica: 1,
              max_replica: 4,
              scale_to_zero_timeout: 300
            )
          )
        )
      end)

      assert {:ok, endpoint} = InferenceEndpoints.get("my-endpoint", token: "test_token")
      assert %Endpoint{} = endpoint
      assert endpoint.name == "my-endpoint"
      assert endpoint.namespace == "testuser"
      assert endpoint.status == :running
      assert endpoint.url == "https://my-endpoint.endpoints.huggingface.cloud"

      assert %ModelConfig{} = endpoint.model
      assert endpoint.model.repository == "sentence-transformers/all-MiniLM-L6-v2"
      assert endpoint.model.framework == "pytorch"
      assert endpoint.model.task == "feature-extraction"

      assert %ComputeConfig{} = endpoint.compute
      assert endpoint.compute.accelerator == :gpu
      assert endpoint.compute.instance_size == "x2"
      assert endpoint.compute.instance_type == "g5.xlarge"

      assert %ScalingConfig{} = endpoint.compute.scaling
      assert endpoint.compute.scaling.min_replica == 1
      assert endpoint.compute.scaling.max_replica == 4
      assert endpoint.compute.scaling.scale_to_zero_timeout == 300

      assert %ProviderConfig{} = endpoint.provider
      assert endpoint.provider.vendor == :aws
      assert endpoint.provider.region == "us-east-1"

      assert endpoint.type == :protected
      assert %DateTime{} = endpoint.created_at
      assert %DateTime{} = endpoint.updated_at
    end

    test "gets endpoint from organization", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/inference-endpoints/my-org/org-endpoint", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(endpoint_response("org-endpoint", namespace: "my-org"))
        )
      end)

      assert {:ok, endpoint} =
               InferenceEndpoints.get("org-endpoint", namespace: "my-org", token: "test_token")

      assert endpoint.name == "org-endpoint"
      assert endpoint.namespace == "my-org"
    end

    test "handles 404 not found", %{bypass: bypass} do
      setup_whoami(bypass)

      Bypass.expect_once(bypass, "GET", "/api/inference-endpoints/testuser/missing", fn conn ->
        Plug.Conn.resp(conn, 404, "")
      end)

      assert {:error, :not_found} = InferenceEndpoints.get("missing", token: "test_token")
    end

    test "handles 403 forbidden", %{bypass: bypass} do
      setup_whoami(bypass)

      Bypass.expect_once(bypass, "GET", "/api/inference-endpoints/testuser/forbidden", fn conn ->
        Plug.Conn.resp(conn, 403, "")
      end)

      assert {:error, :forbidden} = InferenceEndpoints.get("forbidden", token: "test_token")
    end
  end

  describe "create/2" do
    test "creates CPU endpoint", %{bypass: bypass} do
      setup_whoami(bypass)

      Bypass.expect_once(bypass, "POST", "/api/inference-endpoints/testuser", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["name"] == "my-cpu-endpoint"
        assert params["model"]["repository"] == "bert-base-uncased"
        assert params["model"]["framework"] == "pytorch"
        assert params["compute"]["accelerator"] == "cpu"
        assert params["compute"]["instanceSize"] == "x1"
        assert params["compute"]["instanceType"] == "c6i.xlarge"
        assert params["provider"]["vendor"] == "aws"
        assert params["provider"]["region"] == "us-east-1"
        assert params["type"] == "protected"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(
            endpoint_response("my-cpu-endpoint",
              accelerator: "cpu",
              instance_type: "c6i.xlarge",
              status: "pending"
            )
          )
        )
      end)

      assert {:ok, endpoint} =
               InferenceEndpoints.create("my-cpu-endpoint",
                 repository: "bert-base-uncased",
                 accelerator: :cpu,
                 instance_size: :x1,
                 instance_type: "c6i.xlarge",
                 region: "us-east-1",
                 vendor: :aws,
                 token: "test_token"
               )

      assert endpoint.name == "my-cpu-endpoint"
      assert endpoint.status == :pending
      assert endpoint.compute.accelerator == :cpu
    end

    test "creates GPU endpoint", %{bypass: bypass} do
      setup_whoami(bypass)

      Bypass.expect_once(bypass, "POST", "/api/inference-endpoints/testuser", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["compute"]["accelerator"] == "gpu"
        assert params["compute"]["instanceSize"] == "x2"
        assert params["model"]["task"] == "text-classification"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(
            endpoint_response("my-gpu-endpoint",
              accelerator: "gpu",
              instance_size: "x2",
              task: "text-classification"
            )
          )
        )
      end)

      assert {:ok, endpoint} =
               InferenceEndpoints.create("my-gpu-endpoint",
                 repository: "bert-base-uncased",
                 accelerator: :gpu,
                 instance_size: :x2,
                 instance_type: "g5.xlarge",
                 region: "us-east-1",
                 vendor: :aws,
                 task: "text-classification",
                 token: "test_token"
               )

      assert endpoint.compute.accelerator == :gpu
      assert endpoint.model.task == "text-classification"
    end

    test "creates endpoint with scaling config", %{bypass: bypass} do
      setup_whoami(bypass)

      Bypass.expect_once(bypass, "POST", "/api/inference-endpoints/testuser", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["compute"]["scaling"]["minReplica"] == 1
        assert params["compute"]["scaling"]["maxReplica"] == 4
        assert params["compute"]["scaling"]["scaleToZeroTimeout"] == 300

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(
            endpoint_response("scaled-endpoint",
              min_replica: 1,
              max_replica: 4,
              scale_to_zero_timeout: 300
            )
          )
        )
      end)

      assert {:ok, endpoint} =
               InferenceEndpoints.create("scaled-endpoint",
                 repository: "bert-base-uncased",
                 accelerator: :gpu,
                 instance_size: :x1,
                 instance_type: "g5.xlarge",
                 region: "us-east-1",
                 vendor: :aws,
                 min_replica: 1,
                 max_replica: 4,
                 scale_to_zero_timeout: 300,
                 token: "test_token"
               )

      assert endpoint.compute.scaling.min_replica == 1
      assert endpoint.compute.scaling.max_replica == 4
      assert endpoint.compute.scaling.scale_to_zero_timeout == 300
    end

    test "creates public endpoint", %{bypass: bypass} do
      setup_whoami(bypass)

      Bypass.expect_once(bypass, "POST", "/api/inference-endpoints/testuser", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["type"] == "public"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(endpoint_response("public-endpoint", type: "public")))
      end)

      assert {:ok, endpoint} =
               InferenceEndpoints.create("public-endpoint",
                 repository: "bert-base-uncased",
                 accelerator: :cpu,
                 instance_size: :x1,
                 instance_type: "c6i.xlarge",
                 region: "us-east-1",
                 vendor: :aws,
                 type: :public,
                 token: "test_token"
               )

      assert endpoint.type == :public
    end

    test "creates endpoint in organization", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/inference-endpoints/my-org", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(endpoint_response("org-endpoint", namespace: "my-org"))
        )
      end)

      assert {:ok, endpoint} =
               InferenceEndpoints.create("org-endpoint",
                 repository: "bert-base-uncased",
                 accelerator: :cpu,
                 instance_size: :x1,
                 instance_type: "c6i.xlarge",
                 region: "us-east-1",
                 vendor: :aws,
                 namespace: "my-org",
                 token: "test_token"
               )

      assert endpoint.namespace == "my-org"
    end

    test "creates endpoint with Azure vendor", %{bypass: bypass} do
      setup_whoami(bypass)

      Bypass.expect_once(bypass, "POST", "/api/inference-endpoints/testuser", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["provider"]["vendor"] == "azure"
        assert params["provider"]["region"] == "eastus"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(endpoint_response("azure-endpoint", vendor: "azure", region: "eastus"))
        )
      end)

      assert {:ok, endpoint} =
               InferenceEndpoints.create("azure-endpoint",
                 repository: "bert-base-uncased",
                 accelerator: :cpu,
                 instance_size: :x1,
                 instance_type: "Standard_F4s_v2",
                 region: "eastus",
                 vendor: :azure,
                 token: "test_token"
               )

      assert endpoint.provider.vendor == :azure
      assert endpoint.provider.region == "eastus"
    end

    test "creates endpoint with GCP vendor", %{bypass: bypass} do
      setup_whoami(bypass)

      Bypass.expect_once(bypass, "POST", "/api/inference-endpoints/testuser", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["provider"]["vendor"] == "gcp"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(endpoint_response("gcp-endpoint", vendor: "gcp", region: "us-central1"))
        )
      end)

      assert {:ok, endpoint} =
               InferenceEndpoints.create("gcp-endpoint",
                 repository: "bert-base-uncased",
                 accelerator: :gpu,
                 instance_size: :x1,
                 instance_type: "n1-standard-4",
                 region: "us-central1",
                 vendor: :gcp,
                 token: "test_token"
               )

      assert endpoint.provider.vendor == :gcp
    end

    test "handles 401 unauthorized", %{bypass: bypass} do
      setup_whoami(bypass)

      Bypass.expect_once(bypass, "POST", "/api/inference-endpoints/testuser", fn conn ->
        Plug.Conn.resp(conn, 401, "")
      end)

      assert {:error, :unauthorized} =
               InferenceEndpoints.create("endpoint",
                 repository: "bert-base-uncased",
                 accelerator: :cpu,
                 instance_size: :x1,
                 instance_type: "c6i.xlarge",
                 region: "us-east-1",
                 vendor: :aws,
                 token: "bad_token"
               )
    end

    test "handles duplicate name conflict", %{bypass: bypass} do
      setup_whoami(bypass)

      Bypass.expect_once(bypass, "POST", "/api/inference-endpoints/testuser", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          409,
          Jason.encode!(%{"error" => "Endpoint with this name already exists"})
        )
      end)

      assert {:error, {:conflict, _}} =
               InferenceEndpoints.create("existing-endpoint",
                 repository: "bert-base-uncased",
                 accelerator: :cpu,
                 instance_size: :x1,
                 instance_type: "c6i.xlarge",
                 region: "us-east-1",
                 vendor: :aws,
                 token: "test_token"
               )
    end
  end

  describe "update/2" do
    test "updates instance size", %{bypass: bypass} do
      setup_whoami(bypass)

      Bypass.expect_once(bypass, "PUT", "/api/inference-endpoints/testuser/my-endpoint", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["compute"]["instanceSize"] == "x4"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(endpoint_response("my-endpoint", instance_size: "x4")))
      end)

      assert {:ok, endpoint} =
               InferenceEndpoints.update("my-endpoint",
                 instance_size: :x4,
                 token: "test_token"
               )

      assert endpoint.compute.instance_size == "x4"
    end

    test "updates scaling limits", %{bypass: bypass} do
      setup_whoami(bypass)

      Bypass.expect_once(bypass, "PUT", "/api/inference-endpoints/testuser/my-endpoint", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["compute"]["scaling"]["minReplica"] == 2
        assert params["compute"]["scaling"]["maxReplica"] == 8

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(endpoint_response("my-endpoint", min_replica: 2, max_replica: 8))
        )
      end)

      assert {:ok, endpoint} =
               InferenceEndpoints.update("my-endpoint",
                 min_replica: 2,
                 max_replica: 8,
                 token: "test_token"
               )

      assert endpoint.compute.scaling.min_replica == 2
      assert endpoint.compute.scaling.max_replica == 8
    end

    test "updates model repository", %{bypass: bypass} do
      setup_whoami(bypass)

      Bypass.expect_once(bypass, "PUT", "/api/inference-endpoints/testuser/my-endpoint", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["model"]["repository"] == "bert-large-uncased"
        assert params["model"]["revision"] == "main"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(endpoint_response("my-endpoint", repository: "bert-large-uncased"))
        )
      end)

      assert {:ok, endpoint} =
               InferenceEndpoints.update("my-endpoint",
                 repository: "bert-large-uncased",
                 revision: "main",
                 token: "test_token"
               )

      assert endpoint.model.repository == "bert-large-uncased"
    end

    test "updates accelerator", %{bypass: bypass} do
      setup_whoami(bypass)

      Bypass.expect_once(bypass, "PUT", "/api/inference-endpoints/testuser/my-endpoint", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["compute"]["accelerator"] == "gpu"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(endpoint_response("my-endpoint", accelerator: "gpu")))
      end)

      assert {:ok, endpoint} =
               InferenceEndpoints.update("my-endpoint",
                 accelerator: :gpu,
                 token: "test_token"
               )

      assert endpoint.compute.accelerator == :gpu
    end

    test "handles 404 not found", %{bypass: bypass} do
      setup_whoami(bypass)

      Bypass.expect_once(bypass, "PUT", "/api/inference-endpoints/testuser/missing", fn conn ->
        Plug.Conn.resp(conn, 404, "")
      end)

      assert {:error, :not_found} =
               InferenceEndpoints.update("missing",
                 instance_size: :x2,
                 token: "test_token"
               )
    end
  end

  describe "delete/2" do
    test "deletes endpoint", %{bypass: bypass} do
      setup_whoami(bypass)

      Bypass.expect_once(
        bypass,
        "DELETE",
        "/api/inference-endpoints/testuser/my-endpoint",
        fn conn ->
          Plug.Conn.resp(conn, 204, "")
        end
      )

      assert :ok = InferenceEndpoints.delete("my-endpoint", token: "test_token")
    end

    test "deletes endpoint from organization", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "DELETE",
        "/api/inference-endpoints/my-org/org-endpoint",
        fn conn ->
          Plug.Conn.resp(conn, 204, "")
        end
      )

      assert :ok =
               InferenceEndpoints.delete("org-endpoint",
                 namespace: "my-org",
                 token: "test_token"
               )
    end

    test "handles 404 not found", %{bypass: bypass} do
      setup_whoami(bypass)

      Bypass.expect_once(bypass, "DELETE", "/api/inference-endpoints/testuser/missing", fn conn ->
        Plug.Conn.resp(conn, 404, "")
      end)

      assert {:error, :not_found} = InferenceEndpoints.delete("missing", token: "test_token")
    end

    test "handles 401 unauthorized", %{bypass: bypass} do
      setup_whoami(bypass)

      Bypass.expect_once(bypass, "DELETE", "/api/inference-endpoints/testuser/endpoint", fn conn ->
        Plug.Conn.resp(conn, 401, "")
      end)

      assert {:error, :unauthorized} = InferenceEndpoints.delete("endpoint", token: "bad_token")
    end
  end

  describe "pause/2" do
    test "pauses running endpoint", %{bypass: bypass} do
      setup_whoami(bypass)

      Bypass.expect_once(
        bypass,
        "POST",
        "/api/inference-endpoints/testuser/my-endpoint/pause",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(200, Jason.encode!(endpoint_response("my-endpoint", status: "paused")))
        end
      )

      assert {:ok, endpoint} = InferenceEndpoints.pause("my-endpoint", token: "test_token")
      assert endpoint.status == :paused
    end

    test "pauses endpoint in organization", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/inference-endpoints/my-org/org-endpoint/pause",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!(endpoint_response("org-endpoint", namespace: "my-org", status: "paused"))
          )
        end
      )

      assert {:ok, endpoint} =
               InferenceEndpoints.pause("org-endpoint",
                 namespace: "my-org",
                 token: "test_token"
               )

      assert endpoint.status == :paused
    end

    test "handles 404 not found", %{bypass: bypass} do
      setup_whoami(bypass)

      Bypass.expect_once(
        bypass,
        "POST",
        "/api/inference-endpoints/testuser/missing/pause",
        fn conn ->
          Plug.Conn.resp(conn, 404, "")
        end
      )

      assert {:error, :not_found} = InferenceEndpoints.pause("missing", token: "test_token")
    end

    test "handles 401 unauthorized", %{bypass: bypass} do
      setup_whoami(bypass)

      Bypass.expect_once(
        bypass,
        "POST",
        "/api/inference-endpoints/testuser/endpoint/pause",
        fn conn ->
          Plug.Conn.resp(conn, 401, "")
        end
      )

      assert {:error, :unauthorized} = InferenceEndpoints.pause("endpoint", token: "bad_token")
    end
  end

  describe "resume/2" do
    test "resumes paused endpoint", %{bypass: bypass} do
      setup_whoami(bypass)

      Bypass.expect_once(
        bypass,
        "POST",
        "/api/inference-endpoints/testuser/my-endpoint/resume",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!(endpoint_response("my-endpoint", status: "initializing"))
          )
        end
      )

      assert {:ok, endpoint} = InferenceEndpoints.resume("my-endpoint", token: "test_token")
      assert endpoint.status == :initializing
    end

    test "resumes endpoint in organization", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/inference-endpoints/my-org/org-endpoint/resume",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!(
              endpoint_response("org-endpoint", namespace: "my-org", status: "initializing")
            )
          )
        end
      )

      assert {:ok, endpoint} =
               InferenceEndpoints.resume("org-endpoint",
                 namespace: "my-org",
                 token: "test_token"
               )

      assert endpoint.status == :initializing
    end

    test "handles 404 not found", %{bypass: bypass} do
      setup_whoami(bypass)

      Bypass.expect_once(
        bypass,
        "POST",
        "/api/inference-endpoints/testuser/missing/resume",
        fn conn ->
          Plug.Conn.resp(conn, 404, "")
        end
      )

      assert {:error, :not_found} = InferenceEndpoints.resume("missing", token: "test_token")
    end
  end

  describe "scale_to_zero/2" do
    test "scales endpoint to zero", %{bypass: bypass} do
      setup_whoami(bypass)

      Bypass.expect_once(
        bypass,
        "POST",
        "/api/inference-endpoints/testuser/my-endpoint/scale-to-zero",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!(endpoint_response("my-endpoint", status: "scaledToZero"))
          )
        end
      )

      assert {:ok, endpoint} = InferenceEndpoints.scale_to_zero("my-endpoint", token: "test_token")
      assert endpoint.status == :scaled_to_zero
    end

    test "scales endpoint in organization to zero", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/inference-endpoints/my-org/org-endpoint/scale-to-zero",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!(
              endpoint_response("org-endpoint", namespace: "my-org", status: "scaledToZero")
            )
          )
        end
      )

      assert {:ok, endpoint} =
               InferenceEndpoints.scale_to_zero("org-endpoint",
                 namespace: "my-org",
                 token: "test_token"
               )

      assert endpoint.status == :scaled_to_zero
    end

    test "handles 404 not found", %{bypass: bypass} do
      setup_whoami(bypass)

      Bypass.expect_once(
        bypass,
        "POST",
        "/api/inference-endpoints/testuser/missing/scale-to-zero",
        fn conn ->
          Plug.Conn.resp(conn, 404, "")
        end
      )

      assert {:error, :not_found} = InferenceEndpoints.scale_to_zero("missing", token: "test_token")
    end
  end

  describe "Endpoint.from_response/1" do
    test "parses all status types" do
      statuses = [
        {"pending", :pending},
        {"initializing", :initializing},
        {"updating", :updating},
        {"running", :running},
        {"paused", :paused},
        {"failed", :failed},
        {"scaledToZero", :scaled_to_zero}
      ]

      for {api_status, expected} <- statuses do
        response = %{
          "name" => "test",
          "status" => %{"state" => api_status}
        }

        endpoint = Endpoint.from_response(response)
        assert endpoint.status == expected, "Expected #{expected} for status '#{api_status}'"
      end
    end

    test "parses all endpoint types" do
      types = [
        {"public", :public},
        {"protected", :protected},
        {"private", :private}
      ]

      for {api_type, expected} <- types do
        response = %{
          "name" => "test",
          "type" => api_type
        }

        endpoint = Endpoint.from_response(response)
        assert endpoint.type == expected
      end
    end

    test "handles missing optional fields" do
      response = %{"name" => "minimal"}

      endpoint = Endpoint.from_response(response)
      assert endpoint.name == "minimal"
      assert endpoint.status == nil
      assert endpoint.model == nil
      assert endpoint.compute == nil
      assert endpoint.provider == nil
    end
  end

  describe "ComputeConfig.from_response/1" do
    test "parses accelerator types" do
      for {api_accel, expected} <- [{"cpu", :cpu}, {"gpu", :gpu}] do
        response = %{"accelerator" => api_accel}
        config = ComputeConfig.from_response(response)
        assert config.accelerator == expected
      end
    end

    test "handles unknown accelerator" do
      response = %{"accelerator" => "tpu"}
      config = ComputeConfig.from_response(response)
      assert config.accelerator == nil
    end
  end

  describe "ProviderConfig.from_response/1" do
    test "parses all vendor types" do
      for {api_vendor, expected} <- [{"aws", :aws}, {"azure", :azure}, {"gcp", :gcp}] do
        response = %{"vendor" => api_vendor, "region" => "us-east-1"}
        config = ProviderConfig.from_response(response)
        assert config.vendor == expected
      end
    end

    test "handles unknown vendor" do
      response = %{"vendor" => "ibm"}
      config = ProviderConfig.from_response(response)
      assert config.vendor == nil
    end
  end
end
