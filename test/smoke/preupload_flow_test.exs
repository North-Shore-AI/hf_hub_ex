defmodule HfHub.PreuploadFlowTest do
  # End-to-end smoke: prove `Commit.create/3` consults `/preupload` and uses
  # the server's verdict instead of the local size threshold. This is the
  # regression armor for the "Your push was rejected because it contains
  # binary files" Hub error caused by sending an LFS-tracked `.safetensors`
  # under 10MB as a base64 regular blob.
  use ExUnit.Case, async: false

  alias HfHub.Commit
  alias HfHub.Commit.Operation

  setup do
    bypass = Bypass.open()
    original = Application.get_env(:hf_hub, :endpoint)
    Application.put_env(:hf_hub, :endpoint, "http://localhost:#{bypass.port}")

    on_exit(fn ->
      if original do
        Application.put_env(:hf_hub, :endpoint, original)
      else
        Application.delete_env(:hf_hub, :endpoint)
      end
    end)

    {:ok, bypass: bypass}
  end

  test "small .safetensors flagged as :lfs by the Hub travels as lfsFile",
       %{bypass: bypass} do
    repo_id = "org/dataset"
    small_safetensors_path = "checkpoints/0002_query.kernel.safetensors"
    json_path = "manifest.json"

    # 1. /preupload — small safetensors -> lfs (because .gitattributes
    # tracks the extension), manifest.json -> regular.
    Bypass.expect_once(
      bypass,
      "POST",
      "/api/datasets/#{repo_id}/preupload/main",
      fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        payload = Jason.decode!(body)

        # Sanity: the request body matches the canonical Python shape.
        paths = payload["files"] |> Enum.map(& &1["path"]) |> Enum.sort()
        assert paths == [json_path, small_safetensors_path] |> Enum.sort()

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "files" => [
              %{
                "path" => small_safetensors_path,
                "uploadMode" => "lfs",
                "shouldIgnore" => false,
                "oid" => nil
              },
              %{
                "path" => json_path,
                "uploadMode" => "regular",
                "shouldIgnore" => false,
                "oid" => nil
              }
            ]
          })
        )
      end
    )

    # 2. LFS batch — the small safetensors must be requested as LFS.
    Bypass.expect_once(
      bypass,
      "POST",
      "/datasets/#{repo_id}.git/info/lfs/objects/batch",
      fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        payload = Jason.decode!(body)

        assert payload["operation"] == "upload"
        assert [%{"size" => 16}] = payload["objects"]

        # Tell the client the LFS object is already on the server (no
        # `actions` => skip upload).
        conn
        |> Plug.Conn.put_resp_content_type("application/vnd.git-lfs+json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "transfer" => "basic",
            "objects" => [
              %{
                "oid" =>
                  :crypto.hash(:sha256, String.duplicate("x", 16))
                  |> Base.encode16(case: :lower),
                "size" => 16,
                "actions" => %{}
              }
            ]
          })
        )
      end
    )

    # 3. /commit — must contain both an lfsFile and a file entry.
    Bypass.expect_once(
      bypass,
      "POST",
      "/api/datasets/#{repo_id}/commit/main",
      fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)

        items =
          body
          |> String.split("\n", trim: true)
          |> Enum.map(&Jason.decode!/1)

        [header | ops] = items
        assert header["key"] == "header"

        assert [
                 %{
                   "key" => "lfsFile",
                   "value" => %{"path" => ^small_safetensors_path, "algo" => "sha256"}
                 },
                 %{"key" => "file", "value" => %{"path" => ^json_path, "encoding" => "base64"}}
               ] = ops

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "commitUrl" => "https://huggingface.co/datasets/#{repo_id}/commit/abc",
            "commitOid" => "abc",
            "commitMessage" => "preupload smoke",
            "repoUrl" => "https://huggingface.co/datasets/#{repo_id}"
          })
        )
      end
    )

    assert {:ok, _info} =
             Commit.create(
               repo_id,
               [
                 Operation.add(small_safetensors_path, String.duplicate("x", 16)),
                 Operation.add(json_path, ~s({"hello":"world"}))
               ],
               token: "hf_smoke",
               repo_type: :dataset,
               commit_message: "preupload smoke"
             )
  end
end
