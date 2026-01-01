defmodule HfHub.Discussions.CommentTest do
  use ExUnit.Case, async: true

  alias HfHub.Discussions.Comment

  describe "from_response/1" do
    test "parses complete response" do
      response = %{
        "id" => "comment-123",
        "author" => "testuser",
        "content" => "This is a comment",
        "hidden" => false,
        "createdAt" => "2025-01-15T10:00:00Z",
        "updatedAt" => "2025-01-15T12:00:00Z",
        "edited" => true
      }

      comment = Comment.from_response(response)

      assert comment.id == "comment-123"
      assert comment.author == "testuser"
      assert comment.content == "This is a comment"
      refute comment.hidden
      assert %DateTime{} = comment.created_at
      assert %DateTime{} = comment.updated_at
      assert comment.edited
    end

    test "defaults hidden to false" do
      response = %{"id" => "1"}
      comment = Comment.from_response(response)
      refute comment.hidden
    end

    test "defaults edited to false" do
      response = %{"id" => "1"}
      comment = Comment.from_response(response)
      refute comment.edited
    end

    test "handles nil datetime fields" do
      response = %{
        "id" => "1",
        "createdAt" => nil,
        "updatedAt" => nil
      }

      comment = Comment.from_response(response)
      assert is_nil(comment.created_at)
      assert is_nil(comment.updated_at)
    end
  end

  describe "JSON encoding" do
    test "struct is JSON encodable" do
      comment = %Comment{
        id: "comment-1",
        author: "user",
        content: "Test content",
        hidden: false,
        edited: false
      }

      assert {:ok, json} = Jason.encode(comment)
      assert json =~ "\"id\":\"comment-1\""
      assert json =~ "\"content\":\"Test content\""
    end
  end
end
