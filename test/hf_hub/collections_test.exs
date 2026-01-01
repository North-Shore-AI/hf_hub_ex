defmodule HfHub.CollectionsTest do
  use ExUnit.Case, async: false

  alias HfHub.Collections
  alias HfHub.Collections.{Collection, CollectionItem}

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
    test "lists all collections", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/collections", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "collections" => [
              %{
                "slug" => "user/llm-collection-abc123",
                "title" => "Best LLMs",
                "description" => "Curated LLMs",
                "owner" => %{"name" => "user"},
                "private" => false,
                "upvotes" => 42,
                "createdAt" => "2025-01-15T10:00:00Z",
                "updatedAt" => "2025-01-15T12:00:00Z",
                "items" => []
              },
              %{
                "slug" => "org/datasets-xyz789",
                "title" => "Top Datasets",
                "owner" => "org",
                "private" => true,
                "upvotes" => 10,
                "items" => []
              }
            ]
          })
        )
      end)

      assert {:ok, collections} = Collections.list()
      assert length(collections) == 2

      [first, second] = collections
      assert %Collection{slug: "user/llm-collection-abc123", title: "Best LLMs"} = first
      assert first.description == "Curated LLMs"
      assert first.owner == "user"
      assert first.upvotes == 42
      refute first.private

      assert %Collection{slug: "org/datasets-xyz789", private: true} = second
      assert second.owner == "org"
    end

    test "handles list response format (without wrapper)", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/collections", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!([
            %{"slug" => "user/collection-1", "title" => "Collection 1", "items" => []}
          ])
        )
      end)

      assert {:ok, [collection]} = Collections.list()
      assert collection.slug == "user/collection-1"
    end

    test "filters by owner", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/collections", fn conn ->
        assert conn.query_string =~ "owner=huggingface"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"collections" => []}))
      end)

      assert {:ok, []} = Collections.list(owner: "huggingface")
    end

    test "filters by item", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/collections", fn conn ->
        assert conn.query_string =~ "item=bert-base-uncased"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"collections" => []}))
      end)

      assert {:ok, []} = Collections.list(item: "bert-base-uncased")
    end

    test "sorts by trending", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/collections", fn conn ->
        assert conn.query_string =~ "sort=trending"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"collections" => []}))
      end)

      assert {:ok, []} = Collections.list(sort: :trending)
    end

    test "sorts by upvotes", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/collections", fn conn ->
        assert conn.query_string =~ "sort=upvotes"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"collections" => []}))
      end)

      assert {:ok, []} = Collections.list(sort: :upvotes)
    end

    test "sorts by last modified", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/collections", fn conn ->
        assert conn.query_string =~ "sort=lastModified"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{"collections" => []}))
      end)

      assert {:ok, []} = Collections.list(sort: :last_modified)
    end

    test "handles 404 error", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/collections", fn conn ->
        Plug.Conn.resp(conn, 404, "")
      end)

      assert {:error, :not_found} = Collections.list()
    end
  end

  describe "get/2" do
    test "gets collection details with items", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/collections/user%2Fmy-collection-abc123", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "slug" => "user/my-collection-abc123",
            "title" => "My Collection",
            "description" => "A great collection",
            "owner" => %{"name" => "user"},
            "private" => false,
            "upvotes" => 100,
            "createdAt" => "2025-01-10T08:00:00Z",
            "updatedAt" => "2025-01-15T10:00:00Z",
            "theme" => "dark",
            "items" => [
              %{
                "_id" => "item-1",
                "itemId" => "bert-base-uncased",
                "itemType" => "model",
                "note" => "Best BERT model",
                "position" => 0,
                "addedAt" => "2025-01-10T09:00:00Z"
              },
              %{
                "_id" => "item-2",
                "itemId" => "squad",
                "itemType" => "dataset",
                "position" => 1
              }
            ]
          })
        )
      end)

      assert {:ok, collection} = Collections.get("user/my-collection-abc123")
      assert %Collection{slug: "user/my-collection-abc123", title: "My Collection"} = collection
      assert collection.description == "A great collection"
      assert collection.theme == "dark"
      assert collection.upvotes == 100
      assert length(collection.items) == 2

      [item1, item2] = collection.items
      assert %CollectionItem{id: "item-1", item_id: "bert-base-uncased", item_type: :model} = item1
      assert item1.note == "Best BERT model"
      assert item1.position == 0

      assert %CollectionItem{id: "item-2", item_id: "squad", item_type: :dataset} = item2
    end

    test "handles 404 error", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/collections/user%2Fmissing", fn conn ->
        Plug.Conn.resp(conn, 404, "")
      end)

      assert {:error, :not_found} = Collections.get("user/missing")
    end

    test "handles 403 for private collection", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/collections/user%2Fprivate", fn conn ->
        Plug.Conn.resp(conn, 403, "")
      end)

      assert {:error, :forbidden} = Collections.get("user/private")
    end
  end

  describe "create/2" do
    test "creates a public collection", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/collections", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["title"] == "My New Collection"
        assert params["description"] == "A description"
        assert params["private"] == false

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "slug" => "user/my-new-collection-xyz",
            "title" => "My New Collection",
            "description" => "A description",
            "owner" => "user",
            "private" => false,
            "items" => []
          })
        )
      end)

      assert {:ok, collection} =
               Collections.create("My New Collection",
                 description: "A description",
                 token: "test_token"
               )

      assert collection.slug == "user/my-new-collection-xyz"
      assert collection.title == "My New Collection"
    end

    test "creates a private collection", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/collections", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["private"] == true

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "slug" => "user/private-collection",
            "title" => "Private",
            "private" => true,
            "items" => []
          })
        )
      end)

      assert {:ok, collection} =
               Collections.create("Private", private: true, token: "test_token")

      assert collection.private
    end

    test "creates with namespace", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/collections", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["namespace"] == "my-org"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "slug" => "my-org/org-collection",
            "title" => "Org Collection",
            "owner" => "my-org",
            "items" => []
          })
        )
      end)

      assert {:ok, collection} =
               Collections.create("Org Collection", namespace: "my-org", token: "test_token")

      assert collection.owner == "my-org"
    end

    test "handles exists_ok when collection already exists", %{bypass: bypass} do
      Bypass.expect(bypass, "POST", "/api/collections", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(409, Jason.encode!(%{"error" => "Collection already exists"}))
      end)

      Bypass.expect(bypass, "GET", "/api/collections", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "collections" => [
              %{
                "slug" => "user/existing-collection",
                "title" => "Existing Collection",
                "items" => []
              }
            ]
          })
        )
      end)

      assert {:ok, collection} =
               Collections.create("Existing Collection", exists_ok: true, token: "test_token")

      assert collection.title == "Existing Collection"
    end

    test "requires authentication", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/collections", fn conn ->
        Plug.Conn.resp(conn, 401, "")
      end)

      assert {:error, :unauthorized} = Collections.create("Test", token: "bad_token")
    end
  end

  describe "update/2" do
    test "updates title and description", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "PATCH",
        "/api/collections/user%2Fmy-collection-123",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          params = Jason.decode!(body)

          assert params["title"] == "Updated Title"
          assert params["description"] == "Updated description"

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!(%{
              "slug" => "user/my-collection-123",
              "title" => "Updated Title",
              "description" => "Updated description",
              "items" => []
            })
          )
        end
      )

      assert {:ok, collection} =
               Collections.update("user/my-collection-123",
                 title: "Updated Title",
                 description: "Updated description",
                 token: "test_token"
               )

      assert collection.title == "Updated Title"
      assert collection.description == "Updated description"
    end

    test "changes visibility", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "PATCH",
        "/api/collections/user%2Fmy-collection-123",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          params = Jason.decode!(body)

          assert params["private"] == true

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!(%{
              "slug" => "user/my-collection-123",
              "title" => "Test",
              "private" => true,
              "items" => []
            })
          )
        end
      )

      assert {:ok, collection} =
               Collections.update("user/my-collection-123", private: true, token: "test_token")

      assert collection.private
    end

    test "updates position and theme", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "PATCH",
        "/api/collections/user%2Fmy-collection-123",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          params = Jason.decode!(body)

          assert params["position"] == 5
          assert params["theme"] == "dark"

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!(%{
              "slug" => "user/my-collection-123",
              "title" => "Test",
              "position" => 5,
              "theme" => "dark",
              "items" => []
            })
          )
        end
      )

      assert {:ok, collection} =
               Collections.update("user/my-collection-123",
                 position: 5,
                 theme: "dark",
                 token: "test_token"
               )

      assert collection.position == 5
      assert collection.theme == "dark"
    end

    test "handles 404 error", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PATCH", "/api/collections/user%2Fmissing", fn conn ->
        Plug.Conn.resp(conn, 404, "")
      end)

      assert {:error, :not_found} =
               Collections.update("user/missing", title: "New", token: "test_token")
    end
  end

  describe "delete/2" do
    test "deletes a collection", %{bypass: bypass} do
      Bypass.expect_once(bypass, "DELETE", "/api/collections/user%2Fmy-collection-123", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      assert :ok = Collections.delete("user/my-collection-123", token: "test_token")
    end

    test "handles missing_ok when collection doesn't exist", %{bypass: bypass} do
      Bypass.expect_once(bypass, "DELETE", "/api/collections/user%2Fmissing", fn conn ->
        Plug.Conn.resp(conn, 404, "")
      end)

      assert :ok = Collections.delete("user/missing", missing_ok: true, token: "test_token")
    end

    test "returns error when collection doesn't exist without missing_ok", %{bypass: bypass} do
      Bypass.expect_once(bypass, "DELETE", "/api/collections/user%2Fmissing", fn conn ->
        Plug.Conn.resp(conn, 404, "")
      end)

      assert {:error, :not_found} = Collections.delete("user/missing", token: "test_token")
    end

    test "requires authentication", %{bypass: bypass} do
      Bypass.expect_once(bypass, "DELETE", "/api/collections/user%2Fcollection", fn conn ->
        Plug.Conn.resp(conn, 401, "")
      end)

      assert {:error, :unauthorized} = Collections.delete("user/collection", token: "bad_token")
    end
  end

  describe "add_item/4" do
    test "adds a model to collection", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/collections/user%2Fmy-collection-123/items",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          params = Jason.decode!(body)

          assert params["itemId"] == "bert-base-uncased"
          assert params["itemType"] == "model"
          assert params["note"] == "Best BERT model"

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!(%{
              "_id" => "new-item-id",
              "itemId" => "bert-base-uncased",
              "itemType" => "model",
              "note" => "Best BERT model",
              "position" => 0,
              "addedAt" => "2025-01-15T10:00:00Z"
            })
          )
        end
      )

      assert {:ok, item} =
               Collections.add_item(
                 "user/my-collection-123",
                 "bert-base-uncased",
                 :model,
                 note: "Best BERT model",
                 token: "test_token"
               )

      assert %CollectionItem{id: "new-item-id", item_id: "bert-base-uncased", item_type: :model} =
               item

      assert item.note == "Best BERT model"
    end

    test "adds a dataset to collection", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/collections/user%2Fmy-collection-123/items",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          params = Jason.decode!(body)

          assert params["itemType"] == "dataset"

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!(%{
              "_id" => "dataset-item",
              "itemId" => "squad",
              "itemType" => "dataset",
              "position" => 1
            })
          )
        end
      )

      assert {:ok, item} =
               Collections.add_item("user/my-collection-123", "squad", :dataset,
                 token: "test_token"
               )

      assert item.item_type == :dataset
    end

    test "adds a space to collection", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/collections/user%2Fmy-collection-123/items",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          params = Jason.decode!(body)

          assert params["itemType"] == "space"

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!(%{
              "_id" => "space-item",
              "itemId" => "gradio/demo",
              "itemType" => "space",
              "position" => 2
            })
          )
        end
      )

      assert {:ok, item} =
               Collections.add_item("user/my-collection-123", "gradio/demo", :space,
                 token: "test_token"
               )

      assert item.item_type == :space
    end

    test "adds a paper to collection", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/collections/user%2Fmy-collection-123/items",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          params = Jason.decode!(body)

          assert params["itemType"] == "paper"

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!(%{
              "_id" => "paper-item",
              "itemId" => "2301.12345",
              "itemType" => "paper",
              "position" => 3
            })
          )
        end
      )

      assert {:ok, item} =
               Collections.add_item("user/my-collection-123", "2301.12345", :paper,
                 token: "test_token"
               )

      assert item.item_type == :paper
    end

    test "handles exists_ok when item already in collection", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/collections/user%2Fmy-collection-123/items",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(409, Jason.encode!(%{"error" => "Item already in collection"}))
        end
      )

      assert {:ok, nil} =
               Collections.add_item("user/my-collection-123", "bert-base-uncased", :model,
                 exists_ok: true,
                 token: "test_token"
               )
    end

    test "returns error for duplicate item without exists_ok", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/collections/user%2Fmy-collection-123/items",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(409, Jason.encode!(%{"error" => "Item already in collection"}))
        end
      )

      assert {:error, {:conflict, _}} =
               Collections.add_item("user/my-collection-123", "bert-base-uncased", :model,
                 token: "test_token"
               )
    end

    test "requires authentication", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/api/collections/user%2Fcollection/items",
        fn conn ->
          Plug.Conn.resp(conn, 401, "")
        end
      )

      assert {:error, :unauthorized} =
               Collections.add_item("user/collection", "model", :model, token: "bad_token")
    end
  end

  describe "update_item/3" do
    test "updates item note", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "PATCH",
        "/api/collections/user%2Fmy-collection-123/items/item-abc",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          params = Jason.decode!(body)

          assert params["note"] == "Updated note"

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!(%{
              "_id" => "item-abc",
              "itemId" => "bert-base-uncased",
              "itemType" => "model",
              "note" => "Updated note",
              "position" => 0
            })
          )
        end
      )

      assert {:ok, item} =
               Collections.update_item("user/my-collection-123", "item-abc",
                 note: "Updated note",
                 token: "test_token"
               )

      assert item.note == "Updated note"
    end

    test "reorders item position", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "PATCH",
        "/api/collections/user%2Fmy-collection-123/items/item-abc",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          params = Jason.decode!(body)

          assert params["position"] == 5

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!(%{
              "_id" => "item-abc",
              "itemId" => "bert-base-uncased",
              "itemType" => "model",
              "position" => 5
            })
          )
        end
      )

      assert {:ok, item} =
               Collections.update_item("user/my-collection-123", "item-abc",
                 position: 5,
                 token: "test_token"
               )

      assert item.position == 5
    end

    test "handles 404 error", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "PATCH",
        "/api/collections/user%2Fmy-collection/items/missing",
        fn conn ->
          Plug.Conn.resp(conn, 404, "")
        end
      )

      assert {:error, :not_found} =
               Collections.update_item("user/my-collection", "missing",
                 note: "Test",
                 token: "test_token"
               )
    end
  end

  describe "delete_item/3" do
    test "removes item from collection", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "DELETE",
        "/api/collections/user%2Fmy-collection-123/items/item-abc",
        fn conn ->
          Plug.Conn.resp(conn, 204, "")
        end
      )

      assert :ok =
               Collections.delete_item("user/my-collection-123", "item-abc", token: "test_token")
    end

    test "handles missing_ok when item doesn't exist", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "DELETE",
        "/api/collections/user%2Fmy-collection/items/missing",
        fn conn ->
          Plug.Conn.resp(conn, 404, "")
        end
      )

      assert :ok =
               Collections.delete_item("user/my-collection", "missing",
                 missing_ok: true,
                 token: "test_token"
               )
    end

    test "returns error when item doesn't exist without missing_ok", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "DELETE",
        "/api/collections/user%2Fmy-collection/items/missing",
        fn conn ->
          Plug.Conn.resp(conn, 404, "")
        end
      )

      assert {:error, :not_found} =
               Collections.delete_item("user/my-collection", "missing", token: "test_token")
    end

    test "requires authentication", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "DELETE",
        "/api/collections/user%2Fcollection/items/item",
        fn conn ->
          Plug.Conn.resp(conn, 401, "")
        end
      )

      assert {:error, :unauthorized} =
               Collections.delete_item("user/collection", "item", token: "bad_token")
    end
  end
end
