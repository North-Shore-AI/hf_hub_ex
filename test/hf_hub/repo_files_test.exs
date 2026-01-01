defmodule HfHub.RepoFilesTest do
  use ExUnit.Case, async: true

  alias HfHub.RepoFiles

  describe "get_repo_files/1 with local directory" do
    setup do
      # Create a temp directory with some files
      tmp_dir = Path.join(System.tmp_dir!(), "hf_hub_test_#{:rand.uniform(100_000)}")
      File.mkdir_p!(tmp_dir)
      File.write!(Path.join(tmp_dir, "config.json"), "{}")
      File.write!(Path.join(tmp_dir, "model.bin"), "data")
      File.mkdir_p!(Path.join(tmp_dir, "subdir"))

      on_exit(fn -> File.rm_rf!(tmp_dir) end)

      {:ok, tmp_dir: tmp_dir}
    end

    test "returns map of files with nil etags", %{tmp_dir: tmp_dir} do
      {:ok, files} = RepoFiles.get_repo_files({:local, tmp_dir})

      assert is_map(files)
      assert Map.has_key?(files, "config.json")
      assert Map.has_key?(files, "model.bin")
      # Directories should not be included
      refute Map.has_key?(files, "subdir")
      # ETags are nil for local files
      assert files["config.json"] == nil
    end

    test "returns error for non-existent directory" do
      {:error, msg} = RepoFiles.get_repo_files({:local, "/non/existent/path"})
      assert msg =~ "could not read"
    end
  end

  describe "get_repo_files/1 normalizes input" do
    test "normalizes {:hf, id} to {:hf, id, []}" do
      # This will fail with network error in tests, but validates normalization works
      result = RepoFiles.get_repo_files({:hf, "nonexistent/repo"})
      assert {:error, _} = result
    end
  end
end
