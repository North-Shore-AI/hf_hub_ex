defmodule HfHub.ApiDatasetFallbackTest do
  use ExUnit.Case, async: false

  setup do
    bypass = Bypass.open()
    Application.put_env(:hf_hub, :endpoint, "http://localhost:#{bypass.port}")

    on_exit(fn ->
      Application.delete_env(:hf_hub, :endpoint)
    end)

    {:ok, bypass: bypass}
  end

  describe "dataset_configs/2 fallbacks" do
    test "uses dataset_infos.json when cardData missing", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/datasets/test-repo", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{id: "test-repo"}))
      end)

      Bypass.expect_once(
        bypass,
        "GET",
        "/datasets/test-repo/resolve/main/dataset_infos.json",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!(%{
              "default" => %{"splits" => %{}},
              "socratic" => %{"splits" => %{}}
            })
          )
        end
      )

      assert {:ok, configs} = HfHub.Api.dataset_configs("test-repo")
      assert Enum.sort(configs) == ["default", "socratic"]
    end

    test "falls back to tree inference when dataset_infos is missing", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/datasets/test-repo", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{id: "test-repo"}))
      end)

      Bypass.expect_once(
        bypass,
        "GET",
        "/datasets/test-repo/resolve/main/dataset_infos.json",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(404, Jason.encode!(%{error: "Not Found"}))
        end
      )

      Bypass.expect_once(bypass, "GET", "/api/datasets/test-repo/tree/main", fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)
        assert conn.params["recursive"] == "1"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!([
            %{"type" => "file", "path" => "math/train-00000.parquet", "size" => 10}
          ])
        )
      end)

      assert {:ok, configs} = HfHub.Api.dataset_configs("test-repo")
      assert configs == ["math"]
    end

    test "returns empty list when no configs can be inferred", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/datasets/empty-repo", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{id: "empty-repo"}))
      end)

      Bypass.expect_once(
        bypass,
        "GET",
        "/datasets/empty-repo/resolve/main/dataset_infos.json",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{}))
        end
      )

      Bypass.expect_once(bypass, "GET", "/api/datasets/empty-repo/tree/main", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!([]))
      end)

      assert {:ok, []} = HfHub.Api.dataset_configs("empty-repo")
    end

    test "propagates forbidden for gated repos", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/datasets/gated", fn conn ->
        Plug.Conn.resp(conn, 403, "Forbidden")
      end)

      assert {:error, :forbidden} = HfHub.Api.dataset_configs("gated")
    end
  end

  describe "dataset_splits/2 fallbacks" do
    test "reads splits from dataset_infos.json", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/datasets/test-repo/resolve/main/dataset_infos.json",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!(%{
              "default" => %{
                "splits" => %{
                  "train" => %{"num_examples" => 1},
                  "test" => %{"num_examples" => 2}
                }
              }
            })
          )
        end
      )

      assert {:ok, splits} = HfHub.Api.dataset_splits("test-repo", config: "default")
      assert splits == ["test", "train"]
    end

    test "falls back to tree inference when dataset_infos is missing", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/datasets/test-repo/resolve/main/dataset_infos.json",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(404, Jason.encode!(%{error: "Not Found"}))
        end
      )

      Bypass.expect_once(bypass, "GET", "/api/datasets/test-repo/tree/main", fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)
        assert conn.params["recursive"] == "1"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!([
            %{"type" => "file", "path" => "math/train-00000.parquet", "size" => 10},
            %{"type" => "file", "path" => "math/test-00000.parquet", "size" => 10}
          ])
        )
      end)

      assert {:ok, splits} = HfHub.Api.dataset_splits("test-repo", config: "math")
      assert splits == ["test", "train"]
    end

    test "returns empty list when no splits can be inferred", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/datasets/empty-repo/resolve/main/dataset_infos.json",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(404, Jason.encode!(%{error: "Not Found"}))
        end
      )

      Bypass.expect_once(bypass, "GET", "/api/datasets/empty-repo/tree/main", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!([]))
      end)

      assert {:ok, []} = HfHub.Api.dataset_splits("empty-repo", config: "default")
    end

    test "propagates forbidden when tree is gated", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/datasets/gated/resolve/main/dataset_infos.json",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(404, Jason.encode!(%{error: "Not Found"}))
        end
      )

      Bypass.expect_once(bypass, "GET", "/api/datasets/gated/tree/main", fn conn ->
        Plug.Conn.resp(conn, 403, "Forbidden")
      end)

      assert {:error, :forbidden} = HfHub.Api.dataset_splits("gated", config: "default")
    end
  end
end
