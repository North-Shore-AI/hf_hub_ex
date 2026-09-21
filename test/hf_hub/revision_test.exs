defmodule HfHub.RevisionTest do
  use ExUnit.Case, async: false

  alias HfHub.Revision

  @commit "0123456789abcdef0123456789abcdef01234567"

  setup do
    bypass = Bypass.open()

    cache_dir =
      Path.join(
        System.tmp_dir!(),
        "hf_hub_revision_test_#{System.unique_integer([:positive])}"
      )

    Application.put_env(:hf_hub, :endpoint, "http://localhost:#{bypass.port}")
    Application.put_env(:hf_hub, :cache_dir, cache_dir)
    Application.delete_env(:hf_hub, :offline)

    on_exit(fn ->
      Application.delete_env(:hf_hub, :endpoint)
      Application.delete_env(:hf_hub, :cache_dir)
      Application.delete_env(:hf_hub, :offline)
      File.rm_rf!(cache_dir)
    end)

    {:ok, bypass: bypass}
  end

  test "full commit hashes are already resolved without network access" do
    assert {:ok,
            %Revision{
              repo_id: "org/model",
              repo_type: :model,
              requested: @commit,
              resolved: @commit
            }} = Revision.resolve("org/model", revision: @commit)
  end

  test "resolves a mutable model revision and caches its ref", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/api/models/org/model", fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.query_params["revision"] == "main"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, Jason.encode!(%{id: "org/model", sha: @commit}))
    end)

    assert {:ok, %Revision{requested: "main", resolved: @commit}} =
             Revision.resolve("org/model", revision: "main")

    assert {:ok, @commit} = HfHub.FS.read_ref("org/model", :model, "main")
  end

  test "resolves cached refs without network access" do
    assert :ok = HfHub.FS.write_ref("org/model", :model, "release/v1", @commit)

    assert {:ok, %Revision{requested: "release/v1", resolved: @commit}} =
             Revision.resolve("org/model", revision: "release/v1", local_files_only: true)
  end

  test "offline mode uses cached refs" do
    assert :ok = HfHub.FS.write_ref("org/model", :model, "main", @commit)
    Application.put_env(:hf_hub, :offline, true)

    assert {:ok, %Revision{resolved: @commit}} = Revision.resolve("org/model", revision: "main")
  end

  test "cache-only resolution reports a missing ref" do
    assert {:error, {:revision_not_cached, "missing"}} =
             Revision.resolve("org/model", revision: "missing", local_files_only: true)
  end

  test "rejects a Hub response without a full commit hash", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/api/models/org/model", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, Jason.encode!(%{id: "org/model", sha: "abc123"}))
    end)

    assert {:error, {:invalid_resolved_revision, "abc123"}} =
             Revision.resolve("org/model", revision: "main")
  end
end
