defmodule HfHub.OfflineTest do
  use ExUnit.Case, async: false

  setup do
    # Create a temp cache dir for tests
    cache_dir = Path.join(System.tmp_dir!(), "hf_hub_offline_test_#{:rand.uniform(1_000_000)}")
    File.mkdir_p!(cache_dir)
    Application.put_env(:hf_hub, :cache_dir, cache_dir)

    # Clear any offline settings
    System.delete_env("HF_HUB_OFFLINE")
    Application.delete_env(:hf_hub, :offline)

    on_exit(fn ->
      Application.delete_env(:hf_hub, :cache_dir)
      Application.delete_env(:hf_hub, :offline)
      System.delete_env("HF_HUB_OFFLINE")
      File.rm_rf!(cache_dir)
    end)

    {:ok, cache_dir: cache_dir}
  end

  describe "offline_mode?/0" do
    test "returns false by default" do
      refute HfHub.offline_mode?()
    end

    test "returns true when HF_HUB_OFFLINE=1 env var is set" do
      System.put_env("HF_HUB_OFFLINE", "1")
      assert HfHub.offline_mode?()
    end

    test "returns false when HF_HUB_OFFLINE is set to other values" do
      System.put_env("HF_HUB_OFFLINE", "0")
      refute HfHub.offline_mode?()

      System.put_env("HF_HUB_OFFLINE", "false")
      refute HfHub.offline_mode?()

      System.put_env("HF_HUB_OFFLINE", "true")
      refute HfHub.offline_mode?()
    end

    test "returns true when application config offline: true is set" do
      Application.put_env(:hf_hub, :offline, true)
      assert HfHub.offline_mode?()
    end

    test "returns false when application config offline: false is set" do
      Application.put_env(:hf_hub, :offline, false)
      refute HfHub.offline_mode?()
    end

    test "env var takes precedence if set to 1" do
      Application.put_env(:hf_hub, :offline, false)
      System.put_env("HF_HUB_OFFLINE", "1")
      assert HfHub.offline_mode?()
    end

    test "application config works when env var not set" do
      System.delete_env("HF_HUB_OFFLINE")
      Application.put_env(:hf_hub, :offline, true)
      assert HfHub.offline_mode?()
    end
  end

  describe "try_to_load_from_cache/3" do
    test "returns {:ok, path} when file exists in cache", %{cache_dir: cache_dir} do
      # Create a cached file
      repo_path =
        Path.join([cache_dir, "hub", "models--test-repo", "snapshots", "main"])

      File.mkdir_p!(repo_path)
      file_path = Path.join(repo_path, "config.json")
      File.write!(file_path, ~s({"test": true}))

      result = HfHub.try_to_load_from_cache("test-repo", "config.json")

      assert {:ok, ^file_path} = result
    end

    test "returns {:error, :not_cached} when file doesn't exist" do
      result = HfHub.try_to_load_from_cache("nonexistent-repo", "missing.json")

      assert {:error, :not_cached} = result
    end

    test "respects :revision option", %{cache_dir: cache_dir} do
      # Create a cached file at a specific revision
      repo_path =
        Path.join([cache_dir, "hub", "models--test-repo", "snapshots", "v1.0"])

      File.mkdir_p!(repo_path)
      file_path = Path.join(repo_path, "model.bin")
      File.write!(file_path, "model data")

      # Should find it with correct revision
      {:ok, found_path} =
        HfHub.try_to_load_from_cache("test-repo", "model.bin", revision: "v1.0")

      assert found_path == file_path

      # Should not find it with different revision
      result = HfHub.try_to_load_from_cache("test-repo", "model.bin", revision: "main")
      assert {:error, :not_cached} = result
    end

    test "respects :repo_type option", %{cache_dir: cache_dir} do
      # Create a cached file for a dataset
      repo_path =
        Path.join([cache_dir, "hub", "datasets--test-dataset", "snapshots", "main"])

      File.mkdir_p!(repo_path)
      file_path = Path.join(repo_path, "data.json")
      File.write!(file_path, "[]")

      # Should find it with correct repo_type
      {:ok, found_path} =
        HfHub.try_to_load_from_cache("test-dataset", "data.json", repo_type: :dataset)

      assert found_path == file_path

      # Should not find it with wrong repo_type (defaults to :model)
      result = HfHub.try_to_load_from_cache("test-dataset", "data.json")
      assert {:error, :not_cached} = result
    end

    test "handles nested filenames", %{cache_dir: cache_dir} do
      # Create a cached file in a subdirectory
      repo_path =
        Path.join([cache_dir, "hub", "models--test-repo", "snapshots", "main", "subdir"])

      File.mkdir_p!(repo_path)
      file_path = Path.join(repo_path, "nested.json")
      File.write!(file_path, "{}")

      {:ok, found_path} =
        HfHub.try_to_load_from_cache("test-repo", "subdir/nested.json")

      assert found_path == file_path
    end

    test "handles repo_id with organization", %{cache_dir: cache_dir} do
      # Create a cached file for org/repo format
      repo_path =
        Path.join([
          cache_dir,
          "hub",
          "models--my-org--my-model",
          "snapshots",
          "main"
        ])

      File.mkdir_p!(repo_path)
      file_path = Path.join(repo_path, "config.json")
      File.write!(file_path, "{}")

      {:ok, found_path} =
        HfHub.try_to_load_from_cache("my-org/my-model", "config.json")

      assert found_path == file_path
    end

    test "does not make network requests" do
      # This test ensures that try_to_load_from_cache doesn't try to download
      # We don't set up a Bypass, so any network request would fail

      # These should return :not_cached without attempting network
      assert {:error, :not_cached} =
               HfHub.try_to_load_from_cache("bert-base-uncased", "config.json")

      assert {:error, :not_cached} =
               HfHub.try_to_load_from_cache("openai/gpt-2", "model.bin")
    end
  end
end
