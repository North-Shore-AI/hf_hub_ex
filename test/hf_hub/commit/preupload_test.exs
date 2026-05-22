defmodule HfHub.Commit.PreuploadTest do
  # async: false to keep the application :endpoint config isolated per test.
  use ExUnit.Case, async: false

  alias HfHub.Commit.Preupload
  alias HfHub.LFS.UploadInfo

  setup do
    bypass = Bypass.open()
    original_endpoint = Application.get_env(:hf_hub, :endpoint)
    Application.put_env(:hf_hub, :endpoint, "http://localhost:#{bypass.port}")

    on_exit(fn ->
      if original_endpoint do
        Application.put_env(:hf_hub, :endpoint, original_endpoint)
      else
        Application.delete_env(:hf_hub, :endpoint)
      end
    end)

    {:ok, bypass: bypass}
  end

  defp op(path, content) do
    size = byte_size(content)
    sample = if size > 512, do: binary_part(content, 0, 512), else: content
    %{path_in_repo: path, upload_info: %UploadInfo{sha256: <<0::256>>, size: size, sample: sample}}
  end

  describe "fetch_upload_modes/4" do
    test "posts canonical preupload body and returns per-path mode", %{bypass: bypass} do
      # Mirror the canonical Python implementation:
      #   POST /api/{repo_type}s/{repo_id}/preupload/{revision}
      #   {"files": [{"path", "sample" (base64), "size"}]}
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/datasets/org/dataset/preupload/main",
        fn conn ->
          [ct | _] = Plug.Conn.get_req_header(conn, "content-type")
          assert ct =~ "application/json"

          {:ok, body, conn} = Plug.Conn.read_body(conn)
          payload = Jason.decode!(body)

          assert [a, b] = payload["files"]
          assert a["path"] == "checkpoints/small.safetensors"
          assert a["size"] == 16
          # sample is base64-encoded raw bytes
          assert Base.decode64!(a["sample"]) == String.duplicate("s", 16)

          assert b["path"] == "config.json"
          assert b["size"] == 32
          assert Base.decode64!(b["sample"]) == String.duplicate("j", 32)

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!(%{
              "files" => [
                %{
                  "path" => "checkpoints/small.safetensors",
                  "uploadMode" => "lfs",
                  "shouldIgnore" => false,
                  "oid" => nil
                },
                %{
                  "path" => "config.json",
                  "uploadMode" => "regular",
                  "shouldIgnore" => false,
                  "oid" => nil
                }
              ]
            })
          )
        end
      )

      ops = [
        op("checkpoints/small.safetensors", String.duplicate("s", 16)),
        op("config.json", String.duplicate("j", 32))
      ]

      assert {:ok, modes} =
               Preupload.fetch_upload_modes(
                 "org/dataset",
                 ops,
                 "hf_test_token",
                 repo_type: :dataset
               )

      assert modes == %{
               "checkpoints/small.safetensors" => :lfs,
               "config.json" => :regular
             }
    end

    test "uses repo_type=model and revision=main by default", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/models/org/repo/preupload/main", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "files" => [
              %{
                "path" => "weights.bin",
                "uploadMode" => "lfs",
                "shouldIgnore" => false
              }
            ]
          })
        )
      end)

      ops = [op("weights.bin", "x")]

      assert {:ok, %{"weights.bin" => :lfs}} =
               Preupload.fetch_upload_modes("org/repo", ops, "hf_test_token")
    end

    test "preserves the literal owner/name slash in the URL", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/datasets/my-org/my-dataset/preupload/main",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!(%{
              "files" => [%{"path" => "f", "uploadMode" => "regular", "shouldIgnore" => false}]
            })
          )
        end
      )

      assert {:ok, _} =
               Preupload.fetch_upload_modes(
                 "my-org/my-dataset",
                 [op("f", "x")],
                 "t",
                 repo_type: :dataset
               )
    end

    test "honours custom revision and encodes special characters", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/datasets/org/dataset/preupload/feature%2Ffoo",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!(%{
              "files" => [%{"path" => "f", "uploadMode" => "regular", "shouldIgnore" => false}]
            })
          )
        end
      )

      assert {:ok, _} =
               Preupload.fetch_upload_modes(
                 "org/dataset",
                 [op("f", "x")],
                 "t",
                 repo_type: :dataset,
                 revision: "feature/foo"
               )
    end

    test "treats empty-size additions as :regular even if the Hub reports :lfs",
         %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/models/org/repo/preupload/main", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "files" => [
              %{"path" => "empty.bin", "uploadMode" => "lfs", "shouldIgnore" => false},
              %{"path" => "real.bin", "uploadMode" => "lfs", "shouldIgnore" => false}
            ]
          })
        )
      end)

      ops = [op("empty.bin", ""), op("real.bin", "x")]

      assert {:ok, modes} = Preupload.fetch_upload_modes("org/repo", ops, "t")
      # S3 multipart cannot accept zero-byte LFS objects, so empty files
      # always travel as regular base64 blobs — matches Python.
      assert modes["empty.bin"] == :regular
      assert modes["real.bin"] == :lfs
    end

    test "surfaces Hub validation errors as {:error, ...}", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/models/org/repo/preupload/main", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(400, Jason.encode!(%{"error" => "bad"}))
      end)

      assert {:error, _} =
               Preupload.fetch_upload_modes("org/repo", [op("a", "x")], "t")
    end
  end
end
