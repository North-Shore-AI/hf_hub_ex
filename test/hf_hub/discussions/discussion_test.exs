defmodule HfHub.Discussions.DiscussionTest do
  use ExUnit.Case, async: true

  alias HfHub.Discussions.Discussion

  describe "from_response/1" do
    test "parses complete response" do
      response = %{
        "num" => 42,
        "title" => "Bug report",
        "author" => "testuser",
        "status" => "open",
        "isPullRequest" => false,
        "createdAt" => "2025-01-15T10:00:00Z",
        "updatedAt" => "2025-01-15T12:00:00Z",
        "numComments" => 5
      }

      discussion = Discussion.from_response(response)

      assert discussion.num == 42
      assert discussion.title == "Bug report"
      assert discussion.author == "testuser"
      assert discussion.status == :open
      refute discussion.is_pull_request
      assert %DateTime{} = discussion.created_at
      assert %DateTime{} = discussion.updated_at
      assert discussion.num_comments == 5
    end

    test "handles is_pull_request key variant" do
      response = %{
        "num" => 1,
        "is_pull_request" => true
      }

      discussion = Discussion.from_response(response)
      assert discussion.is_pull_request
    end

    test "handles all status values" do
      for {status_str, status_atom} <- [
            {"open", :open},
            {"closed", :closed},
            {"merged", :merged},
            {"draft", :draft}
          ] do
        response = %{"num" => 1, "status" => status_str}
        discussion = Discussion.from_response(response)
        assert discussion.status == status_atom
      end
    end

    test "defaults unknown status to :open" do
      response = %{"num" => 1, "status" => "unknown"}
      discussion = Discussion.from_response(response)
      assert discussion.status == :open
    end

    test "defaults numComments to 0" do
      response = %{"num" => 1}
      discussion = Discussion.from_response(response)
      assert discussion.num_comments == 0
    end

    test "defaults is_pull_request to false" do
      response = %{"num" => 1}
      discussion = Discussion.from_response(response)
      refute discussion.is_pull_request
    end

    test "handles nil datetime fields" do
      response = %{
        "num" => 1,
        "createdAt" => nil,
        "updatedAt" => nil
      }

      discussion = Discussion.from_response(response)
      assert is_nil(discussion.created_at)
      assert is_nil(discussion.updated_at)
    end

    test "handles malformed datetime" do
      response = %{
        "num" => 1,
        "createdAt" => "not a date"
      }

      discussion = Discussion.from_response(response)
      assert is_nil(discussion.created_at)
    end
  end

  describe "JSON encoding" do
    test "struct is JSON encodable" do
      discussion = %Discussion{
        num: 1,
        title: "Test",
        author: "user",
        status: :open,
        is_pull_request: false,
        num_comments: 0
      }

      assert {:ok, json} = Jason.encode(discussion)
      assert json =~ "\"num\":1"
      assert json =~ "\"title\":\"Test\""
    end
  end
end
