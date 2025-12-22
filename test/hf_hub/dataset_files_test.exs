defmodule HfHub.DatasetFilesTest do
  use ExUnit.Case, async: true

  describe "resolve_from_tree/3" do
    test "resolves split files under data/ for default config" do
      tree = [
        %{type: :file, path: "data/train-00000.parquet"},
        %{type: :file, path: "data/test-00000.parquet"}
      ]

      assert {:ok, ["data/train-00000.parquet"]} =
               HfHub.DatasetFiles.resolve_from_tree(tree, "default", "train")
    end

    test "resolves split files under config directories" do
      tree = [
        %{type: :file, path: "math/train-00000.parquet"},
        %{type: :file, path: "math/data/test-00000.parquet"},
        %{type: :file, path: "data/train-00000.parquet"}
      ]

      assert {:ok, ["math/data/test-00000.parquet"]} =
               HfHub.DatasetFiles.resolve_from_tree(tree, "math", "test")
    end

    test "falls back to root when config has no directory" do
      tree = [%{type: :file, path: "data/train-00000.parquet"}]

      assert {:ok, ["data/train-00000.parquet"]} =
               HfHub.DatasetFiles.resolve_from_tree(tree, "main", "train")
    end

    test "returns error when no files match" do
      assert {:error, :no_files_found} =
               HfHub.DatasetFiles.resolve_from_tree([], "default", "train")
    end
  end

  describe "splits_from_tree/2" do
    test "infers split names from file paths" do
      tree = [
        %{type: :file, path: "data/train-00000.parquet"},
        %{type: :file, path: "data/validation-00000.parquet"}
      ]

      assert HfHub.DatasetFiles.splits_from_tree(tree, "default") == ["train", "validation"]
    end
  end
end
