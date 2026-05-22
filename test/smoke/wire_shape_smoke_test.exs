defmodule HfHub.WireShapeSmokeTest do
  use ExUnit.Case, async: false

  alias HfHub.Commit
  alias HfHub.Commit.Operation

  setup do
    bypass = Bypass.open()
    Application.put_env(:hf_hub, :endpoint, "http://localhost:#{bypass.port}")
    on_exit(fn -> Application.delete_env(:hf_hub, :endpoint) end)
    {:ok, bypass: bypass}
  end

  test "create/3 sends one header line + one operation per line of NDJSON",
       %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/api/datasets/org/dataset/commit/main", fn conn ->
      [ct | _] = Plug.Conn.get_req_header(conn, "content-type")
      assert ct =~ "application/x-ndjson"

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      lines = String.split(body, "\n", trim: true)
      items = Enum.map(lines, &Jason.decode!/1)

      assert [header | ops] = items
      assert header["key"] == "header"
      assert header["value"]["summary"] == "smoke"
      assert header["value"]["description"] == "wire-shape smoke"

      assert [
               %{"key" => "file", "value" => %{"path" => "manifest.json", "encoding" => "base64"}},
               %{"key" => "file", "value" => %{"path" => "data/train.txt"}},
               %{"key" => "deletedFile", "value" => %{"path" => "old.bin"}}
             ] = ops

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(
        200,
        Jason.encode!(%{
          "commitUrl" => "https://huggingface.co/datasets/org/dataset/commit/abc",
          "commitOid" => "abc",
          "commitMessage" => "smoke",
          "repoUrl" => "https://huggingface.co/datasets/org/dataset"
        })
      )
    end)

    assert {:ok, _info} =
             Commit.create(
               "org/dataset",
               [
                 Operation.add("manifest.json", ~s({"hello": "world"})),
                 Operation.add("data/train.txt", "tiny\n"),
                 Operation.delete("old.bin")
               ],
               token: "hf_smoke",
               repo_type: :dataset,
               commit_message: "smoke",
               commit_description: "wire-shape smoke"
             )
  end
end
