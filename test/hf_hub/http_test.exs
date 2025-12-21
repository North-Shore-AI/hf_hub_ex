defmodule HfHub.HTTPTest do
  use ExUnit.Case, async: true

  setup do
    bypass = Bypass.open()
    {:ok, bypass: bypass}
  end

  describe "get/2" do
    test "makes successful GET request", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/test", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{status: "ok"}))
      end)

      url = "http://localhost:#{bypass.port}/api/test"
      assert {:ok, %{"status" => "ok"}} = HfHub.HTTP.get(url)
    end

    test "handles query parameters", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/test", fn conn ->
        assert conn.query_string == "foo=bar&baz=qux"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{status: "ok"}))
      end)

      url = "http://localhost:#{bypass.port}/api/test"
      assert {:ok, %{"status" => "ok"}} = HfHub.HTTP.get(url, params: [foo: "bar", baz: "qux"])
    end

    test "includes authorization header when token provided", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/test", fn conn ->
        assert ["Bearer test_token"] = Plug.Conn.get_req_header(conn, "authorization")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{status: "ok"}))
      end)

      url = "http://localhost:#{bypass.port}/api/test"
      assert {:ok, %{"status" => "ok"}} = HfHub.HTTP.get(url, token: "test_token")
    end

    test "handles 404 errors", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/test", fn conn ->
        Plug.Conn.resp(conn, 404, "Not Found")
      end)

      url = "http://localhost:#{bypass.port}/api/test"
      assert {:error, :not_found} = HfHub.HTTP.get(url)
    end

    test "handles 401 errors", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/test", fn conn ->
        Plug.Conn.resp(conn, 401, "Unauthorized")
      end)

      url = "http://localhost:#{bypass.port}/api/test"
      assert {:error, :unauthorized} = HfHub.HTTP.get(url)
    end

    test "handles 403 errors", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/test", fn conn ->
        Plug.Conn.resp(conn, 403, "Forbidden")
      end)

      url = "http://localhost:#{bypass.port}/api/test"
      assert {:error, :forbidden} = HfHub.HTTP.get(url)
    end
  end

  describe "post/3" do
    test "makes successful POST request", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/test", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{"data" => "value"}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{result: "created"}))
      end)

      url = "http://localhost:#{bypass.port}/api/test"
      assert {:ok, %{"result" => "created"}} = HfHub.HTTP.post(url, %{data: "value"})
    end

    test "includes authorization header when token provided", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/test", fn conn ->
        assert ["Bearer test_token"] = Plug.Conn.get_req_header(conn, "authorization")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{result: "ok"}))
      end)

      url = "http://localhost:#{bypass.port}/api/test"
      assert {:ok, %{"result" => "ok"}} = HfHub.HTTP.post(url, %{}, token: "test_token")
    end

    test "handles 404 errors", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/test", fn conn ->
        Plug.Conn.resp(conn, 404, "Not Found")
      end)

      url = "http://localhost:#{bypass.port}/api/test"
      assert {:error, :not_found} = HfHub.HTTP.post(url, %{})
    end
  end

  describe "download_file/3" do
    test "downloads file successfully", %{bypass: bypass} do
      content = "Hello, World!"

      Bypass.expect_once(bypass, "GET", "/test.txt", fn conn ->
        Plug.Conn.resp(conn, 200, content)
      end)

      url = "http://localhost:#{bypass.port}/test.txt"
      destination = Path.join(System.tmp_dir!(), "test_download.txt")

      on_exit(fn -> File.rm(destination) end)

      assert :ok = HfHub.HTTP.download_file(url, destination)
      assert File.read!(destination) == content
    end

    test "creates parent directories if they don't exist", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/test.txt", fn conn ->
        Plug.Conn.resp(conn, 200, "content")
      end)

      url = "http://localhost:#{bypass.port}/test.txt"
      destination = Path.join([System.tmp_dir!(), "subdir", "nested", "test.txt"])

      on_exit(fn ->
        File.rm(destination)
        File.rm_rf(Path.join(System.tmp_dir!(), "subdir"))
      end)

      assert :ok = HfHub.HTTP.download_file(url, destination)
      assert File.exists?(destination)
    end

    test "includes authorization header when token provided", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/test.txt", fn conn ->
        assert ["Bearer test_token"] = Plug.Conn.get_req_header(conn, "authorization")
        Plug.Conn.resp(conn, 200, "content")
      end)

      url = "http://localhost:#{bypass.port}/test.txt"
      destination = Path.join(System.tmp_dir!(), "test_auth.txt")

      on_exit(fn -> File.rm(destination) end)

      assert :ok = HfHub.HTTP.download_file(url, destination, token: "test_token")
    end

    test "handles 404 errors", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/test.txt", fn conn ->
        Plug.Conn.resp(conn, 404, "Not Found")
      end)

      url = "http://localhost:#{bypass.port}/test.txt"
      destination = Path.join(System.tmp_dir!(), "test_404.txt")

      assert {:error, :not_found} = HfHub.HTTP.download_file(url, destination)
    end
  end
end
