defmodule HfHub.UsersTest do
  use ExUnit.Case, async: false

  alias HfHub.Users
  alias HfHub.Users.User

  setup do
    bypass = Bypass.open()
    original_endpoint = Application.get_env(:hf_hub, :endpoint)
    Application.put_env(:hf_hub, :endpoint, "http://localhost:#{bypass.port}")

    on_exit(fn ->
      if original_endpoint do
        Application.put_env(:hf_hub, :endpoint, original_endpoint)
      else
        Application.delete_env(:hf_hub, :endpoint)
      end
    end)

    {:ok, bypass: bypass}
  end

  describe "get/2" do
    test "returns user profile", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/users/testuser", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "user" => "testuser",
            "fullname" => "Test User",
            "avatarUrl" => "https://example.com/avatar.jpg",
            "numFollowers" => 100,
            "numFollowing" => 50,
            "numModels" => 10,
            "numDatasets" => 5,
            "numSpaces" => 3,
            "numLikes" => 25
          })
        )
      end)

      assert {:ok, %User{} = user} = Users.get("testuser")
      assert user.username == "testuser"
      assert user.fullname == "Test User"
      assert user.avatar_url == "https://example.com/avatar.jpg"
      assert user.num_followers == 100
      assert user.num_following == 50
      assert user.num_models == 10
      assert user.num_datasets == 5
      assert user.num_spaces == 3
      assert user.num_likes == 25
    end

    test "handles user not found", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/users/nonexistent", fn conn ->
        Plug.Conn.resp(conn, 404, "Not Found")
      end)

      assert {:error, :not_found} = Users.get("nonexistent")
    end
  end

  describe "list_followers/2" do
    test "returns list of followers", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/users/testuser/followers", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!([
            %{"user" => "follower1", "fullname" => "Follower One"},
            %{"user" => "follower2", "fullname" => "Follower Two"}
          ])
        )
      end)

      assert {:ok, followers} = Users.list_followers("testuser")
      assert length(followers) == 2
      assert [%User{username: "follower1"}, %User{username: "follower2"}] = followers
    end
  end

  describe "list_following/2" do
    test "returns list of users being followed", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/users/testuser/following", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!([
            %{"user" => "following1", "fullname" => "Following One"}
          ])
        )
      end)

      assert {:ok, following} = Users.list_following("testuser")
      assert length(following) == 1
      assert [%User{username: "following1"}] = following
    end
  end

  describe "list_liked_repos/2" do
    test "returns list of liked repositories with likes key", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/users/testuser/likes", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "likes" => [
              %{"repoId" => "user/model1"},
              %{"repoId" => "user/model2"}
            ]
          })
        )
      end)

      assert {:ok, likes} = Users.list_liked_repos("testuser")
      assert length(likes) == 2
    end

    test "returns list of liked repositories as array", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/users/testuser/likes", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!([
            %{"repoId" => "user/model1"}
          ])
        )
      end)

      assert {:ok, likes} = Users.list_liked_repos("testuser")
      assert length(likes) == 1
    end
  end

  describe "like/2" do
    test "likes a model repository", %{bypass: bypass} do
      # repo_id "user/model" is URL-encoded to "user%2Fmodel"
      Bypass.expect_once(bypass, "POST", "/api/models/user%2Fmodel/like", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{}))
      end)

      assert :ok = Users.like("user/model", token: "test_token")
    end

    test "likes a dataset repository", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/api/datasets/user%2Fdataset/like", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(%{}))
      end)

      assert :ok = Users.like("user/dataset", token: "test_token", repo_type: :dataset)
    end
  end

  describe "unlike/2" do
    test "unlikes a repository", %{bypass: bypass} do
      Bypass.expect_once(bypass, "DELETE", "/api/models/user%2Fmodel/like", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      assert :ok = Users.unlike("user/model", token: "test_token")
    end
  end

  describe "list_likers/2" do
    test "returns list of users who liked a repo", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/models/bert-base-uncased/likers", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!([
            %{"user" => "liker1"},
            %{"user" => "liker2"}
          ])
        )
      end)

      assert {:ok, likers} = Users.list_likers("bert-base-uncased")
      assert length(likers) == 2
      assert [%User{username: "liker1"}, %User{username: "liker2"}] = likers
    end
  end
end
