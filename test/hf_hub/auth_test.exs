defmodule HfHub.AuthTest do
  use ExUnit.Case, async: false

  setup do
    # Clear environment and application config before each test
    original_token_env = System.get_env("HF_TOKEN")
    System.delete_env("HF_TOKEN")
    Application.delete_env(:hf_hub, :token)

    bypass = Bypass.open()

    on_exit(fn ->
      if original_token_env, do: System.put_env("HF_TOKEN", original_token_env)
      Application.delete_env(:hf_hub, :token)
      Application.delete_env(:hf_hub, :endpoint)
    end)

    {:ok, bypass: bypass}
  end

  describe "get_token/0" do
    test "returns error when no token is configured" do
      assert {:error, :no_token} = HfHub.Auth.get_token()
    end

    test "returns token from application config" do
      Application.put_env(:hf_hub, :token, "hf_app_token")
      assert {:ok, "hf_app_token"} = HfHub.Auth.get_token()
    end

    test "returns token from HF_TOKEN environment variable" do
      System.put_env("HF_TOKEN", "hf_env_token")
      assert {:ok, "hf_env_token"} = HfHub.Auth.get_token()
    end

    test "prefers application config over environment variable" do
      Application.put_env(:hf_hub, :token, "hf_app_token")
      System.put_env("HF_TOKEN", "hf_env_token")
      assert {:ok, "hf_app_token"} = HfHub.Auth.get_token()
    end
  end

  describe "set_token/1" do
    test "sets token in application config" do
      :ok = HfHub.Auth.set_token("hf_new_token")
      assert {:ok, "hf_new_token"} = HfHub.Auth.get_token()
    end
  end

  describe "logout/0" do
    test "removes token from application config" do
      Application.put_env(:hf_hub, :token, "hf_token")
      :ok = HfHub.Auth.logout()
      assert nil == Application.get_env(:hf_hub, :token)
    end
  end

  describe "validate_token/1" do
    test "validates correct token format" do
      assert :ok = HfHub.Auth.validate_token("hf_1234567890abc")
    end

    test "rejects token without hf_ prefix" do
      assert {:error, :invalid_token} = HfHub.Auth.validate_token("invalid_token")
    end

    test "rejects token that is too short" do
      assert {:error, :invalid_token} = HfHub.Auth.validate_token("hf_short")
    end
  end

  describe "auth_headers/1" do
    test "returns empty headers when no token is available" do
      assert {:ok, []} = HfHub.Auth.auth_headers()
    end

    test "returns authorization header with application config token" do
      Application.put_env(:hf_hub, :token, "hf_test_token")
      assert {:ok, [{"authorization", "Bearer hf_test_token"}]} = HfHub.Auth.auth_headers()
    end

    test "returns authorization header with provided token" do
      assert {:ok, [{"authorization", "Bearer hf_custom"}]} =
               HfHub.Auth.auth_headers(token: "hf_custom")
    end

    test "prefers provided token over application config" do
      Application.put_env(:hf_hub, :token, "hf_app_token")

      assert {:ok, [{"authorization", "Bearer hf_custom"}]} =
               HfHub.Auth.auth_headers(token: "hf_custom")
    end
  end

  describe "login/1" do
    test "stores token when provided directly", %{bypass: _bypass} do
      assert :ok = HfHub.Auth.login(token: "hf_valid_token_12345")
      assert {:ok, "hf_valid_token_12345"} = HfHub.Auth.get_token()
    end

    test "validates token format before storing" do
      assert {:error, :invalid_token} = HfHub.Auth.login(token: "bad_token")
      assert {:error, :no_token} = HfHub.Auth.get_token()
    end

    test "validates token with API when validate: true", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/whoami-v2", fn conn ->
        assert ["Bearer hf_valid_token_12345"] = Plug.Conn.get_req_header(conn, "authorization")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{name: "testuser"}))
      end)

      Application.put_env(:hf_hub, :endpoint, "http://localhost:#{bypass.port}")

      assert :ok = HfHub.Auth.login(token: "hf_valid_token_12345", validate: true)
      assert {:ok, "hf_valid_token_12345"} = HfHub.Auth.get_token()
    end

    test "returns error when API validation fails", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/whoami-v2", fn conn ->
        Plug.Conn.resp(conn, 401, "Unauthorized")
      end)

      Application.put_env(:hf_hub, :endpoint, "http://localhost:#{bypass.port}")

      assert {:error, :unauthorized} = HfHub.Auth.login(token: "hf_invalid_token_", validate: true)
      assert {:error, :no_token} = HfHub.Auth.get_token()
    end
  end

  describe "whoami/0" do
    test "returns user info when authenticated", %{bypass: bypass} do
      Application.put_env(:hf_hub, :token, "hf_valid_token_12345")
      Application.put_env(:hf_hub, :endpoint, "http://localhost:#{bypass.port}")

      Bypass.expect_once(bypass, "GET", "/api/whoami-v2", fn conn ->
        assert ["Bearer hf_valid_token_12345"] = Plug.Conn.get_req_header(conn, "authorization")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            name: "testuser",
            email: "test@example.com",
            fullname: "Test User",
            orgs: [%{name: "testorg"}]
          })
        )
      end)

      assert {:ok, user} = HfHub.Auth.whoami()
      assert user.username == "testuser"
      assert user.email == "test@example.com"
      assert user.fullname == "Test User"
      assert user.organizations == ["testorg"]
    end

    test "returns error when API returns unauthorized", %{bypass: bypass} do
      Application.put_env(:hf_hub, :token, "hf_expired_token_1")
      Application.put_env(:hf_hub, :endpoint, "http://localhost:#{bypass.port}")

      Bypass.expect_once(bypass, "GET", "/api/whoami-v2", fn conn ->
        Plug.Conn.resp(conn, 401, "Unauthorized")
      end)

      assert {:error, :unauthorized} = HfHub.Auth.whoami()
    end

    test "returns error when no token available" do
      assert {:error, :no_token} = HfHub.Auth.whoami()
    end

    test "handles missing optional fields", %{bypass: bypass} do
      Application.put_env(:hf_hub, :token, "hf_valid_token_12345")
      Application.put_env(:hf_hub, :endpoint, "http://localhost:#{bypass.port}")

      Bypass.expect_once(bypass, "GET", "/api/whoami-v2", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{name: "minimaluser"}))
      end)

      assert {:ok, user} = HfHub.Auth.whoami()
      assert user.username == "minimaluser"
      assert user.email == nil
      assert user.fullname == nil
      assert user.organizations == []
    end
  end
end
