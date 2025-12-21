defmodule HfHub.FSTest do
  use ExUnit.Case, async: true

  setup do
    # Use a temporary directory for testing
    temp_dir = Path.join(System.tmp_dir!(), "hf_hub_test_#{:rand.uniform(1_000_000)}")

    Application.put_env(:hf_hub, :cache_dir, temp_dir)

    on_exit(fn ->
      File.rm_rf(temp_dir)
      Application.delete_env(:hf_hub, :cache_dir)
    end)

    {:ok, cache_dir: temp_dir}
  end

  describe "cache_dir/0" do
    test "returns configured cache directory", %{cache_dir: temp_dir} do
      assert HfHub.FS.cache_dir() == temp_dir
    end
  end

  describe "ensure_cache_dir/0" do
    test "creates cache directory if it doesn't exist", %{cache_dir: temp_dir} do
      # Directory shouldn't exist yet
      refute File.exists?(temp_dir)

      assert :ok = HfHub.FS.ensure_cache_dir()
      assert File.exists?(temp_dir)
      assert File.dir?(temp_dir)
    end

    test "succeeds if cache directory already exists", %{cache_dir: temp_dir} do
      File.mkdir_p!(temp_dir)

      assert :ok = HfHub.FS.ensure_cache_dir()
      assert File.exists?(temp_dir)
    end
  end

  describe "repo_path/2" do
    test "constructs path for model repository", %{cache_dir: temp_dir} do
      path = HfHub.FS.repo_path("bert-base-uncased", :model)
      expected = Path.join([temp_dir, "hub", "models--bert-base-uncased"])
      assert path == expected
    end

    test "constructs path for dataset repository", %{cache_dir: temp_dir} do
      path = HfHub.FS.repo_path("squad", :dataset)
      expected = Path.join([temp_dir, "hub", "datasets--squad"])
      assert path == expected
    end

    test "handles repo IDs with slashes", %{cache_dir: temp_dir} do
      path = HfHub.FS.repo_path("openai/gpt-2", :model)
      expected = Path.join([temp_dir, "hub", "models--openai--gpt-2"])
      assert path == expected
    end

    test "constructs path for space repository", %{cache_dir: temp_dir} do
      path = HfHub.FS.repo_path("user/space-name", :space)
      expected = Path.join([temp_dir, "hub", "spaces--user--space-name"])
      assert path == expected
    end
  end

  describe "file_path/4" do
    test "constructs path for file in model repository", %{cache_dir: temp_dir} do
      path = HfHub.FS.file_path("bert-base-uncased", :model, "config.json")

      expected =
        Path.join([
          temp_dir,
          "hub",
          "models--bert-base-uncased",
          "snapshots",
          "main",
          "config.json"
        ])

      assert path == expected
    end

    test "constructs path with custom revision", %{cache_dir: temp_dir} do
      path = HfHub.FS.file_path("bert-base-uncased", :model, "config.json", "v1.0")

      expected =
        Path.join([
          temp_dir,
          "hub",
          "models--bert-base-uncased",
          "snapshots",
          "v1.0",
          "config.json"
        ])

      assert path == expected
    end

    test "handles nested file paths", %{cache_dir: temp_dir} do
      path = HfHub.FS.file_path("openai/gpt-2", :model, "models/pytorch_model.bin")

      expected =
        Path.join([
          temp_dir,
          "hub",
          "models--openai--gpt-2",
          "snapshots",
          "main",
          "models/pytorch_model.bin"
        ])

      assert path == expected
    end
  end

  describe "lock_file/2 and unlock_file/1" do
    test "acquires and releases lock successfully", %{cache_dir: _temp_dir} do
      assert {:ok, lock} = HfHub.FS.lock_file("test-repo", "test-file.bin")
      assert is_reference(lock)
      assert :ok = HfHub.FS.unlock_file(lock)
    end

    test "creates lock directory if it doesn't exist", %{cache_dir: temp_dir} do
      assert {:ok, lock} = HfHub.FS.lock_file("test-repo", "test-file.bin")

      lock_dir = Path.join([temp_dir, "locks"])
      assert File.exists?(lock_dir)
      assert File.dir?(lock_dir)

      HfHub.FS.unlock_file(lock)
    end

    test "releases lock removes lock file", %{cache_dir: temp_dir} do
      assert {:ok, lock} = HfHub.FS.lock_file("test-repo", "test-file.bin")

      lock_path = Path.join([temp_dir, "locks", "test-repo--test-file.bin.lock"])
      assert File.exists?(lock_path)

      assert :ok = HfHub.FS.unlock_file(lock)
      refute File.exists?(lock_path)
    end

    test "returns error for invalid lock reference" do
      invalid_lock = make_ref()
      assert {:error, :invalid_lock} = HfHub.FS.unlock_file(invalid_lock)
    end

    test "concurrent lock attempts wait for lock to be released" do
      parent = self()

      # First process acquires lock
      task1 =
        Task.async(fn ->
          {:ok, lock} = HfHub.FS.lock_file("concurrent-repo", "file.bin")
          send(parent, {:locked, self()})
          # Hold lock for a short time
          Process.sleep(200)
          :ok = HfHub.FS.unlock_file(lock)
          send(parent, {:unlocked, self()})
        end)

      # Wait for first task to acquire lock
      assert_receive {:locked, _pid}, 1000

      # Second process tries to acquire the same lock
      task2 =
        Task.async(fn ->
          {:ok, lock} = HfHub.FS.lock_file("concurrent-repo", "file.bin")
          send(parent, {:locked2, self()})
          :ok = HfHub.FS.unlock_file(lock)
          send(parent, {:unlocked2, self()})
        end)

      # Wait for first task to unlock
      assert_receive {:unlocked, _pid}, 1000

      # Second task should now be able to lock
      assert_receive {:locked2, _pid}, 1000
      assert_receive {:unlocked2, _pid}, 1000

      Task.await(task1)
      Task.await(task2)
    end
  end
end
