defmodule HfHub.ProgressTest do
  use ExUnit.Case, async: false

  setup do
    bypass = Bypass.open()
    Application.put_env(:hf_hub, :endpoint, "http://localhost:#{bypass.port}")

    # Create a temp cache dir for tests
    cache_dir = Path.join(System.tmp_dir!(), "hf_hub_progress_test_#{:rand.uniform(1_000_000)}")
    File.mkdir_p!(cache_dir)
    Application.put_env(:hf_hub, :cache_dir, cache_dir)

    on_exit(fn ->
      Application.delete_env(:hf_hub, :endpoint)
      Application.delete_env(:hf_hub, :cache_dir)
      File.rm_rf!(cache_dir)
    end)

    {:ok, bypass: bypass, cache_dir: cache_dir}
  end

  describe "progress_callback" do
    test "callback receives increasing byte counts", %{bypass: bypass} do
      content = String.duplicate("x", 1000)

      Bypass.expect_once(bypass, "GET", "/test-repo/resolve/main/file.bin", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-length", "1000")
        |> Plug.Conn.resp(200, content)
      end)

      {:ok, agent} = Agent.start_link(fn -> [] end)

      {:ok, _path} =
        HfHub.Download.hf_hub_download(
          repo_id: "test-repo",
          filename: "file.bin",
          progress_callback: fn downloaded, total ->
            Agent.update(agent, fn calls -> [{downloaded, total} | calls] end)
          end
        )

      calls = Agent.get(agent, & &1) |> Enum.reverse()
      Agent.stop(agent)

      # Should have at least one call
      refute Enum.empty?(calls)

      # All calls should have total = 1000
      assert Enum.all?(calls, fn {_, total} -> total == 1000 end)

      # Downloaded bytes should be increasing
      downloaded_values = Enum.map(calls, fn {downloaded, _} -> downloaded end)
      assert downloaded_values == Enum.sort(downloaded_values)

      # Last call should have all bytes downloaded
      {final_downloaded, _} = List.last(calls)
      assert final_downloaded == 1000
    end

    test "callback receives correct total from Content-Length", %{bypass: bypass} do
      content = "hello world"

      Bypass.expect_once(bypass, "GET", "/test-repo/resolve/main/file.txt", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-length", "#{byte_size(content)}")
        |> Plug.Conn.resp(200, content)
      end)

      {:ok, agent} = Agent.start_link(fn -> [] end)

      {:ok, _path} =
        HfHub.Download.hf_hub_download(
          repo_id: "test-repo",
          filename: "file.txt",
          progress_callback: fn downloaded, total ->
            Agent.update(agent, fn calls -> [{downloaded, total} | calls] end)
          end
        )

      calls = Agent.get(agent, & &1)
      Agent.stop(agent)

      # All totals should be 11 (byte_size of "hello world")
      assert Enum.all?(calls, fn {_, total} -> total == 11 end)
    end

    test "download succeeds even if callback raises", %{bypass: bypass} do
      content = "test content"

      Bypass.expect_once(bypass, "GET", "/test-repo/resolve/main/file.txt", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-length", "#{byte_size(content)}")
        |> Plug.Conn.resp(200, content)
      end)

      # Callback that always raises
      {:ok, path} =
        HfHub.Download.hf_hub_download(
          repo_id: "test-repo",
          filename: "file.txt",
          progress_callback: fn _downloaded, _total ->
            raise "Intentional error"
          end
        )

      # Download should still succeed
      assert File.exists?(path)
      assert File.read!(path) == content
    end

    test "download succeeds even if callback throws", %{bypass: bypass} do
      content = "test content"

      Bypass.expect_once(bypass, "GET", "/test-repo/resolve/main/file2.txt", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-length", "#{byte_size(content)}")
        |> Plug.Conn.resp(200, content)
      end)

      # Callback that always throws
      {:ok, path} =
        HfHub.Download.hf_hub_download(
          repo_id: "test-repo",
          filename: "file2.txt",
          progress_callback: fn _downloaded, _total ->
            throw(:intentional_throw)
          end
        )

      # Download should still succeed
      assert File.exists?(path)
      assert File.read!(path) == content
    end

    test "works with larger files", %{bypass: bypass} do
      # 100KB file
      content = String.duplicate("x", 100_000)

      Bypass.expect_once(bypass, "GET", "/test-repo/resolve/main/large.bin", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-length", "100000")
        |> Plug.Conn.resp(200, content)
      end)

      {:ok, agent} = Agent.start_link(fn -> [] end)

      {:ok, path} =
        HfHub.Download.hf_hub_download(
          repo_id: "test-repo",
          filename: "large.bin",
          progress_callback: fn downloaded, total ->
            Agent.update(agent, fn calls -> [{downloaded, total} | calls] end)
          end
        )

      calls = Agent.get(agent, & &1) |> Enum.reverse()
      Agent.stop(agent)

      # Verify file was downloaded correctly
      assert File.exists?(path)
      assert File.stat!(path).size == 100_000

      # Should have at least one progress call
      refute Enum.empty?(calls)

      # Final call should show all bytes downloaded
      {final_downloaded, final_total} = List.last(calls)
      assert final_downloaded == 100_000
      assert final_total == 100_000
    end

    test "download without callback works normally", %{bypass: bypass} do
      content = "simple content"

      Bypass.expect_once(bypass, "GET", "/test-repo/resolve/main/simple.txt", fn conn ->
        Plug.Conn.resp(conn, 200, content)
      end)

      {:ok, path} =
        HfHub.Download.hf_hub_download(
          repo_id: "test-repo",
          filename: "simple.txt"
        )

      assert File.exists?(path)
      assert File.read!(path) == content
    end
  end
end
