defmodule HfHub.CommitTest do
  # async: false to avoid race conditions with Application env
  use ExUnit.Case, async: false

  alias HfHub.Commit
  alias HfHub.Commit.{CommitInfo, Operation}

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
      Bypass.expect_once(bypass, "POST", "/api/models/user%2Frepo/commit/main", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        payload = Jason.decode!(body)

        assert payload["summary"] == "Upload config.json"
        assert [operation] = payload["operations"]
        assert operation["key"] == "config.json"
        assert operation["value"]["encoding"] == "base64"

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
          token: "hf_test_token"
        )

      assert %CommitInfo{} = info
      assert info.oid == "abc123"
    end

    test "uploads with custom commit message", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/models/user%2Frepo/commit/main", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        payload = Jason.decode!(body)

        assert payload["summary"] == "Custom message"

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
          commit_message: "Custom message"
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
            commit_message: "Test"
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
          token: "hf_test"
        )
    end

    test "returns error with empty commit message", %{bypass: _bypass} do
      {:error, :empty_commit_message} =
        Commit.create(
          "user/repo",
          [Operation.add("file.txt", "content")],
          token: "hf_test",
          commit_message: ""
        )
    end

    test "commits multiple operations", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/models/user%2Frepo/commit/main", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        payload = Jason.decode!(body)

        assert length(payload["operations"]) == 2

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
          commit_message: "Update files"
        )
    end

    test "uses correct path for datasets", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/datasets/user%2Fdataset/commit/main", fn conn ->
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
          repo_type: :dataset
        )
    end

    test "uses correct path for spaces", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/spaces/user%2Fspace/commit/main", fn conn ->
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
          repo_type: :space
        )
    end

    test "uses custom revision", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/models/user%2Frepo/commit/dev", fn conn ->
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
          revision: "dev"
        )
    end

    test "includes createPr flag", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/models/user%2Frepo/commit/main", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        payload = Jason.decode!(body)

        assert payload["createPr"] == true

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
          create_pr: true
        )

      assert info.pr_url == "https://huggingface.co/user/repo/discussions/1"
      assert info.pr_num == 1
    end

    test "includes commit description", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/models/user%2Frepo/commit/main", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        payload = Jason.decode!(body)

        assert payload["summary"] == "Add file"
        assert payload["description"] == "This is a longer description"

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
          commit_description: "This is a longer description"
        )
    end
  end

  describe "delete_file/3" do
    test "deletes file successfully", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/models/user%2Frepo/commit/main", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        payload = Jason.decode!(body)

        assert [operation] = payload["operations"]
        assert operation["key"] == "old_file.bin"
        assert operation["value"]["delete"]["isFolder"] == false

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
          token: "hf_test"
        )
    end

    test "uses custom commit message", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/models/user%2Frepo/commit/main", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        payload = Jason.decode!(body)

        assert payload["summary"] == "Remove old file"

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
          commit_message: "Remove old file"
        )
    end
  end

  describe "delete_folder/3" do
    test "deletes folder successfully", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/models/user%2Frepo/commit/main", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        payload = Jason.decode!(body)

        assert [operation] = payload["operations"]
        assert operation["value"]["delete"]["isFolder"] == true

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
