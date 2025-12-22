defmodule HfHub.ApiTreeTest do
  use ExUnit.Case, async: false

  setup do
    bypass = Bypass.open()
    Application.put_env(:hf_hub, :endpoint, "http://localhost:#{bypass.port}")

    on_exit(fn ->
      Application.delete_env(:hf_hub, :endpoint)
    end)

    {:ok, bypass: bypass}
  end

  describe "list_repo_tree/2" do
    test "lists files and folders", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/datasets/test-repo/tree/main", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!([
            %{"type" => "file", "path" => "data/train-00000.parquet", "size" => 123},
            %{"type" => "directory", "path" => "data"}
          ])
        )
      end)

      assert {:ok, items} = HfHub.Api.list_repo_tree("test-repo", repo_type: :dataset)
      assert Enum.any?(items, &match?(%{type: :file, path: "data/train-00000.parquet"}, &1))
      assert Enum.any?(items, &match?(%{type: :folder, path: "data"}, &1))
    end

    test "supports path_in_repo and recursive", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/datasets/test-repo/tree/main/data", fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)
        assert conn.params["recursive"] == "1"
        assert conn.params["expand"] == "1"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!([]))
      end)

      assert {:ok, []} =
               HfHub.Api.list_repo_tree("test-repo",
                 repo_type: :dataset,
                 path_in_repo: "data",
                 recursive: true,
                 expand: true
               )
    end

    test "returns empty list when repo has no entries", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/datasets/test-repo/tree/main", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!([]))
      end)

      assert {:ok, []} = HfHub.Api.list_repo_tree("test-repo", repo_type: :dataset)
    end

    test "handles not found", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/datasets/missing/tree/main", fn conn ->
        Plug.Conn.resp(conn, 404, "Not Found")
      end)

      assert {:error, :not_found} = HfHub.Api.list_repo_tree("missing", repo_type: :dataset)
    end

    test "handles forbidden (gated repo)", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/datasets/gated/tree/main", fn conn ->
        Plug.Conn.resp(conn, 403, "Forbidden")
      end)

      assert {:error, :forbidden} = HfHub.Api.list_repo_tree("gated", repo_type: :dataset)
    end
  end

  describe "list_files/2" do
    test "uses repo tree for datasets by default", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/datasets/test-repo/tree/main", fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)
        assert conn.params["recursive"] == "1"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!([
            %{"type" => "file", "path" => "data/train-00000.parquet", "size" => 123},
            %{"type" => "directory", "path" => "data"}
          ])
        )
      end)

      assert {:ok, files} = HfHub.Api.list_files("test-repo", repo_type: :dataset)
      assert files == [%{rfilename: "data/train-00000.parquet", size: 123, lfs: nil}]
    end

    test "uses repo info for non-recursive model listing", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/models/test-repo", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            id: "test-repo",
            siblings: [%{rfilename: "config.json", size: 10}]
          })
        )
      end)

      assert {:ok, files} = HfHub.Api.list_files("test-repo", repo_type: :model)
      assert files == [%{rfilename: "config.json", size: 10, lfs: nil}]
    end

    test "uses repo tree when recursive is true", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/models/test-repo/tree/main", fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)
        assert conn.params["recursive"] == "1"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!([
            %{"type" => "file", "path" => "nested/file.txt", "size" => 2}
          ])
        )
      end)

      assert {:ok, files} =
               HfHub.Api.list_files("test-repo", repo_type: :model, recursive: true)

      assert files == [%{rfilename: "nested/file.txt", size: 2, lfs: nil}]
    end
  end
end
