defmodule HfHub.ChecksumTest do
  use ExUnit.Case, async: false

  setup do
    bypass = Bypass.open()
    Application.put_env(:hf_hub, :endpoint, "http://localhost:#{bypass.port}")

    # Create a temp cache dir for tests
    cache_dir = Path.join(System.tmp_dir!(), "hf_hub_checksum_test_#{:rand.uniform(1_000_000)}")
    File.mkdir_p!(cache_dir)
    Application.put_env(:hf_hub, :cache_dir, cache_dir)

    on_exit(fn ->
      Application.delete_env(:hf_hub, :endpoint)
      Application.delete_env(:hf_hub, :cache_dir)
      File.rm_rf!(cache_dir)
    end)

    {:ok, bypass: bypass, cache_dir: cache_dir}
  end

  describe "compute_sha256/1" do
    test "computes correct SHA256 for file" do
      # Create a test file
      content = "hello world"
      path = Path.join(System.tmp_dir!(), "sha256_test_#{:rand.uniform(1_000_000)}.txt")
      File.write!(path, content)

      on_exit(fn -> File.rm(path) end)

      {:ok, hash} = HfHub.Download.compute_sha256(path)

      # SHA256 of "hello world" is known
      expected = "b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9"
      assert hash == expected
    end

    test "returns lowercase hex-encoded hash" do
      content = "TEST"
      path = Path.join(System.tmp_dir!(), "sha256_case_test_#{:rand.uniform(1_000_000)}.txt")
      File.write!(path, content)

      on_exit(fn -> File.rm(path) end)

      {:ok, hash} = HfHub.Download.compute_sha256(path)

      # Hash should be all lowercase
      assert hash == String.downcase(hash)
      # Hash should be 64 characters (256 bits = 32 bytes = 64 hex chars)
      assert String.length(hash) == 64
    end

    test "returns error for non-existent file" do
      result = HfHub.Download.compute_sha256("/nonexistent/path/file.txt")
      assert {:error, {:sha256_failed, _}} = result
    end
  end

  describe "verify_checksum option" do
    test "download succeeds with verify_checksum: true and no expected hash", %{bypass: bypass} do
      content = "test content for checksum"

      Bypass.expect_once(bypass, "GET", "/test-repo/resolve/main/file.txt", fn conn ->
        Plug.Conn.resp(conn, 200, content)
      end)

      {:ok, path} =
        HfHub.Download.hf_hub_download(
          repo_id: "test-repo",
          filename: "file.txt",
          verify_checksum: true
        )

      assert File.exists?(path)
      assert File.read!(path) == content
    end

    test "download succeeds with correct expected_sha256", %{bypass: bypass} do
      content = "hello world"
      # SHA256 of "hello world"
      expected_hash = "b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9"

      Bypass.expect_once(bypass, "GET", "/test-repo/resolve/main/verified.txt", fn conn ->
        Plug.Conn.resp(conn, 200, content)
      end)

      {:ok, path} =
        HfHub.Download.hf_hub_download(
          repo_id: "test-repo",
          filename: "verified.txt",
          expected_sha256: expected_hash
        )

      assert File.exists?(path)
      assert File.read!(path) == content
    end

    test "download fails with incorrect expected_sha256", %{bypass: bypass} do
      content = "actual content"
      # Wrong hash (SHA256 of "different content")
      wrong_hash = "0000000000000000000000000000000000000000000000000000000000000000"

      Bypass.expect_once(bypass, "GET", "/test-repo/resolve/main/mismatch.txt", fn conn ->
        Plug.Conn.resp(conn, 200, content)
      end)

      result =
        HfHub.Download.hf_hub_download(
          repo_id: "test-repo",
          filename: "mismatch.txt",
          expected_sha256: wrong_hash
        )

      assert {:error, {:checksum_mismatch, ^wrong_hash, actual}} = result
      # Verify the actual hash is correct for the content
      expected_actual = compute_sha256_of_string(content)
      assert actual == expected_actual
    end

    test "cached file is verified when expected_sha256 provided", %{bypass: bypass} do
      content = "cached content"
      correct_hash = compute_sha256_of_string(content)
      wrong_hash = "0000000000000000000000000000000000000000000000000000000000000000"

      # First, download and cache the file
      Bypass.expect_once(bypass, "GET", "/test-repo/resolve/main/cached.txt", fn conn ->
        Plug.Conn.resp(conn, 200, content)
      end)

      {:ok, path1} =
        HfHub.Download.hf_hub_download(
          repo_id: "test-repo",
          filename: "cached.txt"
        )

      assert File.exists?(path1)

      # Now try to load from cache with correct hash - should succeed
      {:ok, path2} =
        HfHub.Download.hf_hub_download(
          repo_id: "test-repo",
          filename: "cached.txt",
          expected_sha256: correct_hash
        )

      assert path1 == path2

      # Try to load from cache with wrong hash - should fail
      result =
        HfHub.Download.hf_hub_download(
          repo_id: "test-repo",
          filename: "cached.txt",
          expected_sha256: wrong_hash
        )

      assert {:error, {:checksum_mismatch, ^wrong_hash, _actual}} = result
    end

    test "verify_checksum without expected_sha256 computes hash but doesn't fail", %{
      bypass: bypass
    } do
      content = "any content"

      Bypass.expect_once(bypass, "GET", "/test-repo/resolve/main/noexpect.txt", fn conn ->
        Plug.Conn.resp(conn, 200, content)
      end)

      # This should succeed - we compute hash but don't verify against anything
      {:ok, path} =
        HfHub.Download.hf_hub_download(
          repo_id: "test-repo",
          filename: "noexpect.txt",
          verify_checksum: true
        )

      assert File.exists?(path)
    end
  end

  # Helper to compute SHA256 of a string
  defp compute_sha256_of_string(content) do
    :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
  end
end
