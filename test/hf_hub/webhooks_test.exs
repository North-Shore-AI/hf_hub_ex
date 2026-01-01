defmodule HfHub.WebhooksTest do
  use ExUnit.Case, async: false

  alias HfHub.Webhooks
  alias HfHub.Webhooks.{WatchedItem, WebhookInfo}

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

  describe "list/1" do
    test "lists all webhooks", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/settings/webhooks", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!([
            %{
              "id" => "webhook-1",
              "url" => "https://example.com/hook1",
              "watched" => [
                %{"type" => "model", "name" => "bert-base-uncased"}
              ],
              "domains" => ["repo"],
              "disabled" => false,
              "createdAt" => "2025-01-15T10:00:00Z"
            },
            %{
              "id" => "webhook-2",
              "url" => "https://example.com/hook2",
              "watched" => [],
              "domains" => ["repo", "discussion"],
              "disabled" => true
            }
          ])
        )
      end)

      assert {:ok, webhooks} = Webhooks.list(token: "test_token")
      assert length(webhooks) == 2

      [first, second] = webhooks
      assert %WebhookInfo{id: "webhook-1", url: "https://example.com/hook1"} = first
      assert length(first.watched) == 1
      assert hd(first.watched).type == :model
      assert hd(first.watched).name == "bert-base-uncased"
      assert first.domains == [:repo]
      refute first.disabled

      assert %WebhookInfo{id: "webhook-2", disabled: true} = second
      assert second.domains == [:repo, :discussion]
    end

    test "handles wrapped response format", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/settings/webhooks", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "webhooks" => [
              %{"id" => "webhook-1", "url" => "https://example.com/hook", "watched" => []}
            ]
          })
        )
      end)

      assert {:ok, [webhook]} = Webhooks.list(token: "test_token")
      assert webhook.id == "webhook-1"
    end

    test "handles 401 unauthorized", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/settings/webhooks", fn conn ->
        Plug.Conn.resp(conn, 401, "")
      end)

      assert {:error, :unauthorized} = Webhooks.list(token: "bad_token")
    end
  end

  describe "get/2" do
    test "gets webhook details", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/settings/webhooks/webhook-123", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "id" => "webhook-123",
            "url" => "https://example.com/hook",
            "watched" => [
              %{"type" => "model", "name" => "bert-base-uncased"},
              %{"type" => "dataset", "name" => "squad"}
            ],
            "domains" => ["repo", "discussion"],
            "secret" => "my-secret",
            "disabled" => false,
            "createdAt" => "2025-01-15T10:00:00Z"
          })
        )
      end)

      assert {:ok, webhook} = Webhooks.get("webhook-123", token: "test_token")
      assert %WebhookInfo{id: "webhook-123", url: "https://example.com/hook"} = webhook
      assert webhook.secret == "my-secret"
      assert length(webhook.watched) == 2

      [item1, item2] = webhook.watched
      assert %WatchedItem{type: :model, name: "bert-base-uncased"} = item1
      assert %WatchedItem{type: :dataset, name: "squad"} = item2
    end

    test "handles 404 not found", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/settings/webhooks/missing", fn conn ->
        Plug.Conn.resp(conn, 404, "")
      end)

      assert {:error, :not_found} = Webhooks.get("missing", token: "test_token")
    end
  end

  describe "create/2" do
    test "creates webhook for single repo", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/settings/webhooks", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["url"] == "https://example.com/hook"
        assert params["watched"] == [%{"type" => "model", "name" => "bert-base-uncased"}]
        assert params["domains"] == ["repo"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "id" => "new-webhook",
            "url" => "https://example.com/hook",
            "watched" => [%{"type" => "model", "name" => "bert-base-uncased"}],
            "domains" => ["repo"],
            "disabled" => false
          })
        )
      end)

      assert {:ok, webhook} =
               Webhooks.create("https://example.com/hook",
                 watched: [{:model, "bert-base-uncased"}],
                 domains: [:repo],
                 token: "test_token"
               )

      assert webhook.id == "new-webhook"
      assert webhook.url == "https://example.com/hook"
    end

    test "creates webhook for multiple repos", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/settings/webhooks", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert length(params["watched"]) == 2
        assert params["domains"] == ["repo", "discussion"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "id" => "multi-webhook",
            "url" => "https://example.com/hook",
            "watched" => [
              %{"type" => "model", "name" => "bert-base-uncased"},
              %{"type" => "dataset", "name" => "squad"}
            ],
            "domains" => ["repo", "discussion"]
          })
        )
      end)

      assert {:ok, webhook} =
               Webhooks.create("https://example.com/hook",
                 watched: [{:model, "bert-base-uncased"}, {:dataset, "squad"}],
                 domains: [:repo, :discussion],
                 token: "test_token"
               )

      assert length(webhook.watched) == 2
    end

    test "creates webhook with secret", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/settings/webhooks", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["secret"] == "my-secret"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "id" => "secret-webhook",
            "url" => "https://example.com/hook",
            "watched" => [],
            "domains" => ["repo"],
            "secret" => "my-secret"
          })
        )
      end)

      assert {:ok, webhook} =
               Webhooks.create("https://example.com/hook",
                 watched: [],
                 domains: [:repo],
                 secret: "my-secret",
                 token: "test_token"
               )

      assert webhook.secret == "my-secret"
    end

    test "handles 401 unauthorized", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/settings/webhooks", fn conn ->
        Plug.Conn.resp(conn, 401, "")
      end)

      assert {:error, :unauthorized} =
               Webhooks.create("https://example.com/hook",
                 watched: [],
                 token: "bad_token"
               )
    end

    test "handles validation errors", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/settings/webhooks", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(422, Jason.encode!(%{"error" => "Invalid URL"}))
      end)

      assert {:error, {:validation, _}} =
               Webhooks.create("not-a-url",
                 watched: [],
                 token: "test_token"
               )
    end
  end

  describe "update/2" do
    test "updates webhook URL", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PATCH", "/api/settings/webhooks/webhook-123", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["url"] == "https://new-url.com/hook"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "id" => "webhook-123",
            "url" => "https://new-url.com/hook",
            "watched" => [],
            "domains" => ["repo"]
          })
        )
      end)

      assert {:ok, webhook} =
               Webhooks.update("webhook-123",
                 url: "https://new-url.com/hook",
                 token: "test_token"
               )

      assert webhook.url == "https://new-url.com/hook"
    end

    test "updates watched repos", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PATCH", "/api/settings/webhooks/webhook-123", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["watched"] == [%{"type" => "model", "name" => "gpt2"}]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "id" => "webhook-123",
            "url" => "https://example.com/hook",
            "watched" => [%{"type" => "model", "name" => "gpt2"}],
            "domains" => ["repo"]
          })
        )
      end)

      assert {:ok, webhook} =
               Webhooks.update("webhook-123",
                 watched: [{:model, "gpt2"}],
                 token: "test_token"
               )

      assert length(webhook.watched) == 1
      assert hd(webhook.watched).name == "gpt2"
    end

    test "updates domains", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PATCH", "/api/settings/webhooks/webhook-123", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["domains"] == ["discussion"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "id" => "webhook-123",
            "url" => "https://example.com/hook",
            "watched" => [],
            "domains" => ["discussion"]
          })
        )
      end)

      assert {:ok, webhook} =
               Webhooks.update("webhook-123",
                 domains: [:discussion],
                 token: "test_token"
               )

      assert webhook.domains == [:discussion]
    end

    test "updates secret", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PATCH", "/api/settings/webhooks/webhook-123", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["secret"] == "new-secret"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "id" => "webhook-123",
            "url" => "https://example.com/hook",
            "watched" => [],
            "domains" => ["repo"],
            "secret" => "new-secret"
          })
        )
      end)

      assert {:ok, webhook} =
               Webhooks.update("webhook-123",
                 secret: "new-secret",
                 token: "test_token"
               )

      assert webhook.secret == "new-secret"
    end

    test "handles 404 not found", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PATCH", "/api/settings/webhooks/missing", fn conn ->
        Plug.Conn.resp(conn, 404, "")
      end)

      assert {:error, :not_found} =
               Webhooks.update("missing",
                 url: "https://new-url.com/hook",
                 token: "test_token"
               )
    end
  end

  describe "enable/2" do
    test "enables a disabled webhook", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/settings/webhooks/webhook-123/enable", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "id" => "webhook-123",
            "url" => "https://example.com/hook",
            "watched" => [],
            "domains" => ["repo"],
            "disabled" => false
          })
        )
      end)

      assert {:ok, webhook} = Webhooks.enable("webhook-123", token: "test_token")
      refute webhook.disabled
    end

    test "handles 404 not found", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/settings/webhooks/missing/enable", fn conn ->
        Plug.Conn.resp(conn, 404, "")
      end)

      assert {:error, :not_found} = Webhooks.enable("missing", token: "test_token")
    end

    test "handles 401 unauthorized", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/settings/webhooks/webhook-123/enable", fn conn ->
        Plug.Conn.resp(conn, 401, "")
      end)

      assert {:error, :unauthorized} = Webhooks.enable("webhook-123", token: "bad_token")
    end
  end

  describe "disable/2" do
    test "disables an enabled webhook", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/settings/webhooks/webhook-123/disable", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "id" => "webhook-123",
            "url" => "https://example.com/hook",
            "watched" => [],
            "domains" => ["repo"],
            "disabled" => true
          })
        )
      end)

      assert {:ok, webhook} = Webhooks.disable("webhook-123", token: "test_token")
      assert webhook.disabled
    end

    test "handles 404 not found", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/settings/webhooks/missing/disable", fn conn ->
        Plug.Conn.resp(conn, 404, "")
      end)

      assert {:error, :not_found} = Webhooks.disable("missing", token: "test_token")
    end

    test "handles 401 unauthorized", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/settings/webhooks/webhook-123/disable", fn conn ->
        Plug.Conn.resp(conn, 401, "")
      end)

      assert {:error, :unauthorized} = Webhooks.disable("webhook-123", token: "bad_token")
    end
  end

  describe "delete/2" do
    test "deletes a webhook", %{bypass: bypass} do
      Bypass.expect_once(bypass, "DELETE", "/api/settings/webhooks/webhook-123", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      assert :ok = Webhooks.delete("webhook-123", token: "test_token")
    end

    test "handles missing_ok when webhook doesn't exist", %{bypass: bypass} do
      Bypass.expect_once(bypass, "DELETE", "/api/settings/webhooks/missing", fn conn ->
        Plug.Conn.resp(conn, 404, "")
      end)

      assert :ok = Webhooks.delete("missing", missing_ok: true, token: "test_token")
    end

    test "returns error when webhook doesn't exist without missing_ok", %{bypass: bypass} do
      Bypass.expect_once(bypass, "DELETE", "/api/settings/webhooks/missing", fn conn ->
        Plug.Conn.resp(conn, 404, "")
      end)

      assert {:error, :not_found} = Webhooks.delete("missing", token: "test_token")
    end

    test "handles 401 unauthorized", %{bypass: bypass} do
      Bypass.expect_once(bypass, "DELETE", "/api/settings/webhooks/webhook-123", fn conn ->
        Plug.Conn.resp(conn, 401, "")
      end)

      assert {:error, :unauthorized} = Webhooks.delete("webhook-123", token: "bad_token")
    end
  end
end
