defmodule HfHub.OrganizationsTest do
  use ExUnit.Case, async: false

  alias HfHub.Organizations
  alias HfHub.Users.{Organization, User}

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
    test "returns organization profile", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/organizations/huggingface", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "name" => "huggingface",
            "fullname" => "Hugging Face",
            "avatarUrl" => "https://example.com/hf.jpg",
            "details" => "AI community building the future",
            "numMembers" => 500,
            "numModels" => 1000,
            "numDatasets" => 200,
            "numSpaces" => 300
          })
        )
      end)

      assert {:ok, %Organization{} = org} = Organizations.get("huggingface")
      assert org.name == "huggingface"
      assert org.fullname == "Hugging Face"
      assert org.avatar_url == "https://example.com/hf.jpg"
      assert org.details == "AI community building the future"
      assert org.num_members == 500
      assert org.num_models == 1000
      assert org.num_datasets == 200
      assert org.num_spaces == 300
    end

    test "handles organization not found", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/organizations/nonexistent", fn conn ->
        Plug.Conn.resp(conn, 404, "Not Found")
      end)

      assert {:error, :not_found} = Organizations.get("nonexistent")
    end

    test "handles private organization without access", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/organizations/private-org", fn conn ->
        Plug.Conn.resp(conn, 403, "Forbidden")
      end)

      assert {:error, :forbidden} = Organizations.get("private-org")
    end
  end

  describe "list_members/2" do
    test "returns list of organization members", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/organizations/huggingface/members", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!([
            %{"user" => "julien-c", "fullname" => "Julien Chaumond"},
            %{"user" => "lysandre", "fullname" => "Lysandre Debut"}
          ])
        )
      end)

      assert {:ok, members} = Organizations.list_members("huggingface")
      assert length(members) == 2
      assert [%User{username: "julien-c"}, %User{username: "lysandre"}] = members
    end

    test "handles organization not found", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/api/organizations/nonexistent/members", fn conn ->
        Plug.Conn.resp(conn, 404, "Not Found")
      end)

      assert {:error, :not_found} = Organizations.list_members("nonexistent")
    end
  end
end
