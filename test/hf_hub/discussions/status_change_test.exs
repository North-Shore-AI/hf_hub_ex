defmodule HfHub.Discussions.StatusChangeTest do
  use ExUnit.Case, async: true

  alias HfHub.Discussions.StatusChange

  describe "from_response/1" do
    test "parses complete response" do
      response = %{
        "id" => "status-123",
        "author" => "admin",
        "status" => "closed",
        "comment" => "Resolved",
        "createdAt" => "2025-01-15T10:00:00Z"
      }

      status_change = StatusChange.from_response(response)

      assert status_change.id == "status-123"
      assert status_change.author == "admin"
      assert status_change.status == :closed
      assert status_change.comment == "Resolved"
      assert %DateTime{} = status_change.created_at
    end

    test "handles newStatus key variant" do
      response = %{
        "id" => "1",
        "newStatus" => "merged"
      }

      status_change = StatusChange.from_response(response)
      assert status_change.status == :merged
    end

    test "handles all status values" do
      for {status_str, status_atom} <- [
            {"open", :open},
            {"closed", :closed},
            {"merged", :merged}
          ] do
        response = %{"id" => "1", "status" => status_str}
        status_change = StatusChange.from_response(response)
        assert status_change.status == status_atom
      end
    end

    test "defaults unknown status to :open" do
      response = %{"id" => "1", "status" => "unknown"}
      status_change = StatusChange.from_response(response)
      assert status_change.status == :open
    end

    test "handles nil comment" do
      response = %{
        "id" => "1",
        "status" => "closed",
        "comment" => nil
      }

      status_change = StatusChange.from_response(response)
      assert is_nil(status_change.comment)
    end
  end

  describe "JSON encoding" do
    test "struct is JSON encodable" do
      status_change = %StatusChange{
        id: "status-1",
        author: "admin",
        status: :closed,
        comment: "Done"
      }

      assert {:ok, json} = Jason.encode(status_change)
      assert json =~ "\"id\":\"status-1\""
      assert json =~ "\"status\":\"closed\""
    end
  end
end
