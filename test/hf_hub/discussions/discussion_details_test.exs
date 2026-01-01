defmodule HfHub.Discussions.DiscussionDetailsTest do
  use ExUnit.Case, async: true

  alias HfHub.Discussions.{Comment, DiscussionDetails, StatusChange, TitleChange}

  describe "from_response/1" do
    test "parses complete response" do
      response = %{
        "num" => 42,
        "title" => "Feature Discussion",
        "author" => "testuser",
        "status" => "open",
        "isPullRequest" => false,
        "createdAt" => "2025-01-15T10:00:00Z",
        "updatedAt" => "2025-01-15T12:00:00Z",
        "events" => [],
        "targetBranch" => nil,
        "headSha" => nil,
        "mergeCommitOid" => nil
      }

      details = DiscussionDetails.from_response(response)

      assert details.num == 42
      assert details.title == "Feature Discussion"
      assert details.author == "testuser"
      assert details.status == :open
      refute details.is_pull_request
      assert %DateTime{} = details.created_at
      assert %DateTime{} = details.updated_at
      assert details.events == []
    end

    test "parses pull request with PR-specific fields" do
      response = %{
        "num" => 10,
        "title" => "Add feature",
        "author" => "contributor",
        "status" => "draft",
        "isPullRequest" => true,
        "targetBranch" => "main",
        "headSha" => "abc123def456",
        "mergeCommitOid" => nil,
        "events" => []
      }

      details = DiscussionDetails.from_response(response)

      assert details.is_pull_request
      assert details.target_branch == "main"
      assert details.head_sha == "abc123def456"
      assert is_nil(details.merge_commit_oid)
    end

    test "parses merged PR" do
      response = %{
        "num" => 10,
        "status" => "merged",
        "isPullRequest" => true,
        "mergeCommitOid" => "merge123",
        "events" => []
      }

      details = DiscussionDetails.from_response(response)
      assert details.status == :merged
      assert details.merge_commit_oid == "merge123"
    end

    test "parses comment events" do
      response = %{
        "num" => 1,
        "events" => [
          %{
            "type" => "comment",
            "id" => "c1",
            "author" => "user1",
            "content" => "First comment",
            "createdAt" => "2025-01-15T10:00:00Z"
          },
          %{
            "type" => "comment",
            "id" => "c2",
            "author" => "user2",
            "content" => "Second comment",
            "createdAt" => "2025-01-15T11:00:00Z"
          }
        ]
      }

      details = DiscussionDetails.from_response(response)
      assert length(details.events) == 2
      assert Enum.all?(details.events, &match?(%Comment{}, &1))

      [first, second] = details.events
      assert first.id == "c1"
      assert first.content == "First comment"
      assert second.id == "c2"
    end

    test "parses status change events" do
      response = %{
        "num" => 1,
        "events" => [
          %{
            "type" => "status-change",
            "id" => "s1",
            "author" => "admin",
            "newStatus" => "closed",
            "comment" => "Fixed",
            "createdAt" => "2025-01-15T10:00:00Z"
          }
        ]
      }

      details = DiscussionDetails.from_response(response)
      assert length(details.events) == 1

      [event] = details.events
      assert %StatusChange{} = event
      assert event.status == :closed
      assert event.comment == "Fixed"
    end

    test "parses title change events" do
      response = %{
        "num" => 1,
        "events" => [
          %{
            "type" => "title-change",
            "id" => "t1",
            "author" => "user",
            "oldTitle" => "Old Title",
            "newTitle" => "New Title",
            "createdAt" => "2025-01-15T10:00:00Z"
          }
        ]
      }

      details = DiscussionDetails.from_response(response)
      assert length(details.events) == 1

      [event] = details.events
      assert %TitleChange{} = event
      assert event.old_title == "Old Title"
      assert event.new_title == "New Title"
    end

    test "parses mixed event types" do
      response = %{
        "num" => 1,
        "events" => [
          %{"type" => "comment", "id" => "c1", "content" => "Comment"},
          %{"type" => "status-change", "id" => "s1", "newStatus" => "closed"},
          %{"type" => "title-change", "id" => "t1", "oldTitle" => "Old", "newTitle" => "New"},
          %{"type" => "comment", "id" => "c2", "content" => "Another comment"}
        ]
      }

      details = DiscussionDetails.from_response(response)
      assert length(details.events) == 4

      [c1, s1, t1, c2] = details.events
      assert %Comment{id: "c1"} = c1
      assert %StatusChange{id: "s1"} = s1
      assert %TitleChange{id: "t1"} = t1
      assert %Comment{id: "c2"} = c2
    end

    test "falls back to comment for events with content but no type" do
      response = %{
        "num" => 1,
        "events" => [
          %{
            "id" => "unknown",
            "author" => "user",
            "content" => "Some content"
          }
        ]
      }

      details = DiscussionDetails.from_response(response)
      [event] = details.events
      assert %Comment{} = event
      assert event.content == "Some content"
    end

    test "handles nil events" do
      response = %{
        "num" => 1,
        "events" => nil
      }

      details = DiscussionDetails.from_response(response)
      assert details.events == []
    end

    test "handles missing events key" do
      response = %{"num" => 1}

      details = DiscussionDetails.from_response(response)
      assert details.events == []
    end
  end

  describe "JSON encoding" do
    test "struct is JSON encodable" do
      details = %DiscussionDetails{
        num: 1,
        title: "Test",
        author: "user",
        status: :open,
        is_pull_request: false,
        events: []
      }

      assert {:ok, json} = Jason.encode(details)
      assert json =~ "\"num\":1"
      assert json =~ "\"title\":\"Test\""
    end

    test "encodes events properly" do
      details = %DiscussionDetails{
        num: 1,
        title: "Test",
        author: "user",
        status: :open,
        is_pull_request: false,
        events: [
          %Comment{id: "c1", author: "a", content: "text", hidden: false, edited: false}
        ]
      }

      assert {:ok, json} = Jason.encode(details)
      assert json =~ "\"events\":"
      assert json =~ "\"id\":\"c1\""
    end
  end
end
