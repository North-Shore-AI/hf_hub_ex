defmodule HfHub.RepoTest do
  use ExUnit.Case, async: false
  alias HfHub.Repo

  setup do
    bypass = Bypass.open()

    # Configure HfHub to use the bypass URL
    # We need to update the application config or mock the Config module
    # HfHub.Config typically reads from application env.

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

  describe "create/2" do
    test "creates a public model repository", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/repos/create", fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["name"] == "model-name"
        assert params["organization"] == "org"
        assert params["type"] == "model"
        assert params["private"] == false

        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{
            "url" => "https://huggingface.co/org/model-name",
            "repo_id" => "org/model-name"
          })
        )
        |> Plug.Conn.put_resp_content_type("application/json")
      end)

      assert {:ok, result} = Repo.create("org/model-name", token: "token")
      assert result.url == "https://huggingface.co/org/model-name"
      assert result.repo_type == :model
    end

    test "creates a private repository", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/repos/create", fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["private"] == true

        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{
            "url" => "https://huggingface.co/org/model-private"
          })
        )
        |> Plug.Conn.put_resp_content_type("application/json")
      end)

      {:ok, _} = Repo.create("org/model-private", private: true, token: "token")
    end

    test "creates a space with SDK", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/repos/create", fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["type"] == "space"
        assert params["sdk"] == "gradio"

        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{
            "url" => "https://huggingface.co/spaces/org/space-name"
          })
        )
        |> Plug.Conn.put_resp_content_type("application/json")
      end)

      {:ok, result} =
        Repo.create("org/space-name", repo_type: :space, space_sdk: "gradio", token: "token")

      assert result.repo_type == :space
    end

    test "returns existing repo with exist_ok: true", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/repos/create", fn conn ->
        Plug.Conn.resp(
          conn,
          409,
          Jason.encode!(%{"error" => "You already created this model repo"})
        )
        |> Plug.Conn.put_resp_content_type("application/json")
      end)

      {:ok, result} = Repo.create("org/existing", exist_ok: true, token: "token")
      # Note: Since the endpoint is overridden to localhost, build_repo_url uses that endpoint
      # So we expect http://localhost:PORT/org/existing
      assert result.url =~ "http://localhost:#{bypass.port}/org/existing"
    end

    test "returns error without token (when required by API)", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/repos/create", fn conn ->
        Plug.Conn.resp(conn, 401, "")
      end)

      assert {:error, :unauthorized} = Repo.create("org/repo", token: "bad_token")
    end
  end

  describe "delete/2" do
    test "deletes existing repository", %{bypass: bypass} do
      Bypass.expect_once(bypass, "DELETE", "/api/repos/models/org%2Frepo", fn conn ->
        Plug.Conn.resp(conn, 200, "{}")
        |> Plug.Conn.put_resp_content_type("application/json")
      end)

      assert :ok = Repo.delete("org/repo", token: "token")
    end

    test "deletes existing dataset", %{bypass: bypass} do
      Bypass.expect_once(bypass, "DELETE", "/api/repos/datasets/org%2Fds", fn conn ->
        Plug.Conn.resp(conn, 200, "{}")
        |> Plug.Conn.put_resp_content_type("application/json")
      end)

      assert :ok = Repo.delete("org/ds", repo_type: :dataset, token: "token")
    end

    test "returns :ok with missing_ok when not found", %{bypass: bypass} do
      Bypass.expect_once(bypass, "DELETE", "/api/repos/models/org%2Fmissing", fn conn ->
        Plug.Conn.resp(conn, 404, "")
      end)

      assert :ok = Repo.delete("org/missing", missing_ok: true, token: "token")
    end
  end

  describe "update_settings/2" do
    test "updates visibility", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PUT", "/api/models/org%2Frepo/settings", fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["private"] == true

        Plug.Conn.resp(conn, 200, "{}")
        |> Plug.Conn.put_resp_content_type("application/json")
      end)

      assert :ok = Repo.update_settings("org/repo", private: true, token: "token")
    end
  end

  describe "move/3" do
    test "moves repository to new name", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/repos/move", fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["fromRepo"] == "old"
        assert params["toRepo"] == "new"

        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{
            "url" => "https://huggingface.co/new"
          })
        )
        |> Plug.Conn.put_resp_content_type("application/json")
      end)

      assert {:ok, result} = Repo.move("old", "new", token: "token")
      assert result.url == "https://huggingface.co/new"
    end
  end

  describe "exists?/2" do
    test "returns true for existing repo", %{bypass: bypass} do
      Bypass.expect_once(bypass, "HEAD", "/org/repo", fn conn ->
        Plug.Conn.resp(conn, 200, "")
      end)

      assert Repo.exists?("org/repo", token: "token")
    end

    test "returns false for non-existent repo", %{bypass: bypass} do
      Bypass.expect_once(bypass, "HEAD", "/org/missing", fn conn ->
        Plug.Conn.resp(conn, 404, "")
      end)

      refute Repo.exists?("org/missing", token: "token")
    end
  end

  describe "file_exists?/3" do
    test "returns true for existing file", %{bypass: bypass} do
      Bypass.expect_once(bypass, "HEAD", "/org/repo/resolve/main/config.json", fn conn ->
        Plug.Conn.resp(conn, 200, "")
      end)

      assert Repo.file_exists?("org/repo", "config.json", token: "token")
    end

    test "returns true for redirect (LFS)", %{bypass: bypass} do
      Bypass.expect_once(bypass, "HEAD", "/org/repo/resolve/main/model.safetensors", fn conn ->
        Plug.Conn.resp(conn, 302, "")
      end)

      assert Repo.file_exists?("org/repo", "model.safetensors", token: "token")
    end
  end

  describe "revision_exists?/3" do
    test "returns true for existing revision", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/models/org%2Frepo/revision/main", fn conn ->
        Plug.Conn.resp(conn, 200, "{}")
        |> Plug.Conn.put_resp_content_type("application/json")
      end)

      assert Repo.revision_exists?("org/repo", "main", token: "token")
    end

    test "returns false for missing revision", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/models/org%2Frepo/revision/missing", fn conn ->
        Plug.Conn.resp(conn, 404, "{}")
      end)

      refute Repo.revision_exists?("org/repo", "missing", token: "token")
    end
  end
end
