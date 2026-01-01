defmodule HfHub.AccessRequestsTest do
  use ExUnit.Case, async: false

  alias HfHub.AccessRequests
  alias HfHub.AccessRequests.AccessRequest

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

  describe "list_pending/2" do
    test "lists pending access requests for a model", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/models/org%2Fgated-model/user-access-request/pending",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!([
              %{
                "user" => "user1",
                "fullname" => "User One",
                "email" => "user1@example.com",
                "timestamp" => "2025-01-15T10:00:00Z",
                "fields" => %{"reason" => "Research"}
              },
              %{
                "user" => "user2",
                "fullname" => "User Two",
                "email" => "user2@example.com",
                "timestamp" => "2025-01-16T12:00:00Z",
                "fields" => %{}
              }
            ])
          )
        end
      )

      assert {:ok, requests} = AccessRequests.list_pending("org/gated-model")
      assert length(requests) == 2

      [first, second] = requests
      assert %AccessRequest{user: "user1", fullname: "User One", status: :pending} = first
      assert first.email == "user1@example.com"
      assert first.fields == %{"reason" => "Research"}

      assert %AccessRequest{user: "user2", status: :pending} = second
    end

    test "handles wrapped response format", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/models/org%2Fmodel/user-access-request/pending",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!(%{
              "accessRequests" => [
                %{"user" => "user1", "timestamp" => "2025-01-15T10:00:00Z"}
              ]
            })
          )
        end
      )

      assert {:ok, [request]} = AccessRequests.list_pending("org/model")
      assert request.user == "user1"
      assert request.status == :pending
    end

    test "handles empty list", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/models/org%2Fmodel/user-access-request/pending",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(200, Jason.encode!([]))
        end
      )

      assert {:ok, []} = AccessRequests.list_pending("org/model")
    end

    test "lists pending for datasets", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/datasets/org%2Fdataset/user-access-request/pending",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(200, Jason.encode!([]))
        end
      )

      assert {:ok, []} = AccessRequests.list_pending("org/dataset", repo_type: :dataset)
    end

    test "lists pending for spaces", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/spaces/org%2Fspace/user-access-request/pending",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(200, Jason.encode!([]))
        end
      )

      assert {:ok, []} = AccessRequests.list_pending("org/space", repo_type: :space)
    end

    test "handles 404 error", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/models/org%2Fmissing/user-access-request/pending",
        fn conn ->
          Plug.Conn.resp(conn, 404, "")
        end
      )

      assert {:error, :not_found} = AccessRequests.list_pending("org/missing")
    end

    test "handles 401 unauthorized", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/models/org%2Fmodel/user-access-request/pending",
        fn conn ->
          Plug.Conn.resp(conn, 401, "")
        end
      )

      assert {:error, :unauthorized} = AccessRequests.list_pending("org/model")
    end
  end

  describe "list_accepted/2" do
    test "lists accepted access requests", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/models/org%2Fmodel/user-access-request/accepted",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!([
              %{
                "user" => "approved_user",
                "fullname" => "Approved User",
                "email" => "approved@example.com",
                "timestamp" => "2025-01-10T08:00:00Z"
              }
            ])
          )
        end
      )

      assert {:ok, [request]} = AccessRequests.list_accepted("org/model")
      assert request.user == "approved_user"
      assert request.status == :accepted
    end
  end

  describe "list_rejected/2" do
    test "lists rejected access requests", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/api/models/org%2Fmodel/user-access-request/rejected",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!([
              %{
                "user" => "rejected_user",
                "fullname" => "Rejected User",
                "timestamp" => "2025-01-12T14:00:00Z"
              }
            ])
          )
        end
      )

      assert {:ok, [request]} = AccessRequests.list_rejected("org/model")
      assert request.user == "rejected_user"
      assert request.status == :rejected
    end
  end

  describe "accept/3" do
    test "accepts a pending request", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/models/org%2Fmodel/user-access-request/handle",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          params = Jason.decode!(body)
          assert params["user"] == "pending_user"
          assert params["status"] == "accepted"

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"ok" => true}))
        end
      )

      assert :ok = AccessRequests.accept("org/model", "pending_user", token: "test_token")
    end

    test "handles 401 unauthorized", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/models/org%2Fmodel/user-access-request/handle",
        fn conn ->
          Plug.Conn.resp(conn, 401, "")
        end
      )

      assert {:error, :unauthorized} =
               AccessRequests.accept("org/model", "user", token: "bad_token")
    end

    test "accepts for dataset", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/datasets/org%2Fdataset/user-access-request/handle",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{}))
        end
      )

      assert :ok =
               AccessRequests.accept("org/dataset", "user",
                 repo_type: :dataset,
                 token: "test_token"
               )
    end
  end

  describe "reject/3" do
    test "rejects a pending request", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/models/org%2Fmodel/user-access-request/handle",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          params = Jason.decode!(body)
          assert params["user"] == "pending_user"
          assert params["status"] == "rejected"

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"ok" => true}))
        end
      )

      assert :ok = AccessRequests.reject("org/model", "pending_user", token: "test_token")
    end
  end

  describe "cancel/3" do
    test "cancels/revokes access", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "DELETE",
        "/api/models/org%2Fmodel/user-access-request/handle",
        fn conn ->
          assert conn.query_string == "user=revoked_user"

          Plug.Conn.resp(conn, 204, "")
        end
      )

      assert :ok = AccessRequests.cancel("org/model", "revoked_user", token: "test_token")
    end

    test "handles 404 for non-existent request", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "DELETE",
        "/api/models/org%2Fmodel/user-access-request/handle",
        fn conn ->
          Plug.Conn.resp(conn, 404, "")
        end
      )

      assert {:error, :not_found} =
               AccessRequests.cancel("org/model", "unknown_user", token: "test_token")
    end
  end

  describe "grant/3" do
    test "grants access directly without request", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/models/org%2Fmodel/user-access-request/grant",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          params = Jason.decode!(body)
          assert params["user"] == "new_user"

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{"ok" => true}))
        end
      )

      assert :ok = AccessRequests.grant("org/model", "new_user", token: "test_token")
    end

    test "handles 403 forbidden", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/models/org%2Fmodel/user-access-request/grant",
        fn conn ->
          Plug.Conn.resp(conn, 403, "")
        end
      )

      assert {:error, :forbidden} =
               AccessRequests.grant("org/model", "user", token: "test_token")
    end

    test "grants for space", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/spaces/org%2Fspace/user-access-request/grant",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(200, Jason.encode!(%{}))
        end
      )

      assert :ok =
               AccessRequests.grant("org/space", "user",
                 repo_type: :space,
                 token: "test_token"
               )
    end
  end

  describe "AccessRequest struct" do
    test "from_response parses user field" do
      response = %{"user" => "testuser", "fullname" => "Test User"}
      request = AccessRequest.from_response(response, :pending)

      assert request.user == "testuser"
      assert request.fullname == "Test User"
      assert request.status == :pending
    end

    test "from_response handles username alternative field" do
      response = %{"username" => "altuser", "email" => "alt@example.com"}
      request = AccessRequest.from_response(response, :accepted)

      assert request.user == "altuser"
      assert request.email == "alt@example.com"
      assert request.status == :accepted
    end

    test "from_response parses timestamp" do
      response = %{"user" => "user", "timestamp" => "2025-01-15T10:30:00Z"}
      request = AccessRequest.from_response(response, :pending)

      assert request.timestamp == ~U[2025-01-15 10:30:00Z]
    end

    test "from_response handles nil timestamp" do
      response = %{"user" => "user"}
      request = AccessRequest.from_response(response, :pending)

      assert is_nil(request.timestamp)
    end

    test "from_response handles invalid timestamp" do
      response = %{"user" => "user", "timestamp" => "not-a-date"}
      request = AccessRequest.from_response(response, :pending)

      assert is_nil(request.timestamp)
    end

    test "from_response defaults fields to empty map" do
      response = %{"user" => "user"}
      request = AccessRequest.from_response(response, :pending)

      assert request.fields == %{}
    end

    test "from_response preserves custom fields" do
      response = %{
        "user" => "user",
        "fields" => %{
          "organization" => "ACME Corp",
          "use_case" => "Commercial application"
        }
      }

      request = AccessRequest.from_response(response, :pending)

      assert request.fields == %{
               "organization" => "ACME Corp",
               "use_case" => "Commercial application"
             }
    end
  end
end
