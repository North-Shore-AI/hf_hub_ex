defmodule HfHub.Commit.LfsUploadTest do
  # async: false to avoid race conditions with Application env
  use ExUnit.Case, async: false

  alias HfHub.Commit.{LfsUpload, Operation}

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

  describe "request_batch_info/4" do
    test "requests upload info for objects", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/user%2Frepo.git/info/lfs/objects/batch", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        payload = Jason.decode!(body)

        assert payload["operation"] == "upload"
        assert ["basic", "multipart"] = payload["transfers"]
        assert payload["hash_algo"] == "sha256"
        assert [%{"oid" => _, "size" => 1000}] = payload["objects"]

        conn
        |> Plug.Conn.put_resp_content_type("application/vnd.git-lfs+json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "transfer" => "basic",
            "objects" => [
              %{
                "oid" => "abc123",
                "size" => 1000,
                "actions" => %{
                  "upload" => %{
                    "href" => "https://storage.example.com/upload",
                    "header" => %{}
                  }
                }
              }
            ]
          })
        )
      end)

      upload_info = %HfHub.LFS.UploadInfo{
        sha256: :crypto.hash(:sha256, "test"),
        size: 1000,
        sample: "test"
      }

      {:ok, response} =
        LfsUpload.request_batch_info(
          "user/repo",
          [upload_info],
          "hf_test_token"
        )

      assert response["transfer"] == "basic"
      assert [%{"oid" => "abc123"}] = response["objects"]
    end

    test "uses correct path for datasets", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/datasets/user%2Fdataset.git/info/lfs/objects/batch",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/vnd.git-lfs+json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!(%{
              "transfer" => "basic",
              "objects" => []
            })
          )
        end
      )

      upload_info = %HfHub.LFS.UploadInfo{
        sha256: :crypto.hash(:sha256, "test"),
        size: 1000,
        sample: "test"
      }

      {:ok, _} =
        LfsUpload.request_batch_info(
          "user/dataset",
          [upload_info],
          "hf_test_token",
          repo_type: :dataset
        )
    end

    test "uses correct path for spaces", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/spaces/user%2Fspace.git/info/lfs/objects/batch",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/vnd.git-lfs+json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!(%{
              "transfer" => "basic",
              "objects" => []
            })
          )
        end
      )

      upload_info = %HfHub.LFS.UploadInfo{
        sha256: :crypto.hash(:sha256, "test"),
        size: 1000,
        sample: "test"
      }

      {:ok, _} =
        LfsUpload.request_batch_info(
          "user/space",
          [upload_info],
          "hf_test_token",
          repo_type: :space
        )
    end
  end

  describe "upload_batch/4" do
    test "uploads single file successfully", %{bypass: bypass} do
      content = String.duplicate("x", 1000)
      sha256 = :crypto.hash(:sha256, content)
      oid = Base.encode16(sha256, case: :lower)

      # Use a separate bypass for the upload endpoint
      upload_bypass = Bypass.open()

      # Expect LFS batch request
      Bypass.expect_once(bypass, "POST", "/user%2Frepo.git/info/lfs/objects/batch", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/vnd.git-lfs+json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "transfer" => "basic",
            "objects" => [
              %{
                "oid" => oid,
                "size" => 1000,
                "actions" => %{
                  "upload" => %{
                    "href" => "http://localhost:#{upload_bypass.port}/upload/#{oid}",
                    "header" => %{"Authorization" => "Bearer storage-token"}
                  }
                }
              }
            ]
          })
        )
      end)

      # Expect actual file upload
      Bypass.expect_once(upload_bypass, "PUT", "/upload/#{oid}", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert body == content

        conn
        |> Plug.Conn.resp(200, "")
      end)

      upload_info = %HfHub.LFS.UploadInfo{
        sha256: sha256,
        size: 1000,
        sample: binary_part(content, 0, min(512, 1000))
      }

      op = %Operation.Add{
        path_in_repo: "model.bin",
        content: content,
        upload_info: upload_info,
        upload_mode: :lfs
      }

      {:ok, [uploaded_op]} = LfsUpload.upload_batch("user/repo", [op], "hf_test_token")

      assert uploaded_op.is_uploaded == true
    end

    test "skips upload for existing files", %{bypass: bypass} do
      content = "test content"
      sha256 = :crypto.hash(:sha256, content)
      oid = Base.encode16(sha256, case: :lower)

      # Return no upload action (file already exists)
      Bypass.expect_once(bypass, "POST", "/user%2Frepo.git/info/lfs/objects/batch", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/vnd.git-lfs+json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "transfer" => "basic",
            "objects" => [
              %{
                "oid" => oid,
                "size" => byte_size(content),
                "actions" => %{}
              }
            ]
          })
        )
      end)

      upload_info = %HfHub.LFS.UploadInfo{
        sha256: sha256,
        size: byte_size(content),
        sample: content
      }

      op = %Operation.Add{
        path_in_repo: "existing.bin",
        content: content,
        upload_info: upload_info,
        upload_mode: :lfs
      }

      {:ok, [uploaded_op]} = LfsUpload.upload_batch("user/repo", [op], "hf_test_token")

      assert uploaded_op.is_uploaded == true
    end

    test "verifies upload when verify action present", %{bypass: bypass} do
      content = "test content"
      sha256 = :crypto.hash(:sha256, content)
      oid = Base.encode16(sha256, case: :lower)

      upload_bypass = Bypass.open()
      verify_bypass = Bypass.open()

      Bypass.expect_once(bypass, "POST", "/user%2Frepo.git/info/lfs/objects/batch", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/vnd.git-lfs+json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "transfer" => "basic",
            "objects" => [
              %{
                "oid" => oid,
                "size" => byte_size(content),
                "actions" => %{
                  "upload" => %{
                    "href" => "http://localhost:#{upload_bypass.port}/upload/#{oid}",
                    "header" => %{}
                  },
                  "verify" => %{
                    "href" => "http://localhost:#{verify_bypass.port}/verify/#{oid}",
                    "header" => %{}
                  }
                }
              }
            ]
          })
        )
      end)

      Bypass.expect_once(upload_bypass, "PUT", "/upload/#{oid}", fn conn ->
        conn |> Plug.Conn.resp(200, "")
      end)

      Bypass.expect_once(verify_bypass, "POST", "/verify/#{oid}", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        payload = Jason.decode!(body)

        assert payload["oid"] == oid
        assert payload["size"] == byte_size(content)

        conn |> Plug.Conn.resp(200, "")
      end)

      upload_info = %HfHub.LFS.UploadInfo{
        sha256: sha256,
        size: byte_size(content),
        sample: content
      }

      op = %Operation.Add{
        path_in_repo: "verified.bin",
        content: content,
        upload_info: upload_info,
        upload_mode: :lfs
      }

      {:ok, [uploaded_op]} = LfsUpload.upload_batch("user/repo", [op], "hf_test_token")

      assert uploaded_op.is_uploaded == true
    end

    test "handles upload failure", %{bypass: bypass} do
      content = "test content"
      sha256 = :crypto.hash(:sha256, content)
      oid = Base.encode16(sha256, case: :lower)

      upload_bypass = Bypass.open()

      Bypass.expect_once(bypass, "POST", "/user%2Frepo.git/info/lfs/objects/batch", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/vnd.git-lfs+json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "transfer" => "basic",
            "objects" => [
              %{
                "oid" => oid,
                "size" => byte_size(content),
                "actions" => %{
                  "upload" => %{
                    "href" => "http://localhost:#{upload_bypass.port}/upload/#{oid}",
                    "header" => %{}
                  }
                }
              }
            ]
          })
        )
      end)

      Bypass.expect_once(upload_bypass, "PUT", "/upload/#{oid}", fn conn ->
        conn |> Plug.Conn.resp(500, "Internal Server Error")
      end)

      upload_info = %HfHub.LFS.UploadInfo{
        sha256: sha256,
        size: byte_size(content),
        sample: content
      }

      op = %Operation.Add{
        path_in_repo: "failing.bin",
        content: content,
        upload_info: upload_info,
        upload_mode: :lfs
      }

      {:error, {:lfs_upload_failed, 500, _}} =
        LfsUpload.upload_batch("user/repo", [op], "hf_test_token")
    end
  end
end
