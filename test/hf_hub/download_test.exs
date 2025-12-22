defmodule HfHub.DownloadTest do
  use ExUnit.Case, async: false

  setup do
    bypass = Bypass.open()
    Application.put_env(:hf_hub, :endpoint, "http://localhost:#{bypass.port}")

    # Create a temp cache dir for tests
    cache_dir = Path.join(System.tmp_dir!(), "hf_hub_test_cache_#{:rand.uniform(1_000_000)}")
    File.mkdir_p!(cache_dir)
    Application.put_env(:hf_hub, :cache_dir, cache_dir)

    on_exit(fn ->
      Application.delete_env(:hf_hub, :endpoint)
      Application.delete_env(:hf_hub, :cache_dir)
      File.rm_rf!(cache_dir)
    end)

    {:ok, bypass: bypass, cache_dir: cache_dir}
  end

  describe "hf_hub_download/1" do
    test "downloads file and caches it", %{bypass: bypass, cache_dir: cache_dir} do
      Bypass.expect_once(bypass, "GET", "/test-repo/resolve/main/config.json", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, ~s({"model": "test"}))
      end)

      assert {:ok, path} =
               HfHub.Download.hf_hub_download(
                 repo_id: "test-repo",
                 filename: "config.json",
                 repo_type: :model
               )

      assert String.starts_with?(path, cache_dir)
      assert File.exists?(path)
      assert File.read!(path) == ~s({"model": "test"})
    end

    test "returns cached file without downloading again", %{bypass: bypass, cache_dir: _cache_dir} do
      # First download
      Bypass.expect_once(bypass, "GET", "/test-repo/resolve/main/config.json", fn conn ->
        Plug.Conn.resp(conn, 200, "original content")
      end)

      {:ok, path1} =
        HfHub.Download.hf_hub_download(
          repo_id: "test-repo",
          filename: "config.json",
          repo_type: :model
        )

      # Second call should return cached file (no HTTP request)
      {:ok, path2} =
        HfHub.Download.hf_hub_download(
          repo_id: "test-repo",
          filename: "config.json",
          repo_type: :model
        )

      assert path1 == path2
      assert File.read!(path2) == "original content"
    end

    test "force_download bypasses cache", %{bypass: bypass} do
      Bypass.expect(bypass, "GET", "/test-repo/resolve/main/config.json", fn conn ->
        Plug.Conn.resp(conn, 200, "new content")
      end)

      {:ok, path1} =
        HfHub.Download.hf_hub_download(
          repo_id: "test-repo",
          filename: "config.json",
          repo_type: :model
        )

      {:ok, path2} =
        HfHub.Download.hf_hub_download(
          repo_id: "test-repo",
          filename: "config.json",
          repo_type: :model,
          force_download: true
        )

      assert path1 == path2
    end

    test "handles 404 errors", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/missing-repo/resolve/main/file.txt", fn conn ->
        Plug.Conn.resp(conn, 404, "Not Found")
      end)

      assert {:error, :not_found} =
               HfHub.Download.hf_hub_download(
                 repo_id: "missing-repo",
                 filename: "file.txt"
               )
    end

    test "includes auth token when provided", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/private-repo/resolve/main/secret.txt", fn conn ->
        assert ["Bearer hf_secret_token"] = Plug.Conn.get_req_header(conn, "authorization")
        Plug.Conn.resp(conn, 200, "secret content")
      end)

      assert {:ok, _path} =
               HfHub.Download.hf_hub_download(
                 repo_id: "private-repo",
                 filename: "secret.txt",
                 token: "hf_secret_token"
               )
    end

    test "extracts archives when extract is true", %{bypass: bypass} do
      dir =
        Path.join(
          System.tmp_dir!(),
          "hf_hub_download_extract_#{System.unique_integer([:positive])}"
        )

      File.mkdir_p!(dir)
      on_exit(fn -> File.rm_rf(dir) end)

      source_path = Path.join(dir, "hello.txt")
      File.write!(source_path, "hello archive")

      zip_path = Path.join(dir, "archive.zip")

      {:ok, _} =
        :zip.create(
          to_charlist(zip_path),
          [~c"hello.txt"],
          cwd: to_charlist(dir)
        )

      zip_binary = File.read!(zip_path)

      Bypass.expect_once(bypass, "GET", "/test-repo/resolve/main/archive.zip", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/zip")
        |> Plug.Conn.resp(200, zip_binary)
      end)

      assert {:ok, extracted_path} =
               HfHub.Download.hf_hub_download(
                 repo_id: "test-repo",
                 filename: "archive.zip",
                 repo_type: :model,
                 extract: true
               )

      assert File.read!(Path.join(extracted_path, "hello.txt")) == "hello archive"
    end
  end

  describe "download_stream/1" do
    test "returns a stream of chunks", %{bypass: bypass} do
      content = String.duplicate("chunk data ", 100)

      Bypass.expect_once(bypass, "GET", "/test-repo/resolve/main/large.bin", fn conn ->
        Plug.Conn.resp(conn, 200, content)
      end)

      {:ok, stream} =
        HfHub.Download.download_stream(
          repo_id: "test-repo",
          filename: "large.bin",
          repo_type: :model
        )

      result = stream |> Enum.to_list() |> IO.iodata_to_binary()
      assert result == content
    end

    test "stream handles 404 gracefully", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/test-repo/resolve/main/missing.bin", fn conn ->
        Plug.Conn.resp(conn, 404, "Not Found")
      end)

      {:ok, stream} =
        HfHub.Download.download_stream(
          repo_id: "test-repo",
          filename: "missing.bin"
        )

      # Stream should halt with error on enumeration
      result = Enum.to_list(stream)
      assert result == []
    end

    test "stream includes auth token", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/test-repo/resolve/main/secret.bin", fn conn ->
        assert ["Bearer hf_token_12345"] = Plug.Conn.get_req_header(conn, "authorization")
        Plug.Conn.resp(conn, 200, "secret data")
      end)

      {:ok, stream} =
        HfHub.Download.download_stream(
          repo_id: "test-repo",
          filename: "secret.bin",
          token: "hf_token_12345"
        )

      result = stream |> Enum.to_list() |> IO.iodata_to_binary()
      assert result == "secret data"
    end
  end

  describe "snapshot_download/1" do
    test "downloads all files in repository", %{bypass: bypass, cache_dir: cache_dir} do
      # Mock the API file listing
      Bypass.expect_once(bypass, "GET", "/api/models/test-repo", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            id: "test-repo",
            siblings: [
              %{rfilename: "config.json", size: 100},
              %{rfilename: "model.bin", size: 200}
            ]
          })
        )
      end)

      # Mock the file downloads
      Bypass.expect(bypass, "GET", "/test-repo/resolve/main/config.json", fn conn ->
        Plug.Conn.resp(conn, 200, ~s({"model": "test"}))
      end)

      Bypass.expect(bypass, "GET", "/test-repo/resolve/main/model.bin", fn conn ->
        Plug.Conn.resp(conn, 200, "binary model data")
      end)

      assert {:ok, snapshot_path} =
               HfHub.Download.snapshot_download(
                 repo_id: "test-repo",
                 repo_type: :model
               )

      assert String.contains?(snapshot_path, cache_dir)
      assert String.ends_with?(snapshot_path, "snapshots/main")
    end

    test "respects ignore_patterns", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/models/test-repo", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            id: "test-repo",
            siblings: [
              %{rfilename: "config.json", size: 100},
              %{rfilename: "model.safetensors", size: 1000},
              %{rfilename: "model.bin", size: 1000}
            ]
          })
        )
      end)

      # Only config.json should be downloaded (*.bin and *.safetensors ignored)
      Bypass.expect_once(bypass, "GET", "/test-repo/resolve/main/config.json", fn conn ->
        Plug.Conn.resp(conn, 200, "{}")
      end)

      assert {:ok, _path} =
               HfHub.Download.snapshot_download(
                 repo_id: "test-repo",
                 repo_type: :model,
                 ignore_patterns: ["*.bin", "*.safetensors"]
               )
    end

    test "respects allow_patterns", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/models/test-repo", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            id: "test-repo",
            siblings: [
              %{rfilename: "config.json", size: 100},
              %{rfilename: "README.md", size: 50},
              %{rfilename: "model.bin", size: 1000}
            ]
          })
        )
      end)

      # Only .json files should be downloaded
      Bypass.expect_once(bypass, "GET", "/test-repo/resolve/main/config.json", fn conn ->
        Plug.Conn.resp(conn, 200, "{}")
      end)

      assert {:ok, _path} =
               HfHub.Download.snapshot_download(
                 repo_id: "test-repo",
                 repo_type: :model,
                 allow_patterns: ["*.json"]
               )
    end
  end

  describe "resume_download/1" do
    test "resumes download from partial file", %{bypass: bypass, cache_dir: cache_dir} do
      # Create a partial file
      repo_path = Path.join([cache_dir, "hub", "models--test-repo", "snapshots", "main"])
      File.mkdir_p!(repo_path)
      partial_path = Path.join(repo_path, "large.bin")
      File.write!(partial_path, "partial")

      Bypass.expect_once(bypass, "GET", "/test-repo/resolve/main/large.bin", fn conn ->
        # Check Range header
        case Plug.Conn.get_req_header(conn, "range") do
          ["bytes=7-"] ->
            conn
            |> Plug.Conn.resp(206, " content")

          _ ->
            Plug.Conn.resp(conn, 200, "partial content")
        end
      end)

      assert {:ok, :resumed} =
               HfHub.Download.resume_download(
                 repo_id: "test-repo",
                 filename: "large.bin",
                 repo_type: :model
               )

      assert File.read!(partial_path) == "partial content"
    end

    test "starts fresh download when no partial file exists", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/test-repo/resolve/main/new.bin", fn conn ->
        Plug.Conn.resp(conn, 200, "new content")
      end)

      assert {:ok, path} =
               HfHub.Download.resume_download(
                 repo_id: "test-repo",
                 filename: "new.bin",
                 repo_type: :model
               )

      assert File.read!(path) == "new content"
    end

    test "handles 416 Range Not Satisfiable (file complete)", %{
      bypass: bypass,
      cache_dir: cache_dir
    } do
      # Create a complete file
      repo_path = Path.join([cache_dir, "hub", "models--test-repo", "snapshots", "main"])
      File.mkdir_p!(repo_path)
      complete_path = Path.join(repo_path, "complete.bin")
      File.write!(complete_path, "complete content")

      Bypass.expect_once(bypass, "GET", "/test-repo/resolve/main/complete.bin", fn conn ->
        Plug.Conn.resp(conn, 416, "Range Not Satisfiable")
      end)

      assert {:ok, :complete} =
               HfHub.Download.resume_download(
                 repo_id: "test-repo",
                 filename: "complete.bin",
                 repo_type: :model
               )
    end
  end
end
