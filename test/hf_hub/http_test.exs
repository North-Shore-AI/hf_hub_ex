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

    test "handles 201 created response", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/test", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(201, Jason.encode!(%{id: "new-resource"}))
      end)

      url = "http://localhost:#{bypass.port}/api/test"
      assert {:ok, %{"id" => "new-resource"}} = HfHub.HTTP.post(url, %{name: "test"})
    end

    test "handles 400 errors", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/test", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(400, Jason.encode!(%{error: "Bad Request"}))
      end)

      url = "http://localhost:#{bypass.port}/api/test"
      assert {:error, %HfHub.Errors.BadRequest{message: "Bad Request"}} = HfHub.HTTP.post(url)
    end

    test "handles 401 unauthorized", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/test", fn conn ->
        Plug.Conn.resp(conn, 401, "Unauthorized")
      end)

      url = "http://localhost:#{bypass.port}/api/test"
      assert {:error, :unauthorized} = HfHub.HTTP.post(url, %{})
    end

    test "handles 404 errors", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/test", fn conn ->
        Plug.Conn.resp(conn, 404, "Not Found")
      end)

      url = "http://localhost:#{bypass.port}/api/test"
      assert {:error, :not_found} = HfHub.HTTP.post(url, %{})
    end

    test "handles 409 conflict", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/test", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(409, Jason.encode!(%{error: "Conflict"}))
      end)

      url = "http://localhost:#{bypass.port}/api/test"
      assert {:error, {:conflict, %{"error" => "Conflict"}}} = HfHub.HTTP.post(url)
    end

    test "handles 422 validation error", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/test", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(422, Jason.encode!(%{error: "Invalid"}))
      end)

      url = "http://localhost:#{bypass.port}/api/test"
      assert {:error, {:validation, %{"error" => "Invalid"}}} = HfHub.HTTP.post(url)
    end

    test "handles nil body", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/test", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{result: "ok"}))
      end)

      url = "http://localhost:#{bypass.port}/api/test"
      assert {:ok, %{"result" => "ok"}} = HfHub.HTTP.post(url, nil)
    end
  end

  describe "put/3" do
    test "makes successful PUT request", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PUT", "/api/test", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{"data" => "update"}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{result: "updated"}))
      end)

      url = "http://localhost:#{bypass.port}/api/test"
      assert {:ok, %{"result" => "updated"}} = HfHub.HTTP.put(url, %{data: "update"})
    end

    test "handles 204 no content", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PUT", "/api/test", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      url = "http://localhost:#{bypass.port}/api/test"
      assert :ok = HfHub.HTTP.put(url, %{data: "update"})
    end
  end

  describe "patch/3" do
    test "makes successful PATCH request", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PATCH", "/api/test", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{"data" => "patch"}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{result: "patched"}))
      end)

      url = "http://localhost:#{bypass.port}/api/test"
      assert {:ok, %{"result" => "patched"}} = HfHub.HTTP.patch(url, %{data: "patch"})
    end
  end

  describe "delete/2" do
    test "returns :ok on 204", %{bypass: bypass} do
      Bypass.expect_once(bypass, "DELETE", "/api/test", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      url = "http://localhost:#{bypass.port}/api/test"
      assert :ok = HfHub.HTTP.delete(url)
    end

    test "returns {:ok, body} on 200 with body", %{bypass: bypass} do
      Bypass.expect_once(bypass, "DELETE", "/api/test", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{deleted: true}))
      end)

      url = "http://localhost:#{bypass.port}/api/test"
      assert {:ok, %{"deleted" => true}} = HfHub.HTTP.delete(url)
    end

    test "handles 404 not found", %{bypass: bypass} do
      Bypass.expect_once(bypass, "DELETE", "/api/test", fn conn ->
        Plug.Conn.resp(conn, 404, "Not Found")
      end)

      url = "http://localhost:#{bypass.port}/api/test"
      assert {:error, :not_found} = HfHub.HTTP.delete(url)
    end
  end

  describe "post_action/3" do
    test "returns :ok on 200", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/test", fn conn ->
        Plug.Conn.resp(conn, 200, "OK")
      end)

      url = "http://localhost:#{bypass.port}/api/test"
      assert :ok = HfHub.HTTP.post_action(url)
    end

    test "returns :ok on 204", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/test", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      url = "http://localhost:#{bypass.port}/api/test"
      assert :ok = HfHub.HTTP.post_action(url)
    end
  end

  describe "get_paginated/2" do
    test "collects all pages via Link headers", %{bypass: bypass} do
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      Bypass.expect(bypass, "GET", "/api/list", fn conn ->
        count = Agent.get_and_update(counter, fn n -> {n, n + 1} end)

        case count do
          0 ->
            assert conn.query_string == "limit=2"

            conn
            |> Plug.Conn.put_resp_header(
              "link",
              "<http://localhost:#{bypass.port}/api/list?limit=2&offset=2>; rel=\"next\""
            )
            |> Plug.Conn.put_resp_content_type("application/json")
            |> Plug.Conn.resp(200, Jason.encode!([%{"id" => 1}, %{"id" => 2}]))

          1 ->
            assert conn.query_string == "limit=2&offset=2"

            conn
            |> Plug.Conn.put_resp_content_type("application/json")
            |> Plug.Conn.resp(200, Jason.encode!([%{"id" => 3}]))

          _ ->
            Plug.Conn.resp(conn, 500, "Unexpected request")
        end
      end)

      url = "http://localhost:#{bypass.port}/api/list"
      assert {:ok, results} = HfHub.HTTP.get_paginated(url, params: [limit: 2])
      assert Enum.map(results, & &1["id"]) == [1, 2, 3]
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
