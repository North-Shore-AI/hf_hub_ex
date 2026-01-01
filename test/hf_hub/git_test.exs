defmodule HfHub.GitTest do
  use ExUnit.Case, async: false
  alias HfHub.Git
  alias HfHub.Git.{BranchInfo, CommitInfo, GitRefs, TagInfo}

  setup do
    bypass = Bypass.open()

    original_url = Application.get_env(:hf_hub, :endpoint)
    Application.put_env(:hf_hub, :endpoint, "http://localhost:#{bypass.port}")

    on_exit(fn ->
      if original_url do
        Application.put_env(:hf_hub, :endpoint, original_url)
      else
        Application.delete_env(:hf_hub, :endpoint)
      end
    end)

    {:ok, bypass: bypass}
  end

  describe "create_branch/3" do
    test "creates a branch from main", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/models/org%2Fmodel/branch/feature", fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["startingPoint"] == "main"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "name" => "feature",
            "ref" => "refs/heads/feature",
            "targetCommit" => "abc123"
          })
        )
      end)

      assert {:ok, %BranchInfo{} = info} = Git.create_branch("org/model", "feature", token: "token")
      assert info.name == "feature"
      assert info.ref == "refs/heads/feature"
      assert info.target_commit == "abc123"
    end

    test "creates a branch from specific revision", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/models/my-model/branch/hotfix", fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["startingPoint"] == "v1.0"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"name" => "hotfix"}))
      end)

      assert {:ok, info} = Git.create_branch("my-model", "hotfix", revision: "v1.0", token: "token")
      assert info.name == "hotfix"
    end

    test "creates branch for dataset", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/datasets/org%2Fds/branch/dev", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"name" => "dev"}))
      end)

      assert {:ok, info} = Git.create_branch("org/ds", "dev", repo_type: :dataset, token: "token")
      assert info.name == "dev"
    end

    test "returns existing branch with exist_ok: true", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/models/model/branch/existing", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(409, Jason.encode!(%{"error" => "Branch already exists"}))
      end)

      assert {:ok, info} = Git.create_branch("model", "existing", exist_ok: true, token: "token")
      assert info.name == "existing"
    end

    test "returns error without token", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/models/model/branch/new", fn conn ->
        Plug.Conn.resp(conn, 401, "")
      end)

      assert {:error, :unauthorized} = Git.create_branch("model", "new", token: "bad")
    end
  end

  describe "delete_branch/3" do
    test "deletes existing branch", %{bypass: bypass} do
      Bypass.expect_once(bypass, "DELETE", "/api/models/org%2Fmodel/branch/old", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, "{}")
      end)

      assert :ok = Git.delete_branch("org/model", "old", token: "token")
    end

    test "returns 204 on success", %{bypass: bypass} do
      Bypass.expect_once(bypass, "DELETE", "/api/models/model/branch/temp", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      assert :ok = Git.delete_branch("model", "temp", token: "token")
    end

    test "returns error for protected branch", %{bypass: bypass} do
      Bypass.expect_once(bypass, "DELETE", "/api/models/model/branch/main", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(403, Jason.encode!(%{"error" => "Cannot delete protected branch"}))
      end)

      assert {:error, :forbidden} = Git.delete_branch("model", "main", token: "token")
    end
  end

  describe "create_tag/3" do
    test "creates lightweight tag", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/models/model/tag/v1.0", fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["ref"] == "refs/heads/main"
        refute Map.has_key?(params, "message")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "name" => "v1.0",
            "ref" => "refs/tags/v1.0",
            "targetCommit" => "abc123"
          })
        )
      end)

      assert {:ok, %TagInfo{} = info} = Git.create_tag("model", "v1.0", token: "token")
      assert info.name == "v1.0"
      assert info.ref == "refs/tags/v1.0"
    end

    test "creates annotated tag with message", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/models/model/tag/v2.0", fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["ref"] == "refs/heads/abc123"
        assert params["message"] == "Release v2.0"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"name" => "v2.0", "message" => "Release v2.0"}))
      end)

      assert {:ok, info} =
               Git.create_tag("model", "v2.0",
                 revision: "abc123",
                 message: "Release v2.0",
                 token: "token"
               )

      assert info.name == "v2.0"
      assert info.message == "Release v2.0"
    end

    test "creates tag for space", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/spaces/org%2Fspace/tag/v1", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"name" => "v1"}))
      end)

      assert {:ok, info} = Git.create_tag("org/space", "v1", repo_type: :space, token: "token")
      assert info.name == "v1"
    end

    test "returns existing tag with exist_ok: true", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/models/model/tag/existing", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(409, Jason.encode!(%{"error" => "Tag already exists"}))
      end)

      assert {:ok, info} = Git.create_tag("model", "existing", exist_ok: true, token: "token")
      assert info.name == "existing"
    end
  end

  describe "delete_tag/3" do
    test "deletes existing tag", %{bypass: bypass} do
      Bypass.expect_once(bypass, "DELETE", "/api/models/model/tag/old-tag", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, "{}")
      end)

      assert :ok = Git.delete_tag("model", "old-tag", token: "token")
    end

    test "returns error for non-existent tag", %{bypass: bypass} do
      Bypass.expect_once(bypass, "DELETE", "/api/models/model/tag/missing", fn conn ->
        Plug.Conn.resp(conn, 404, "")
      end)

      assert {:error, :not_found} = Git.delete_tag("model", "missing", token: "token")
    end
  end

  describe "list_refs/2" do
    test "lists branches and tags", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/models/bert-base-uncased/refs", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "branches" => [
              %{"name" => "main", "ref" => "refs/heads/main", "targetCommit" => "abc123"},
              %{"name" => "dev", "ref" => "refs/heads/dev", "targetCommit" => "def456"}
            ],
            "tags" => [
              %{"name" => "v1.0", "ref" => "refs/tags/v1.0", "targetCommit" => "abc123"}
            ],
            "converts" => [],
            "pullRequests" => []
          })
        )
      end)

      assert {:ok, %GitRefs{} = refs} = Git.list_refs("bert-base-uncased")
      assert length(refs.branches) == 2
      assert length(refs.tags) == 1
      assert hd(refs.branches).name == "main"
      assert hd(refs.tags).name == "v1.0"
    end

    test "lists refs with pull requests", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/models/model/refs", fn conn ->
        assert conn.query_string =~ "include_pull_requests"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "branches" => [],
            "tags" => [],
            "converts" => [],
            "pullRequests" => [
              %{"name" => "pr/1", "ref" => "refs/pr/1"}
            ]
          })
        )
      end)

      assert {:ok, refs} = Git.list_refs("model", include_pull_requests: true)
      assert length(refs.pull_requests) == 1
    end

    test "lists refs for dataset", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/datasets/squad/refs", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"branches" => [], "tags" => []}))
      end)

      assert {:ok, _refs} = Git.list_refs("squad", repo_type: :dataset)
    end

    test "handles empty repo", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/models/empty-repo/refs", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{}))
      end)

      assert {:ok, refs} = Git.list_refs("empty-repo")
      assert refs.branches == []
      assert refs.tags == []
    end
  end

  describe "list_commits/2" do
    test "lists commits from main", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/models/model/commits/main", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!([
            %{
              "id" => "abc123",
              "title" => "Initial commit",
              "message" => "Full message",
              "authors" => [%{"name" => "User", "email" => "user@example.com"}],
              "date" => "2024-01-15T10:30:00Z"
            },
            %{
              "id" => "def456",
              "title" => "Second commit",
              "message" => "Another message",
              "authors" => [%{"name" => "Other", "email" => "other@example.com"}],
              "date" => "2024-01-16T11:00:00Z"
            }
          ])
        )
      end)

      assert {:ok, commits} = Git.list_commits("model", token: "token")
      assert length(commits) == 2
      assert %CommitInfo{} = hd(commits)
      assert hd(commits).id == "abc123"
      assert hd(commits).title == "Initial commit"
      assert hd(commits).authors == [%{name: "User", email: "user@example.com"}]
      assert %DateTime{} = hd(commits).date
    end

    test "lists commits from specific branch", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/models/model/commits/dev", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!([%{"id" => "xyz789", "title" => "Dev commit"}]))
      end)

      assert {:ok, commits} = Git.list_commits("model", revision: "dev", token: "token")
      assert hd(commits).id == "xyz789"
    end

    test "lists commits from tag", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/models/model/commits/v1.0", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!([%{"id" => "tag123"}]))
      end)

      assert {:ok, commits} = Git.list_commits("model", revision: "v1.0", token: "token")
      assert hd(commits).id == "tag123"
    end

    test "handles wrapped response format", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/models/model/commits/main", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "commits" => [%{"id" => "wrapped123"}]
          })
        )
      end)

      assert {:ok, commits} = Git.list_commits("model", token: "token")
      assert hd(commits).id == "wrapped123"
    end

    test "handles dataset commits", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/datasets/ds/commits/main", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!([%{"id" => "dscommit"}]))
      end)

      assert {:ok, commits} = Git.list_commits("ds", repo_type: :dataset, token: "token")
      assert hd(commits).id == "dscommit"
    end
  end

  describe "super_squash/2" do
    test "squashes repository history", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/models/model/super-squash", fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["branch"] == "main"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, "{}")
      end)

      assert :ok = Git.super_squash("model", token: "token")
    end

    test "squashes with custom message", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/models/model/super-squash", fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["message"] == "Squashed history"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, "{}")
      end)

      assert :ok = Git.super_squash("model", message: "Squashed history", token: "token")
    end

    test "squashes specific branch", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/models/model/super-squash", fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["branch"] == "dev"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, "{}")
      end)

      assert :ok = Git.super_squash("model", branch: "dev", token: "token")
    end

    test "returns error without write permission", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/models/model/super-squash", fn conn ->
        Plug.Conn.resp(conn, 403, "")
      end)

      assert {:error, :forbidden} = Git.super_squash("model", token: "token")
    end

    test "squashes dataset", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/datasets/ds/super-squash", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, "{}")
      end)

      assert :ok = Git.super_squash("ds", repo_type: :dataset, token: "token")
    end
  end
end
