defmodule HfHub.SpacesTest do
  use ExUnit.Case, async: false

  alias HfHub.Spaces
  alias HfHub.Spaces.{SpaceRuntime, SpaceVariable}

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

  describe "get_runtime/2" do
    test "gets runtime for a running space", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/spaces/user%2Fmy-space/runtime", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "stage" => "RUNNING",
            "hardware" => %{"current" => "cpu-basic", "requested" => "cpu-basic"},
            "gcTimeout" => 300,
            "rawLogs" => true,
            "sdk" => "gradio",
            "sdkVersion" => "4.0.0"
          })
        )
      end)

      assert {:ok, runtime} = Spaces.get_runtime("user/my-space")
      assert %SpaceRuntime{} = runtime
      assert runtime.stage == :running
      assert runtime.hardware == "cpu-basic"
      assert runtime.requested_hardware == "cpu-basic"
      assert runtime.sleep_time == 300
      assert runtime.raw_logs == true
      assert runtime.sdk == "gradio"
      assert runtime.sdk_version == "4.0.0"
    end

    test "gets runtime for a paused space", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/spaces/user%2Fpaused-space/runtime", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "stage" => "PAUSED",
            "hardware" => %{"current" => "t4-small"},
            "sdk" => "streamlit"
          })
        )
      end)

      assert {:ok, runtime} = Spaces.get_runtime("user/paused-space")
      assert runtime.stage == :paused
      assert runtime.hardware == "t4-small"
    end

    test "gets runtime for a building space", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/spaces/user%2Fbuilding-space/runtime", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "stage" => "BUILDING",
            "hardware" => %{"current" => "cpu-basic"}
          })
        )
      end)

      assert {:ok, runtime} = Spaces.get_runtime("user/building-space")
      assert runtime.stage == :building
    end

    test "gets runtime for a sleeping space", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/spaces/user%2Fsleeping-space/runtime", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "stage" => "SLEEPING",
            "hardware" => %{"current" => "cpu-basic"}
          })
        )
      end)

      assert {:ok, runtime} = Spaces.get_runtime("user/sleeping-space")
      assert runtime.stage == :sleeping
    end

    test "handles 404 error", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/spaces/user%2Fmissing/runtime", fn conn ->
        Plug.Conn.resp(conn, 404, "")
      end)

      assert {:error, :not_found} = Spaces.get_runtime("user/missing")
    end

    test "handles 403 for private space", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/spaces/user%2Fprivate-space/runtime", fn conn ->
        Plug.Conn.resp(conn, 403, "")
      end)

      assert {:error, :forbidden} = Spaces.get_runtime("user/private-space")
    end
  end

  describe "get_variables/2" do
    test "gets all variables", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/spaces/user%2Fmy-space/variables", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "DEBUG" => %{
              "value" => "true",
              "description" => "Enable debug mode",
              "updatedAt" => "2025-01-15T10:00:00Z"
            },
            "API_URL" => %{
              "value" => "https://api.example.com"
            }
          })
        )
      end)

      assert {:ok, vars} = Spaces.get_variables("user/my-space")
      assert map_size(vars) == 2

      assert %SpaceVariable{key: "DEBUG", value: "true"} = vars["DEBUG"]
      assert vars["DEBUG"].description == "Enable debug mode"
      assert %DateTime{} = vars["DEBUG"].updated_at

      assert %SpaceVariable{key: "API_URL", value: "https://api.example.com"} = vars["API_URL"]
    end

    test "handles empty variables", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/spaces/user%2Fmy-space/variables", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{}))
      end)

      assert {:ok, vars} = Spaces.get_variables("user/my-space")
      assert vars == %{}
    end

    test "handles 404 error", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/spaces/user%2Fmissing/variables", fn conn ->
        Plug.Conn.resp(conn, 404, "")
      end)

      assert {:error, :not_found} = Spaces.get_variables("user/missing")
    end
  end

  describe "add_secret/4" do
    test "adds a secret", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/spaces/user%2Fmy-space/secrets", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["key"] == "API_KEY"
        assert params["value"] == "secret_value"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{}))
      end)

      assert :ok =
               Spaces.add_secret("user/my-space", "API_KEY", "secret_value", token: "test_token")
    end

    test "adds a secret with description", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/spaces/user%2Fmy-space/secrets", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["key"] == "API_KEY"
        assert params["description"] == "API key for external service"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{}))
      end)

      assert :ok =
               Spaces.add_secret("user/my-space", "API_KEY", "secret_value",
                 description: "API key for external service",
                 token: "test_token"
               )
    end

    test "handles 401 unauthorized", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/spaces/user%2Fmy-space/secrets", fn conn ->
        Plug.Conn.resp(conn, 401, "")
      end)

      assert {:error, :unauthorized} =
               Spaces.add_secret("user/my-space", "KEY", "value", token: "bad_token")
    end
  end

  describe "delete_secret/3" do
    test "deletes a secret", %{bypass: bypass} do
      Bypass.expect_once(bypass, "DELETE", "/api/spaces/user%2Fmy-space/secrets/API_KEY", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      assert :ok = Spaces.delete_secret("user/my-space", "API_KEY", token: "test_token")
    end

    test "handles 404 when secret not found", %{bypass: bypass} do
      Bypass.expect_once(bypass, "DELETE", "/api/spaces/user%2Fmy-space/secrets/MISSING", fn conn ->
        Plug.Conn.resp(conn, 404, "")
      end)

      assert {:error, :not_found} =
               Spaces.delete_secret("user/my-space", "MISSING", token: "test_token")
    end
  end

  describe "add_variable/4" do
    test "adds a variable", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/spaces/user%2Fmy-space/variables", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["key"] == "DEBUG"
        assert params["value"] == "true"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "value" => "true",
            "description" => nil,
            "updatedAt" => "2025-01-15T10:00:00Z"
          })
        )
      end)

      assert {:ok, var} = Spaces.add_variable("user/my-space", "DEBUG", "true", token: "test_token")
      assert %SpaceVariable{key: "DEBUG", value: "true"} = var
    end

    test "adds a variable with description", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/spaces/user%2Fmy-space/variables", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["description"] == "Enable debugging"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "value" => "true",
            "description" => "Enable debugging"
          })
        )
      end)

      assert {:ok, var} =
               Spaces.add_variable("user/my-space", "DEBUG", "true",
                 description: "Enable debugging",
                 token: "test_token"
               )

      assert var.description == "Enable debugging"
    end

    test "handles 401 unauthorized", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/spaces/user%2Fmy-space/variables", fn conn ->
        Plug.Conn.resp(conn, 401, "")
      end)

      assert {:error, :unauthorized} =
               Spaces.add_variable("user/my-space", "KEY", "value", token: "bad_token")
    end
  end

  describe "delete_variable/3" do
    test "deletes a variable", %{bypass: bypass} do
      Bypass.expect_once(bypass, "DELETE", "/api/spaces/user%2Fmy-space/variables/DEBUG", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      assert :ok = Spaces.delete_variable("user/my-space", "DEBUG", token: "test_token")
    end

    test "handles 404 when variable not found", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "DELETE",
        "/api/spaces/user%2Fmy-space/variables/MISSING",
        fn conn ->
          Plug.Conn.resp(conn, 404, "")
        end
      )

      assert {:error, :not_found} =
               Spaces.delete_variable("user/my-space", "MISSING", token: "test_token")
    end
  end

  describe "request_hardware/3" do
    test "requests GPU hardware", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/spaces/user%2Fmy-space/hardware", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["hardware"] == "t4-small"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "stage" => "RUNNING",
            "hardware" => %{"current" => "cpu-basic", "requested" => "t4-small"}
          })
        )
      end)

      assert {:ok, runtime} =
               Spaces.request_hardware("user/my-space", :t4_small, token: "test_token")

      assert runtime.requested_hardware == "t4-small"
    end

    test "requests hardware with sleep time", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/spaces/user%2Fmy-space/hardware", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["hardware"] == "a10g-small"
        assert params["sleepTime"] == 600

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "stage" => "RUNNING",
            "hardware" => %{"current" => "a10g-small"},
            "gcTimeout" => 600
          })
        )
      end)

      assert {:ok, runtime} =
               Spaces.request_hardware("user/my-space", :a10g_small,
                 sleep_time: 600,
                 token: "test_token"
               )

      assert runtime.sleep_time == 600
    end

    test "downgrades to CPU", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/spaces/user%2Fmy-space/hardware", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["hardware"] == "cpu-basic"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "stage" => "RUNNING",
            "hardware" => %{"current" => "cpu-basic"}
          })
        )
      end)

      assert {:ok, runtime} =
               Spaces.request_hardware("user/my-space", :cpu_basic, token: "test_token")

      assert runtime.hardware == "cpu-basic"
    end

    test "handles all hardware types", %{bypass: bypass} do
      hardware_mappings = [
        {:cpu_basic, "cpu-basic"},
        {:cpu_upgrade, "cpu-upgrade"},
        {:t4_small, "t4-small"},
        {:t4_medium, "t4-medium"},
        {:a10g_small, "a10g-small"},
        {:a10g_large, "a10g-large"},
        {:a100_large, "a100-large"},
        {:zero_a10g, "zero-a10g"}
      ]

      for {atom, string} <- hardware_mappings do
        Bypass.expect_once(bypass, "POST", "/api/spaces/user%2Fmy-space/hardware", fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          params = Jason.decode!(body)

          assert params["hardware"] == string

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!(%{
              "stage" => "RUNNING",
              "hardware" => %{"current" => string}
            })
          )
        end)

        assert {:ok, _} = Spaces.request_hardware("user/my-space", atom, token: "test_token")
      end
    end

    test "handles 401 unauthorized", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/spaces/user%2Fmy-space/hardware", fn conn ->
        Plug.Conn.resp(conn, 401, "")
      end)

      assert {:error, :unauthorized} =
               Spaces.request_hardware("user/my-space", :t4_small, token: "bad_token")
    end
  end

  describe "set_sleep_time/3" do
    test "sets sleep time", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/spaces/user%2Fmy-space/sleeptime", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["sleepTime"] == 300

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "stage" => "RUNNING",
            "gcTimeout" => 300
          })
        )
      end)

      assert {:ok, runtime} = Spaces.set_sleep_time("user/my-space", 300, token: "test_token")
      assert runtime.sleep_time == 300
    end

    test "disables sleep with -1", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/spaces/user%2Fmy-space/sleeptime", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["sleepTime"] == -1

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "stage" => "RUNNING",
            "gcTimeout" => -1
          })
        )
      end)

      assert {:ok, runtime} = Spaces.set_sleep_time("user/my-space", -1, token: "test_token")
      assert runtime.sleep_time == -1
    end
  end

  describe "request_storage/3" do
    test "requests storage", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/spaces/user%2Fmy-space/storage", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["storage"] == "small"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "stage" => "RUNNING",
            "storage" => "small"
          })
        )
      end)

      assert {:ok, runtime} = Spaces.request_storage("user/my-space", :small, token: "test_token")
      assert runtime.storage == "small"
    end

    test "requests medium storage", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/spaces/user%2Fmy-space/storage", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["storage"] == "medium"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "stage" => "RUNNING",
            "storage" => "medium"
          })
        )
      end)

      assert {:ok, runtime} = Spaces.request_storage("user/my-space", :medium, token: "test_token")
      assert runtime.storage == "medium"
    end

    test "requests large storage", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/spaces/user%2Fmy-space/storage", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["storage"] == "large"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "stage" => "RUNNING",
            "storage" => "large"
          })
        )
      end)

      assert {:ok, runtime} = Spaces.request_storage("user/my-space", :large, token: "test_token")
      assert runtime.storage == "large"
    end
  end

  describe "delete_storage/2" do
    test "deletes storage", %{bypass: bypass} do
      Bypass.expect_once(bypass, "DELETE", "/api/spaces/user%2Fmy-space/storage", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "stage" => "RUNNING",
            "storage" => nil
          })
        )
      end)

      assert {:ok, runtime} = Spaces.delete_storage("user/my-space", token: "test_token")
      assert runtime.storage == nil
    end

    test "handles 204 response and fetches runtime", %{bypass: bypass} do
      Bypass.expect_once(bypass, "DELETE", "/api/spaces/user%2Fmy-space/storage", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      Bypass.expect_once(bypass, "GET", "/api/spaces/user%2Fmy-space/runtime", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "stage" => "RUNNING",
            "hardware" => %{"current" => "cpu-basic"}
          })
        )
      end)

      assert {:ok, runtime} = Spaces.delete_storage("user/my-space", token: "test_token")
      assert runtime.stage == :running
    end
  end

  describe "pause/2" do
    test "pauses a space", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/spaces/user%2Fmy-space/pause", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "stage" => "PAUSED",
            "hardware" => %{"current" => "cpu-basic"}
          })
        )
      end)

      assert {:ok, runtime} = Spaces.pause("user/my-space", token: "test_token")
      assert runtime.stage == :paused
    end

    test "handles 401 unauthorized", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/spaces/user%2Fmy-space/pause", fn conn ->
        Plug.Conn.resp(conn, 401, "")
      end)

      assert {:error, :unauthorized} = Spaces.pause("user/my-space", token: "bad_token")
    end
  end

  describe "restart/2" do
    test "restarts a space", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/spaces/user%2Fmy-space/restart", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        # Body should be empty for normal restart
        assert body == "" or body == "null"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "stage" => "BUILDING",
            "hardware" => %{"current" => "cpu-basic"}
          })
        )
      end)

      assert {:ok, runtime} = Spaces.restart("user/my-space", token: "test_token")
      assert runtime.stage == :building
    end

    test "factory reboots a space", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/spaces/user%2Fmy-space/restart", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["factoryReboot"] == true

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "stage" => "BUILDING",
            "hardware" => %{"current" => "cpu-basic"}
          })
        )
      end)

      assert {:ok, runtime} =
               Spaces.restart("user/my-space", factory_reboot: true, token: "test_token")

      assert runtime.stage == :building
    end
  end

  describe "duplicate/2" do
    test "duplicates a space", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/spaces/gradio%2Fhello_world/duplicate", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "url" => "https://huggingface.co/spaces/user/hello_world"
          })
        )
      end)

      assert {:ok, repo_url} = Spaces.duplicate("gradio/hello_world", token: "test_token")
      assert repo_url.url == "https://huggingface.co/spaces/user/hello_world"
      assert repo_url.repo_type == :space
    end

    test "duplicates with target id", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/spaces/gradio%2Fhello_world/duplicate", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["toId"] == "user/my-copy"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "url" => "https://huggingface.co/spaces/user/my-copy"
          })
        )
      end)

      assert {:ok, repo_url} =
               Spaces.duplicate("gradio/hello_world", to_id: "user/my-copy", token: "test_token")

      assert repo_url.repo_id == "user/my-copy"
    end

    test "duplicates with all options", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/spaces/gradio%2Fhello_world/duplicate", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["toId"] == "user/my-copy"
        assert params["private"] == true
        assert params["hardware"] == "t4-small"
        assert params["storage"] == "medium"
        assert params["secrets"] == [%{"key" => "SECRET", "value" => "value"}]
        assert params["variables"] == [%{"key" => "VAR", "value" => "val"}]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "url" => "https://huggingface.co/spaces/user/my-copy"
          })
        )
      end)

      assert {:ok, _} =
               Spaces.duplicate("gradio/hello_world",
                 to_id: "user/my-copy",
                 private: true,
                 hardware: :t4_small,
                 storage: :medium,
                 secrets: [%{"key" => "SECRET", "value" => "value"}],
                 variables: [%{"key" => "VAR", "value" => "val"}],
                 token: "test_token"
               )
    end

    test "handles 401 unauthorized", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/spaces/gradio%2Fhello_world/duplicate", fn conn ->
        Plug.Conn.resp(conn, 401, "")
      end)

      assert {:error, :unauthorized} =
               Spaces.duplicate("gradio/hello_world", token: "bad_token")
    end

    test "handles 403 forbidden", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/spaces/private%2Fspace/duplicate", fn conn ->
        Plug.Conn.resp(conn, 403, "")
      end)

      assert {:error, :forbidden} = Spaces.duplicate("private/space", token: "test_token")
    end
  end
end
