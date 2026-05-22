defmodule HfHub.Commit.FolderUploadTest do
  # async: false to avoid race conditions with Application env
  use ExUnit.Case, async: false

  alias HfHub.Commit

  defp parse_ndjson(body) do
    body
    |> String.split("\n", trim: true)
    |> Enum.map(&Jason.decode!/1)
  end

  defp header(items), do: Enum.find(items, &(&1["key"] == "header"))
  defp ops(items), do: Enum.reject(items, &(&1["key"] == "header"))

  defp op_paths(items),
    do: items |> ops() |> Enum.map(& &1["value"]["path"])

  setup do
    # Create temp directory with test files
    dir = Path.join(System.tmp_dir!(), "hf_hub_test_#{:rand.uniform(1_000_000)}")
    File.mkdir_p!(dir)

    File.write!(Path.join(dir, "config.json"), ~s({"key": "value"}))
    File.write!(Path.join(dir, "model.bin"), String.duplicate("x", 100))

    File.mkdir_p!(Path.join(dir, "subdir"))
    File.write!(Path.join(dir, "subdir/data.txt"), "data")

    File.mkdir_p!(Path.join(dir, "__pycache__"))
    File.write!(Path.join(dir, "__pycache__/cache.pyc"), "cache")

    bypass = Bypass.open()
    original_endpoint = Application.get_env(:hf_hub, :endpoint)
    Application.put_env(:hf_hub, :endpoint, "http://localhost:#{bypass.port}")

    on_exit(fn ->
      File.rm_rf!(dir)

      if original_endpoint do
        Application.put_env(:hf_hub, :endpoint, original_endpoint)
      else
        Application.delete_env(:hf_hub, :endpoint)
      end
    end)

    {:ok, dir: dir, bypass: bypass}
  end

  describe "upload_folder/3" do
    test "uploads all files in folder (excluding default ignores)", %{dir: dir, bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/models/user/repo/commit/main", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        items = parse_ndjson(body)

        # Should have 3 files (excluding __pycache__)
        assert length(ops(items)) == 3

        paths = op_paths(items)
        assert "config.json" in paths
        assert "model.bin" in paths
        assert "subdir/data.txt" in paths
        refute "__pycache__/cache.pyc" in paths

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "commitUrl" => "url",
            "commitOid" => "abc",
            "commitMessage" => "msg",
            "repoUrl" => "url"
          })
        )
      end)

      {:ok, _} = Commit.upload_folder(dir, "user/repo", token: "hf_test")
    end

    test "respects allow_patterns", %{dir: dir, bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/models/user/repo/commit/main", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        items = parse_ndjson(body)

        # Only .json files
        assert length(ops(items)) == 1
        assert hd(ops(items))["value"]["path"] == "config.json"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "commitUrl" => "url",
            "commitOid" => "abc",
            "commitMessage" => "msg",
            "repoUrl" => "url"
          })
        )
      end)

      {:ok, _} =
        Commit.upload_folder(dir, "user/repo",
          token: "hf_test",
          allow_patterns: ["*.json"]
        )
    end

    test "respects ignore_patterns", %{dir: dir, bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/models/user/repo/commit/main", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        items = parse_ndjson(body)

        paths = op_paths(items)
        refute Enum.any?(paths, &String.ends_with?(&1, ".bin"))

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "commitUrl" => "url",
            "commitOid" => "abc",
            "commitMessage" => "msg",
            "repoUrl" => "url"
          })
        )
      end)

      {:ok, _} =
        Commit.upload_folder(dir, "user/repo",
          token: "hf_test",
          ignore_patterns: ["*.bin"]
        )
    end

    test "includes subdirectory files", %{dir: dir, bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/models/user/repo/commit/main", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        items = parse_ndjson(body)

        paths = op_paths(items)
        assert "subdir/data.txt" in paths

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "commitUrl" => "url",
            "commitOid" => "abc",
            "commitMessage" => "msg",
            "repoUrl" => "url"
          })
        )
      end)

      {:ok, _} = Commit.upload_folder(dir, "user/repo", token: "hf_test")
    end

    test "uses custom commit message", %{dir: dir, bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/models/user/repo/commit/main", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        items = parse_ndjson(body)

        assert header(items)["value"]["summary"] == "Upload my model"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "commitUrl" => "url",
            "commitOid" => "abc",
            "commitMessage" => "msg",
            "repoUrl" => "url"
          })
        )
      end)

      {:ok, _} =
        Commit.upload_folder(dir, "user/repo",
          token: "hf_test",
          commit_message: "Upload my model"
        )
    end

    test "returns error for non-existent folder" do
      {:error, {:folder_not_found, _}} =
        Commit.upload_folder(
          "/nonexistent/path",
          "user/repo",
          token: "hf_test"
        )
    end

    test "returns error for file path instead of folder", %{dir: dir} do
      file_path = Path.join(dir, "config.json")

      {:error, {:not_a_directory, ^file_path}} =
        Commit.upload_folder(
          file_path,
          "user/repo",
          token: "hf_test"
        )
    end

    test "handles delete_patterns for explicit paths", %{dir: dir, bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/models/user/repo/commit/main", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        items = parse_ndjson(body)

        # Should include add operations plus delete operations
        ops_list = ops(items)
        delete_ops = Enum.filter(ops_list, &(&1["key"] in ["deletedFile", "deletedFolder"]))

        assert length(delete_ops) == 1
        assert hd(delete_ops)["key"] == "deletedFile"
        assert hd(delete_ops)["value"]["path"] == "old_file.bin"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "commitUrl" => "url",
            "commitOid" => "abc",
            "commitMessage" => "msg",
            "repoUrl" => "url"
          })
        )
      end)

      {:ok, _} =
        Commit.upload_folder(dir, "user/repo",
          token: "hf_test",
          delete_patterns: ["old_file.bin"]
        )
    end
  end

  describe "upload_large_folder/3" do
    test "returns single commit when multi_commits is false", %{dir: dir, bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/models/user/repo/commit/main", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "commitUrl" => "url",
            "commitOid" => "abc",
            "commitMessage" => "msg",
            "repoUrl" => "url"
          })
        )
      end)

      {:ok, infos} =
        Commit.upload_large_folder(dir, "user/repo",
          token: "hf_test",
          multi_commits: false
        )

      assert length(infos) == 1
    end

    test "delegates to upload_folder when multi_commits is false", %{dir: dir, bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/models/user/repo/commit/main", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "commitUrl" => "url",
            "commitOid" => "abc",
            "commitMessage" => "msg",
            "repoUrl" => "url"
          })
        )
      end)

      {:ok, [info]} = Commit.upload_large_folder(dir, "user/repo", token: "hf_test")
      assert info.oid == "abc"
    end
  end

  describe "matches_pattern?/2" do
    test "matches simple glob patterns" do
      assert Commit.matches_pattern?("file.json", "*.json")
      assert Commit.matches_pattern?("config.json", "*.json")
      refute Commit.matches_pattern?("file.txt", "*.json")
    end

    test "matches double-star globstar patterns" do
      assert Commit.matches_pattern?("path/to/file.json", "**/*.json")
      assert Commit.matches_pattern?("deep/nested/path/file.json", "**/*.json")
      assert Commit.matches_pattern?("__pycache__/cache.pyc", "__pycache__/**")
    end

    test "matches single character wildcard" do
      assert Commit.matches_pattern?("file1.txt", "file?.txt")
      assert Commit.matches_pattern?("fileX.txt", "file?.txt")
      refute Commit.matches_pattern?("file12.txt", "file?.txt")
    end

    test "escapes dots in patterns" do
      assert Commit.matches_pattern?("file.json", "*.json")
      refute Commit.matches_pattern?("filejson", "*.json")
    end

    test "matches directory patterns" do
      assert Commit.matches_pattern?(".git", ".git")
      assert Commit.matches_pattern?(".git/config", ".git/**")
      assert Commit.matches_pattern?(".git/objects/abc", ".git/**")
    end
  end
end
