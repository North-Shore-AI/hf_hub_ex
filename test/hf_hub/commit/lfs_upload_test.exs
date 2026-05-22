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
      Bypass.expect_once(bypass, "POST", "/user/repo.git/info/lfs/objects/batch", fn conn ->
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
        "/datasets/user/dataset.git/info/lfs/objects/batch",
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
        "/spaces/user/space.git/info/lfs/objects/batch",
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
      Bypass.expect_once(bypass, "POST", "/user/repo.git/info/lfs/objects/batch", fn conn ->
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
      Bypass.expect_once(bypass, "POST", "/user/repo.git/info/lfs/objects/batch", fn conn ->
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

      Bypass.expect_once(bypass, "POST", "/user/repo.git/info/lfs/objects/batch", fn conn ->
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

      Bypass.expect_once(bypass, "POST", "/user/repo.git/info/lfs/objects/batch", fn conn ->
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

  describe "upload_batch/4 multipart (HF protocol)" do
    # Regression for the real-world failure observed when pushing a 297 MB
    # tensor to a HF dataset repo:
    #
    #     {:error, {:lfs_upload_failed, 404,
    #       "...<pre>Cannot PUT /api/complete_multipart</pre>..."}}
    #
    # Root cause: the multipart-detection branch looked for the wrong header
    # key ("x-amz-meta-chunk-size" instead of HF's actual "chunk_size"), so
    # the multipart batch response silently fell through to single-part PUT
    # against the *completion* URL.
    #
    # This test reproduces the canonical HF batch shape from
    # huggingface_hub/src/huggingface_hub/lfs.py and asserts that:
    #   1. Each part URL receives a PUT with the correct chunk
    #   2. The completion endpoint receives a POST with
    #      {"oid": ..., "parts": [%{"partNumber": n, "etag": ...}]}
    #   3. Completion headers include LFS Accept/Content-Type
    test "uploads parts and POSTs canonical completion payload", %{bypass: bypass} do
      chunk = String.duplicate("a", 1024)
      content = chunk <> chunk <> chunk
      sha256 = :crypto.hash(:sha256, content)
      oid = Base.encode16(sha256, case: :lower)

      parts_bypass = Bypass.open()
      complete_bypass = Bypass.open()
      completion_path = "/api/complete_multipart/#{oid}"

      # ---------------- LFS batch ----------------
      Bypass.expect_once(bypass, "POST", "/user/repo.git/info/lfs/objects/batch", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/vnd.git-lfs+json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "transfer" => "multipart",
            "objects" => [
              %{
                "oid" => oid,
                "size" => byte_size(content),
                "actions" => %{
                  "upload" => %{
                    "href" => "http://localhost:#{complete_bypass.port}#{completion_path}",
                    "header" => %{
                      "chunk_size" => "1024",
                      "00001" => "http://localhost:#{parts_bypass.port}/parts/1",
                      "00002" => "http://localhost:#{parts_bypass.port}/parts/2",
                      "00003" => "http://localhost:#{parts_bypass.port}/parts/3"
                    }
                  }
                }
              }
            ]
          })
        )
      end)

      # ---------------- 3 part PUTs ----------------
      parts_received = :counters.new(1, [])
      etag_for = fn n -> "etag-#{n}" end

      Bypass.expect(parts_bypass, fn conn ->
        assert conn.method == "PUT"
        :counters.add(parts_received, 1, 1)
        assert {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert body == chunk

        part_num =
          case conn.request_path do
            "/parts/1" -> 1
            "/parts/2" -> 2
            "/parts/3" -> 3
          end

        conn
        |> Plug.Conn.put_resp_header("etag", etag_for.(part_num))
        |> Plug.Conn.resp(200, "")
      end)

      # ---------------- Completion POST ----------------
      Bypass.expect_once(complete_bypass, "POST", completion_path, fn conn ->
        # LFS headers must be present on completion
        accept = Plug.Conn.get_req_header(conn, "accept")
        content_type = Plug.Conn.get_req_header(conn, "content-type")
        assert Enum.any?(accept, &String.contains?(&1, "application/vnd.git-lfs+json"))
        assert Enum.any?(content_type, &String.contains?(&1, "application/vnd.git-lfs+json"))

        {:ok, raw, conn} = Plug.Conn.read_body(conn)
        payload = Jason.decode!(raw)

        assert payload["oid"] == oid

        assert payload["parts"] == [
                 %{"partNumber" => 1, "etag" => etag_for.(1)},
                 %{"partNumber" => 2, "etag" => etag_for.(2)},
                 %{"partNumber" => 3, "etag" => etag_for.(3)}
               ]

        conn |> Plug.Conn.resp(200, "")
      end)

      upload_info = %HfHub.LFS.UploadInfo{
        sha256: sha256,
        size: byte_size(content),
        sample: binary_part(content, 0, 512)
      }

      op = %Operation.Add{
        path_in_repo: "big.bin",
        content: content,
        upload_info: upload_info,
        upload_mode: :lfs
      }

      assert {:ok, [uploaded]} = LfsUpload.upload_batch("user/repo", [op], "hf_test_token")
      assert uploaded.is_uploaded == true
      assert :counters.get(parts_received, 1) == 3
    end

    test "raises ArgumentError when chunk_size is malformed", %{bypass: bypass} do
      content = "x"
      sha256 = :crypto.hash(:sha256, content)
      oid = Base.encode16(sha256, case: :lower)
      complete_bypass = Bypass.open()

      Bypass.expect_once(bypass, "POST", "/user/repo.git/info/lfs/objects/batch", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/vnd.git-lfs+json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "transfer" => "multipart",
            "objects" => [
              %{
                "oid" => oid,
                "size" => byte_size(content),
                "actions" => %{
                  "upload" => %{
                    "href" => "http://localhost:#{complete_bypass.port}/c",
                    "header" => %{"chunk_size" => "not-a-number"}
                  }
                }
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
        path_in_repo: "bad.bin",
        content: content,
        upload_info: upload_info,
        upload_mode: :lfs
      }

      # Malformed server responses (e.g. non-integer `chunk_size`) are
      # caught inside the worker so they surface as a tagged tuple instead
      # of crashing the caller process. This is the public contract for
      # contract violations in HF's LFS batch response.
      assert {:error, {:malformed_response, msg}} =
               LfsUpload.upload_batch("user/repo", [op], "hf_test_token")

      assert msg =~ "chunk_size"
    end

    test "returns part_count_mismatch when server-declared parts do not cover content",
         %{bypass: bypass} do
      # 3 KiB content, chunk_size 1 KiB but only 2 part URLs => 3 chunks vs 2 urls
      content = String.duplicate("b", 3 * 1024)
      sha256 = :crypto.hash(:sha256, content)
      oid = Base.encode16(sha256, case: :lower)
      parts_bypass = Bypass.open()
      complete_bypass = Bypass.open()

      Bypass.expect_once(bypass, "POST", "/user/repo.git/info/lfs/objects/batch", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/vnd.git-lfs+json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "transfer" => "multipart",
            "objects" => [
              %{
                "oid" => oid,
                "size" => byte_size(content),
                "actions" => %{
                  "upload" => %{
                    "href" => "http://localhost:#{complete_bypass.port}/c",
                    "header" => %{
                      "chunk_size" => "1024",
                      "00001" => "http://localhost:#{parts_bypass.port}/p/1",
                      "00002" => "http://localhost:#{parts_bypass.port}/p/2"
                    }
                  }
                }
              }
            ]
          })
        )
      end)

      upload_info = %HfHub.LFS.UploadInfo{
        sha256: sha256,
        size: byte_size(content),
        sample: binary_part(content, 0, 512)
      }

      op = %Operation.Add{
        path_in_repo: "short.bin",
        content: content,
        upload_info: upload_info,
        upload_mode: :lfs
      }

      assert {:error, {:multipart_upload_failed, {:part_count_mismatch, _}}} =
               LfsUpload.upload_batch("user/repo", [op], "hf_test_token")
    end
  end
end
