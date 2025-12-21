defmodule HfHub.CacheTest do
  use ExUnit.Case, async: false

  setup do
    # Create a temp cache dir for tests
    cache_dir = Path.join(System.tmp_dir!(), "hf_hub_cache_test_#{:rand.uniform(1_000_000)}")
    hub_dir = Path.join(cache_dir, "hub")
    File.mkdir_p!(hub_dir)
    Application.put_env(:hf_hub, :cache_dir, cache_dir)

    on_exit(fn ->
      Application.delete_env(:hf_hub, :cache_dir)
      File.rm_rf!(cache_dir)
    end)

    {:ok, cache_dir: cache_dir, hub_dir: hub_dir}
  end

  describe "cached?/1" do
    test "returns false when file doesn't exist" do
      refute HfHub.Cache.cached?(
               repo_id: "test-repo",
               filename: "missing.txt",
               repo_type: :model
             )
    end

    test "returns true when file exists", %{cache_dir: cache_dir} do
      # Create a cached file
      file_path =
        Path.join([cache_dir, "hub", "models--test-repo", "snapshots", "main", "config.json"])

      File.mkdir_p!(Path.dirname(file_path))
      File.write!(file_path, "{}")

      assert HfHub.Cache.cached?(
               repo_id: "test-repo",
               filename: "config.json",
               repo_type: :model
             )
    end
  end

  describe "cache_path/1" do
    test "returns error when file not cached" do
      assert {:error, :not_cached} =
               HfHub.Cache.cache_path(
                 repo_id: "test-repo",
                 filename: "missing.txt"
               )
    end

    test "returns path when file is cached", %{cache_dir: cache_dir} do
      file_path =
        Path.join([cache_dir, "hub", "models--test-repo", "snapshots", "main", "data.bin"])

      File.mkdir_p!(Path.dirname(file_path))
      File.write!(file_path, "data")

      assert {:ok, path} =
               HfHub.Cache.cache_path(
                 repo_id: "test-repo",
                 filename: "data.bin",
                 repo_type: :model
               )

      assert path == file_path
    end
  end

  describe "clear_cache/1" do
    test "clears specific repo cache", %{cache_dir: cache_dir} do
      # Create files for two repos
      repo1_path = Path.join([cache_dir, "hub", "models--repo1", "snapshots", "main", "file.txt"])
      repo2_path = Path.join([cache_dir, "hub", "models--repo2", "snapshots", "main", "file.txt"])

      File.mkdir_p!(Path.dirname(repo1_path))
      File.mkdir_p!(Path.dirname(repo2_path))
      File.write!(repo1_path, "repo1")
      File.write!(repo2_path, "repo2")

      :ok = HfHub.Cache.clear_cache(repo_id: "repo1", repo_type: :model)

      refute File.exists?(repo1_path)
      assert File.exists?(repo2_path)
    end

    test "clears all cache when no repo specified", %{cache_dir: _cache_dir, hub_dir: hub_dir} do
      # Create files
      file_path = Path.join([hub_dir, "models--test", "snapshots", "main", "file.txt"])
      File.mkdir_p!(Path.dirname(file_path))
      File.write!(file_path, "data")

      :ok = HfHub.Cache.clear_cache()

      refute File.exists?(hub_dir)
    end
  end

  describe "evict_lru/1" do
    test "evicts files older than max_age", %{hub_dir: hub_dir} do
      # Create some files
      old_file = Path.join(hub_dir, "old_file.txt")
      new_file = Path.join(hub_dir, "new_file.txt")

      File.write!(old_file, "old data")
      File.write!(new_file, "new data")

      # Wait to ensure files are at least 1 second old (atime uses integer seconds)
      Process.sleep(1100)

      # Evict files older than 0 seconds
      :ok = HfHub.Cache.evict_lru(max_age: 0)

      refute File.exists?(old_file)
      refute File.exists?(new_file)
    end

    test "evicts files to reach target_size", %{hub_dir: hub_dir} do
      # Create files totaling more than target size
      file1 = Path.join(hub_dir, "file1.bin")
      file2 = Path.join(hub_dir, "file2.bin")
      file3 = Path.join(hub_dir, "file3.bin")

      File.write!(file1, String.duplicate("a", 1000))
      Process.sleep(10)
      File.write!(file2, String.duplicate("b", 1000))
      Process.sleep(10)
      File.write!(file3, String.duplicate("c", 1000))

      # Target size of 1500 bytes - should evict oldest files
      :ok = HfHub.Cache.evict_lru(target_size: 1500)

      # At least one file should be evicted
      remaining =
        [file1, file2, file3]
        |> Enum.filter(&File.exists?/1)

      total_size =
        remaining
        |> Enum.map(&File.stat!/1)
        |> Enum.map(& &1.size)
        |> Enum.sum()

      assert total_size <= 1500
    end

    test "does nothing when cache is empty", %{hub_dir: hub_dir} do
      File.rm_rf!(hub_dir)
      assert :ok = HfHub.Cache.evict_lru(target_size: 1000)
    end

    test "does nothing when under target_size", %{hub_dir: hub_dir} do
      file = Path.join(hub_dir, "small.txt")
      File.write!(file, "small")

      :ok = HfHub.Cache.evict_lru(target_size: 1_000_000)

      assert File.exists?(file)
    end
  end

  describe "validate_integrity/0" do
    test "reports files with valid checksums", %{hub_dir: hub_dir} do
      file_path = Path.join(hub_dir, "valid.txt")
      checksum_path = file_path <> ".sha256"

      content = "test content"
      File.write!(file_path, content)

      # Compute SHA256
      hash =
        :crypto.hash(:sha256, content)
        |> Base.encode16(case: :lower)

      File.write!(checksum_path, hash)

      {:ok, report} = HfHub.Cache.validate_integrity()

      assert report.total_files == 1
      assert report.valid_files == 1
      assert report.corrupted_files == 0
    end

    test "reports files with invalid checksums", %{hub_dir: hub_dir} do
      file_path = Path.join(hub_dir, "corrupted.txt")
      checksum_path = file_path <> ".sha256"

      File.write!(file_path, "actual content")
      File.write!(checksum_path, "0000000000000000000000000000000000000000000000000000000000000000")

      {:ok, report} = HfHub.Cache.validate_integrity()

      assert report.total_files == 1
      assert report.valid_files == 0
      assert report.corrupted_files == 1
    end

    test "reports files with missing checksums", %{hub_dir: hub_dir} do
      file_path = Path.join(hub_dir, "no_checksum.txt")
      File.write!(file_path, "content without checksum")

      {:ok, report} = HfHub.Cache.validate_integrity()

      assert report.total_files == 1
      assert report.missing_checksum == 1
    end

    test "handles empty cache", %{hub_dir: hub_dir} do
      File.rm_rf!(hub_dir)
      File.mkdir_p!(hub_dir)

      {:ok, report} = HfHub.Cache.validate_integrity()

      assert report.total_files == 0
      assert report.valid_files == 0
      assert report.corrupted_files == 0
    end

    test "provides detailed results", %{hub_dir: hub_dir} do
      # Create a mix of files
      valid_file = Path.join(hub_dir, "valid.bin")
      corrupted_file = Path.join(hub_dir, "corrupted.bin")
      no_checksum_file = Path.join(hub_dir, "nochecksum.bin")

      # Valid file
      File.write!(valid_file, "valid")
      valid_hash = :crypto.hash(:sha256, "valid") |> Base.encode16(case: :lower)
      File.write!(valid_file <> ".sha256", valid_hash)

      # Corrupted file
      File.write!(corrupted_file, "actual")

      File.write!(
        corrupted_file <> ".sha256",
        "bad_hash_000000000000000000000000000000000000000000000000"
      )

      # File without checksum
      File.write!(no_checksum_file, "no checksum")

      {:ok, report} = HfHub.Cache.validate_integrity()

      assert report.total_files == 3
      assert report.valid_files == 1
      assert report.corrupted_files == 1
      assert report.missing_checksum == 1
      assert length(report.details) == 3
    end
  end
end
