defmodule HfHub.CommitTest do
  # async: false to avoid race conditions with Application env
  use ExUnit.Case, async: false

  alias HfHub.Commit
  alias HfHub.Commit.{CommitInfo, Operation}

  defp parse_ndjson(body) do
    body
    |> String.split("\n", trim: true)
    |> Enum.map(&Jason.decode!/1)
  end

  defp header(items), do: Enum.find(items, &(&1["key"] == "header"))
  defp ops(items), do: Enum.reject(items, &(&1["key"] == "header"))

  defp assert_ndjson_content_type(conn) do
    content_type = Plug.Conn.get_req_header(conn, "content-type")
    assert Enum.any?(content_type, &String.contains?(&1, "application/x-ndjson"))
  end

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

  describe "upload_file/4 with regular upload" do
    test "uploads small file successfully", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/models/user/repo/commit/main", fn conn ->
        assert_ndjson_content_type(conn)
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        items = parse_ndjson(body)

        assert header(items)["value"]["summary"] == "Upload config.json"
        assert [op] = ops(items)
        assert op["key"] == "file"
        assert op["value"]["path"] == "config.json"
        assert op["value"]["encoding"] == "base64"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "commitUrl" => "https://huggingface.co/user/repo/commit/abc123",
            "commitOid" => "abc123",
            "commitMessage" => "Upload config.json",
            "repoUrl" => "https://huggingface.co/user/repo"
          })
        )
      end)

      {:ok, info} =
        Commit.upload_file(
          ~s({"key": "value"}),
          "config.json",
          "user/repo",
          token: "hf_test_token",
          preupload: false
        )

      assert %CommitInfo{} = info
      assert info.oid == "abc123"
    end

    test "uploads with custom commit message", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/models/user/repo/commit/main", fn conn ->
        assert_ndjson_content_type(conn)
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        items = parse_ndjson(body)

        assert header(items)["value"]["summary"] == "Custom message"

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

      {:ok, _info} =
        Commit.upload_file(
          "content",
          "file.txt",
          "user/repo",
          token: "hf_test",
          commit_message: "Custom message",
          preupload: false
        )
    end

    test "returns error without token", %{bypass: _bypass} do
      # Clear any application-level token
      original_token = Application.get_env(:hf_hub, :token)
      Application.delete_env(:hf_hub, :token)
      # Clear environment variable
      original_env = System.get_env("HF_TOKEN")
      System.delete_env("HF_TOKEN")

      try do
        {:error, :no_token} =
          Commit.upload_file(
            "content",
            "file.txt",
            "user/repo",
            commit_message: "Test",
            preupload: false
          )
      after
        if original_token, do: Application.put_env(:hf_hub, :token, original_token)
        if original_env, do: System.put_env("HF_TOKEN", original_env)
      end
    end
  end

  describe "create/3" do
    test "returns error without commit message", %{bypass: _bypass} do
      {:error, :missing_commit_message} =
        Commit.create(
          "user/repo",
          [Operation.add("file.txt", "content")],
          token: "hf_test",
          preupload: false
        )
    end

    test "returns error with empty commit message", %{bypass: _bypass} do
      {:error, :empty_commit_message} =
        Commit.create(
          "user/repo",
          [Operation.add("file.txt", "content")],
          token: "hf_test",
          commit_message: "",
          preupload: false
        )
    end

    test "commits multiple operations", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/models/user/repo/commit/main", fn conn ->
        assert_ndjson_content_type(conn)
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        items = parse_ndjson(body)

        assert length(ops(items)) == 2

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
        Commit.create(
          "user/repo",
          [
            Operation.add("new.txt", "content"),
            Operation.delete("old.txt")
          ],
          token: "hf_test",
          commit_message: "Update files",
          preupload: false
        )
    end

    test "uses correct path for datasets", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/datasets/user/dataset/commit/main", fn conn ->
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
        Commit.create(
          "user/dataset",
          [Operation.add("data.json", "[]")],
          token: "hf_test",
          commit_message: "Add data",
          repo_type: :dataset,
          preupload: false
        )
    end

    test "uses correct path for spaces", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/spaces/user/space/commit/main", fn conn ->
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
        Commit.create(
          "user/space",
          [Operation.add("app.py", "import gradio")],
          token: "hf_test",
          commit_message: "Add app",
          repo_type: :space,
          preupload: false
        )
    end

    test "uses custom revision", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/models/user/repo/commit/dev", fn conn ->
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
        Commit.create(
          "user/repo",
          [Operation.add("file.txt", "content")],
          token: "hf_test",
          commit_message: "Add file",
          revision: "dev",
          preupload: false
        )
    end

    test "encodes revision path segment while preserving repo slash", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/models/user/repo/commit/feature%2Fupload%20%231",
        fn conn ->
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
        end
      )

      {:ok, _} =
        Commit.create(
          "user/repo",
          [Operation.add("file.txt", "content")],
          token: "hf_test",
          commit_message: "Add file",
          revision: "feature/upload #1",
          preupload: false
        )
    end

    test "includes createPr flag", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/models/user/repo/commit/main", fn conn ->
        assert_ndjson_content_type(conn)
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        items = parse_ndjson(body)

        # createPr travels as a query param, not a body field
        assert conn.query_string =~ "create_pr=1"
        assert header(items) != nil

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "commitUrl" => "url",
            "commitOid" => "abc",
            "commitMessage" => "msg",
            "repoUrl" => "url",
            "pullRequest" => %{
              "url" => "https://huggingface.co/user/repo/discussions/1",
              "num" => 1,
              "revision" => "refs/pr/1"
            }
          })
        )
      end)

      {:ok, info} =
        Commit.create(
          "user/repo",
          [Operation.add("file.txt", "content")],
          token: "hf_test",
          commit_message: "Add file",
          create_pr: true,
          preupload: false
        )

      assert info.pr_url == "https://huggingface.co/user/repo/discussions/1"
      assert info.pr_num == 1
    end

    test "includes commit description", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/models/user/repo/commit/main", fn conn ->
        assert_ndjson_content_type(conn)
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        items = parse_ndjson(body)

        assert header(items)["value"]["summary"] == "Add file"
        assert header(items)["value"]["description"] == "This is a longer description"

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
        Commit.create(
          "user/repo",
          [Operation.add("file.txt", "content")],
          token: "hf_test",
          commit_message: "Add file",
          commit_description: "This is a longer description",
          preupload: false
        )
    end
  end

  describe "delete_file/3" do
    test "deletes file successfully", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/models/user/repo/commit/main", fn conn ->
        assert_ndjson_content_type(conn)
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        items = parse_ndjson(body)

        assert [op] = ops(items)
        assert op["key"] == "deletedFile"
        assert op["value"]["path"] == "old_file.bin"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "commitUrl" => "https://huggingface.co/user/repo/commit/abc123",
            "commitOid" => "abc123",
            "commitMessage" => "Delete old_file.bin",
            "repoUrl" => "https://huggingface.co/user/repo"
          })
        )
      end)

      {:ok, _info} =
        Commit.delete_file(
          "old_file.bin",
          "user/repo",
          token: "hf_test",
          preupload: false
        )
    end

    test "uses custom commit message", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/models/user/repo/commit/main", fn conn ->
        assert_ndjson_content_type(conn)
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        items = parse_ndjson(body)

        assert header(items)["value"]["summary"] == "Remove old file"

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
        Commit.delete_file(
          "old.txt",
          "user/repo",
          token: "hf_test",
          commit_message: "Remove old file",
          preupload: false
        )
    end
  end

  describe "delete_folder/3" do
    test "deletes folder successfully", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/models/user/repo/commit/main", fn conn ->
        assert_ndjson_content_type(conn)
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        items = parse_ndjson(body)

        assert [op] = ops(items)
        assert op["key"] == "deletedFolder"

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

      {:ok, _} = Commit.delete_folder("old_dir", "user/repo", token: "hf_test")
    end
  end

  describe "needs_lfs?/1" do
    test "returns false for small files" do
      op = Operation.add("small.txt", String.duplicate("x", 1000))
      refute Commit.needs_lfs?(op)
    end

    test "returns true for files >= 10MB" do
      # Create a minimal upload_info with size >= 10MB
      upload_info = %HfHub.LFS.UploadInfo{
        sha256: :crypto.hash(:sha256, "test"),
        size: 10 * 1024 * 1024,
        sample: "test"
      }

      op = Operation.add("large.bin", "x", upload_info: upload_info)
      assert Commit.needs_lfs?(op)
    end
  end

  describe "lfs_threshold/0" do
    test "returns 10MB in bytes" do
      assert Commit.lfs_threshold() == 10 * 1024 * 1024
    end
  end
end
