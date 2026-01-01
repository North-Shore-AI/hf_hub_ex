defmodule HfHub.Discussions.TitleChangeTest do
  use ExUnit.Case, async: true

  alias HfHub.Discussions.TitleChange

  describe "from_response/1" do
    test "parses complete response" do
      response = %{
        "id" => "title-123",
        "author" => "user",
        "oldTitle" => "Old Title",
        "newTitle" => "New Title",
        "createdAt" => "2025-01-15T10:00:00Z"
      }

      title_change = TitleChange.from_response(response)

      assert title_change.id == "title-123"
      assert title_change.author == "user"
      assert title_change.old_title == "Old Title"
      assert title_change.new_title == "New Title"
      assert %DateTime{} = title_change.created_at
    end

    test "handles nil datetime" do
      response = %{
        "id" => "1",
        "oldTitle" => "Old",
        "newTitle" => "New",
        "createdAt" => nil
      }

      title_change = TitleChange.from_response(response)
      assert is_nil(title_change.created_at)
    end
  end

  describe "JSON encoding" do
    test "struct is JSON encodable" do
      title_change = %TitleChange{
        id: "title-1",
        author: "user",
        old_title: "Old",
        new_title: "New"
      }

      assert {:ok, json} = Jason.encode(title_change)
      assert json =~ "\"id\":\"title-1\""
      assert json =~ "\"old_title\":\"Old\""
      assert json =~ "\"new_title\":\"New\""
    end
  end
end
