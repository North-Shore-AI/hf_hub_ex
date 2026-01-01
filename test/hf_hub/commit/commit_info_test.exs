defmodule HfHub.Commit.CommitInfoTest do
  use ExUnit.Case, async: true

  alias HfHub.Commit.CommitInfo

  describe "from_response/1" do
    test "parses complete response" do
      response = %{
        "commitUrl" => "https://huggingface.co/user/repo/commit/abc123",
        "commitMessage" => "Update model",
        "commitDescription" => "Added new weights",
        "commitOid" => "abc123def456",
        "repoUrl" => "https://huggingface.co/user/repo"
      }

      info = CommitInfo.from_response(response)

      assert info.commit_url == "https://huggingface.co/user/repo/commit/abc123"
      assert info.commit_message == "Update model"
      assert info.commit_description == "Added new weights"
      assert info.oid == "abc123def456"
      assert info.repo_url == "https://huggingface.co/user/repo"
      assert info.pr_url == nil
      assert info.pr_num == nil
      assert info.pr_revision == nil
    end

    test "parses response with PR info" do
      response = %{
        "commitUrl" => "https://huggingface.co/user/repo/commit/abc123",
        "commitMessage" => "Update model",
        "commitOid" => "abc123",
        "repoUrl" => "https://huggingface.co/user/repo",
        "pullRequest" => %{
          "url" => "https://huggingface.co/user/repo/discussions/42",
          "num" => 42,
          "revision" => "refs/pr/42"
        }
      }

      info = CommitInfo.from_response(response)

      assert info.pr_url == "https://huggingface.co/user/repo/discussions/42"
      assert info.pr_num == 42
      assert info.pr_revision == "refs/pr/42"
    end

    test "parses minimal response" do
      response = %{
        "commitUrl" => "https://huggingface.co/user/repo/commit/abc",
        "commitMessage" => "Commit",
        "commitOid" => "abc",
        "repoUrl" => "https://huggingface.co/user/repo"
      }

      info = CommitInfo.from_response(response)

      assert info.commit_url == "https://huggingface.co/user/repo/commit/abc"
      assert info.commit_message == "Commit"
      assert info.commit_description == nil
      assert info.pr_url == nil
    end

    test "handles missing pullRequest gracefully" do
      response = %{
        "commitUrl" => "https://huggingface.co/user/repo/commit/abc",
        "commitMessage" => "Commit",
        "commitOid" => "abc",
        "repoUrl" => "https://huggingface.co/user/repo",
        "pullRequest" => nil
      }

      info = CommitInfo.from_response(response)

      assert info.pr_url == nil
      assert info.pr_num == nil
      assert info.pr_revision == nil
    end
  end

  describe "struct" do
    test "derives Jason.Encoder" do
      info = %CommitInfo{
        commit_url: "https://example.com/commit/abc",
        commit_message: "Test commit",
        commit_description: nil,
        oid: "abc123",
        pr_url: nil,
        pr_num: nil,
        pr_revision: nil,
        repo_url: "https://example.com/repo"
      }

      assert {:ok, json} = Jason.encode(info)
      assert json =~ "commit_url"
      assert json =~ "abc123"
    end
  end
end
