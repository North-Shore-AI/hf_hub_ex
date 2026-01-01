defmodule HfHub.DiscussionsTest do
  use ExUnit.Case, async: false

  alias HfHub.Discussions
  alias HfHub.Discussions.{Comment, Discussion, DiscussionDetails}

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

  describe "list/2" do
    test "lists all discussions for a model", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/models/org%2Fmodel/discussions", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "discussions" => [
              %{
                "num" => 1,
                "title" => "Bug report",
                "author" => "user1",
                "status" => "open",
                "isPullRequest" => false,
                "createdAt" => "2025-01-15T10:00:00Z",
                "updatedAt" => "2025-01-15T12:00:00Z",
                "numComments" => 3
              },
              %{
                "num" => 2,
                "title" => "Feature request",
                "author" => "user2",
                "status" => "closed",
                "isPullRequest" => false,
                "numComments" => 5
              }
            ]
          })
        )
      end)

      assert {:ok, discussions} = Discussions.list("org/model")
      assert length(discussions) == 2

      [first, second] = discussions
      assert %Discussion{num: 1, title: "Bug report", author: "user1", status: :open} = first
      assert first.num_comments == 3
      refute first.is_pull_request

      assert %Discussion{num: 2, status: :closed} = second
    end

    test "handles list response format (without wrapper)", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/models/org%2Fmodel/discussions", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!([
            %{"num" => 1, "title" => "Test", "author" => "user", "status" => "open"}
          ])
        )
      end)

      assert {:ok, [disc]} = Discussions.list("org/model")
      assert disc.num == 1
    end

    test "filters by status", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/models/org%2Fmodel/discussions", fn conn ->
        assert conn.query_string =~ "status=open"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"discussions" => []}))
      end)

      assert {:ok, []} = Discussions.list("org/model", status: :open)
    end

    test "filters by author", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/models/org%2Fmodel/discussions", fn conn ->
        assert conn.query_string =~ "author=testuser"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"discussions" => []}))
      end)

      assert {:ok, []} = Discussions.list("org/model", author: "testuser")
    end

    test "lists discussions for datasets", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/datasets/org%2Fdataset/discussions", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"discussions" => []}))
      end)

      assert {:ok, []} = Discussions.list("org/dataset", repo_type: :dataset)
    end

    test "lists discussions for spaces", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/spaces/org%2Fspace/discussions", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"discussions" => []}))
      end)

      assert {:ok, []} = Discussions.list("org/space", repo_type: :space)
    end

    test "handles 404 error", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/models/org%2Fmissing/discussions", fn conn ->
        Plug.Conn.resp(conn, 404, "")
      end)

      assert {:error, :not_found} = Discussions.list("org/missing")
    end
  end

  describe "get/3" do
    test "gets discussion details", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/models/org%2Fmodel/discussions/42", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "num" => 42,
            "title" => "Test Discussion",
            "author" => "testuser",
            "status" => "open",
            "isPullRequest" => false,
            "createdAt" => "2025-01-15T10:00:00Z",
            "events" => [
              %{
                "type" => "comment",
                "id" => "comment-1",
                "author" => "testuser",
                "content" => "Initial comment",
                "createdAt" => "2025-01-15T10:00:00Z"
              },
              %{
                "type" => "status-change",
                "id" => "status-1",
                "author" => "admin",
                "newStatus" => "closed",
                "createdAt" => "2025-01-15T11:00:00Z"
              }
            ]
          })
        )
      end)

      assert {:ok, details} = Discussions.get("org/model", 42)
      assert %DiscussionDetails{num: 42, title: "Test Discussion"} = details
      assert length(details.events) == 2
    end

    test "gets pull request details", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/models/org%2Fmodel/discussions/10", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "num" => 10,
            "title" => "Add feature",
            "author" => "contributor",
            "status" => "open",
            "isPullRequest" => true,
            "targetBranch" => "main",
            "headSha" => "abc123",
            "events" => []
          })
        )
      end)

      assert {:ok, details} = Discussions.get("org/model", 10)
      assert details.is_pull_request
      assert details.target_branch == "main"
      assert details.head_sha == "abc123"
    end

    test "handles 404 error", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/models/org%2Fmodel/discussions/999", fn conn ->
        Plug.Conn.resp(conn, 404, "")
      end)

      assert {:error, :not_found} = Discussions.get("org/model", 999)
    end
  end

  describe "create/3" do
    test "creates a new discussion", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/models/org%2Fmodel/discussions", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["title"] == "New Discussion"
        assert params["description"] == "This is the description"
        assert params["pullRequest"] == false

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "num" => 5,
            "title" => "New Discussion",
            "author" => "creator",
            "status" => "open",
            "isPullRequest" => false,
            "events" => []
          })
        )
      end)

      assert {:ok, details} =
               Discussions.create("org/model", "New Discussion",
                 description: "This is the description",
                 token: "test_token"
               )

      assert details.num == 5
      assert details.title == "New Discussion"
    end

    test "requires authentication", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/models/org%2Fmodel/discussions", fn conn ->
        Plug.Conn.resp(conn, 401, "")
      end)

      assert {:error, :unauthorized} = Discussions.create("org/model", "Test", token: "bad_token")
    end
  end

  describe "create_pr/3" do
    test "creates a pull request", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/models/org%2Fmodel/discussions", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["title"] == "Add feature"
        assert params["pullRequest"] == true

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "num" => 6,
            "title" => "Add feature",
            "author" => "contributor",
            "status" => "draft",
            "isPullRequest" => true,
            "events" => []
          })
        )
      end)

      assert {:ok, details} = Discussions.create_pr("org/model", "Add feature", token: "test_token")
      assert details.is_pull_request
    end
  end

  describe "comment/4" do
    test "adds a comment to a discussion", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/models/org%2Fmodel/discussions/42/comment",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          params = Jason.decode!(body)
          assert params["comment"] == "Thanks for reporting!"

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!(%{
              "id" => "comment-123",
              "author" => "responder",
              "content" => "Thanks for reporting!",
              "createdAt" => "2025-01-15T12:00:00Z"
            })
          )
        end
      )

      assert {:ok, comment} =
               Discussions.comment("org/model", 42, "Thanks for reporting!", token: "test_token")

      assert %Comment{id: "comment-123", content: "Thanks for reporting!"} = comment
    end
  end

  describe "edit_comment/5" do
    test "edits an existing comment", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "PUT",
        "/api/models/org%2Fmodel/discussions/42/comment/abc123",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          params = Jason.decode!(body)
          assert params["content"] == "Updated content"

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!(%{
              "id" => "abc123",
              "author" => "user",
              "content" => "Updated content",
              "edited" => true
            })
          )
        end
      )

      assert {:ok, comment} =
               Discussions.edit_comment("org/model", 42, "abc123", "Updated content",
                 token: "test_token"
               )

      assert comment.edited
      assert comment.content == "Updated content"
    end
  end

  describe "hide_comment/4" do
    test "hides a comment", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "PUT",
        "/api/models/org%2Fmodel/discussions/42/comment/abc123/hide",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!(%{
              "id" => "abc123",
              "author" => "user",
              "content" => "Hidden content",
              "hidden" => true
            })
          )
        end
      )

      assert {:ok, comment} =
               Discussions.hide_comment("org/model", 42, "abc123", token: "test_token")

      assert comment.hidden
    end
  end

  describe "close/3" do
    test "closes a discussion", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "PUT",
        "/api/models/org%2Fmodel/discussions/42/status",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          params = Jason.decode!(body)
          assert params["status"] == "closed"

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!(%{
              "num" => 42,
              "title" => "Test",
              "status" => "closed"
            })
          )
        end
      )

      assert {:ok, discussion} = Discussions.close("org/model", 42, token: "test_token")
      assert discussion.status == :closed
    end

    test "closes with comment", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "PUT",
        "/api/models/org%2Fmodel/discussions/42/status",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          params = Jason.decode!(body)
          assert params["status"] == "closed"
          assert params["comment"] == "Fixed in v2.0"

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!(%{"num" => 42, "status" => "closed"})
          )
        end
      )

      assert {:ok, _} =
               Discussions.close("org/model", 42, comment: "Fixed in v2.0", token: "test_token")
    end
  end

  describe "reopen/3" do
    test "reopens a closed discussion", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "PUT",
        "/api/models/org%2Fmodel/discussions/42/status",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          params = Jason.decode!(body)
          assert params["status"] == "open"

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!(%{"num" => 42, "status" => "open"})
          )
        end
      )

      assert {:ok, discussion} = Discussions.reopen("org/model", 42, token: "test_token")
      assert discussion.status == :open
    end
  end

  describe "change_status/4" do
    test "changes status to any valid value", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "PUT",
        "/api/models/org%2Fmodel/discussions/42/status",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          params = Jason.decode!(body)
          assert params["status"] == "merged"

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!(%{"num" => 42, "status" => "merged"})
          )
        end
      )

      assert {:ok, disc} = Discussions.change_status("org/model", 42, :merged, token: "test_token")
      assert disc.status == :merged
    end
  end

  describe "merge_pr/3" do
    test "merges a pull request", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/models/org%2Fmodel/discussions/10/merge",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!(%{
              "num" => 10,
              "title" => "Add feature",
              "status" => "merged",
              "isPullRequest" => true
            })
          )
        end
      )

      assert {:ok, pr} = Discussions.merge_pr("org/model", 10, token: "test_token")
      assert pr.status == :merged
    end

    test "merges with comment", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/models/org%2Fmodel/discussions/10/merge",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          params = Jason.decode!(body)
          assert params["comment"] == "LGTM!"

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!(%{"num" => 10, "status" => "merged"})
          )
        end
      )

      assert {:ok, _} = Discussions.merge_pr("org/model", 10, comment: "LGTM!", token: "test_token")
    end

    test "handles error when merging non-PR", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/models/org%2Fmodel/discussions/42/merge",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(400, Jason.encode!(%{"error" => "Not a pull request"}))
        end
      )

      assert {:error, %HfHub.Errors.BadRequest{}} =
               Discussions.merge_pr("org/model", 42, token: "test_token")
    end
  end

  describe "rename/4" do
    test "renames a discussion", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "PUT",
        "/api/models/org%2Fmodel/discussions/42/title",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          params = Jason.decode!(body)
          assert params["title"] == "New Title"

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!(%{
              "num" => 42,
              "title" => "New Title",
              "status" => "open"
            })
          )
        end
      )

      assert {:ok, discussion} =
               Discussions.rename("org/model", 42, "New Title", token: "test_token")

      assert discussion.title == "New Title"
    end
  end
end
