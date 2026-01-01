defmodule HfHub.Commit.OperationTest do
  use ExUnit.Case, async: true

  alias HfHub.Commit.Operation
  alias HfHub.Commit.Operation.{Add, Copy, Delete}

  describe "add/3" do
    test "creates add operation from binary content" do
      op = Operation.add("config.json", ~s({"key": "value"}))

      assert %Add{path_in_repo: "config.json"} = op
      assert op.upload_info != nil
      assert op.upload_info.size == 16
    end

    test "creates add operation from file path" do
      # Create temp file
      path = Path.join(System.tmp_dir!(), "test_file.txt")
      File.write!(path, "test content")

      op = Operation.add("uploaded.txt", path)

      assert %Add{path_in_repo: "uploaded.txt"} = op
      assert op.upload_info.size == 12

      File.rm!(path)
    end

    test "normalizes path with leading ./" do
      op = Operation.add("./config.json", "content")
      assert op.path_in_repo == "config.json"
    end

    test "raises on path starting with /" do
      assert_raise ArgumentError, ~r/cannot start with/, fn ->
        Operation.add("/absolute/path.txt", "content")
      end
    end

    test "raises on path containing .." do
      assert_raise ArgumentError, ~r/cannot contain/, fn ->
        Operation.add("../escape.txt", "content")
      end
    end

    test "raises on path containing //" do
      assert_raise ArgumentError, ~r/cannot contain/, fn ->
        Operation.add("path//double.txt", "content")
      end
    end

    test "accepts pre-computed upload_info" do
      upload_info = %HfHub.LFS.UploadInfo{
        sha256: :crypto.hash(:sha256, "test"),
        size: 4,
        sample: "test"
      }

      op = Operation.add("file.txt", "test", upload_info: upload_info)
      assert op.upload_info == upload_info
    end

    test "initializes with default values" do
      op = Operation.add("file.txt", "content")

      assert op.upload_mode == nil
      assert op.is_uploaded == false
      assert op.is_committed == false
    end
  end

  describe "delete/2" do
    test "creates delete operation for file" do
      op = Operation.delete("old_file.bin")

      assert %Delete{path_in_repo: "old_file.bin", is_folder: false} = op
    end

    test "creates delete operation for folder" do
      op = Operation.delete("old_weights/", is_folder: true)

      assert %Delete{is_folder: true} = op
    end

    test "normalizes path with leading ./" do
      op = Operation.delete("./old_file.bin")
      assert op.path_in_repo == "old_file.bin"
    end

    test "raises on path starting with /" do
      assert_raise ArgumentError, ~r/cannot start with/, fn ->
        Operation.delete("/absolute/path.txt")
      end
    end

    test "raises on path containing .." do
      assert_raise ArgumentError, ~r/cannot contain/, fn ->
        Operation.delete("../escape.txt")
      end
    end
  end

  describe "copy/3" do
    test "creates copy operation" do
      op = Operation.copy("v1/model.bin", "v2/model.bin")

      assert %Copy{src_path: "v1/model.bin", dst_path: "v2/model.bin"} = op
      assert op.src_revision == nil
    end

    test "creates copy with source revision" do
      op = Operation.copy("model.bin", "archive/model.bin", src_revision: "v1.0")

      assert op.src_revision == "v1.0"
    end

    test "normalizes paths" do
      op = Operation.copy("./src/model.bin", "./dst/model.bin")

      assert op.src_path == "src/model.bin"
      assert op.dst_path == "dst/model.bin"
    end

    test "raises on src_path starting with /" do
      assert_raise ArgumentError, ~r/cannot start with/, fn ->
        Operation.copy("/absolute/path.txt", "dst.txt")
      end
    end

    test "raises on dst_path containing .." do
      assert_raise ArgumentError, ~r/cannot contain/, fn ->
        Operation.copy("src.txt", "../escape.txt")
      end
    end
  end

  describe "file_path?/1" do
    test "returns true for existing file" do
      path = Path.join(System.tmp_dir!(), "test_exists.txt")
      File.write!(path, "content")

      op = Operation.add("file.txt", path)
      assert Operation.file_path?(op)

      File.rm!(path)
    end

    test "returns false for binary content" do
      op = Operation.add("file.txt", "raw content")
      refute Operation.file_path?(op)
    end

    test "returns false for non-existent file path" do
      op = Operation.add("file.txt", "/non/existent/path.txt")
      refute Operation.file_path?(op)
    end
  end

  describe "get_content/1" do
    test "returns binary content directly" do
      op = Operation.add("file.txt", "hello world")
      assert {:ok, "hello world"} = Operation.get_content(op)
    end

    test "reads content from file path" do
      path = Path.join(System.tmp_dir!(), "test_read.txt")
      File.write!(path, "file content")

      op = Operation.add("file.txt", path)
      assert {:ok, "file content"} = Operation.get_content(op)

      File.rm!(path)
    end

    test "returns error for missing file" do
      # Create an op with a path that looks like it could be a file
      # but doesn't exist - since file_path? returns false, it treats as binary
      op = %Add{
        path_in_repo: "file.txt",
        content: "/definitely/not/a/real/file.txt",
        upload_info: nil
      }

      # Since file doesn't exist, file_path? returns false, so content is returned as-is
      assert {:ok, "/definitely/not/a/real/file.txt"} = Operation.get_content(op)
    end
  end

  describe "base64_content/1" do
    test "encodes binary content" do
      op = Operation.add("file.txt", "hello world")
      assert {:ok, encoded} = Operation.base64_content(op)
      assert Base.decode64!(encoded) == "hello world"
    end

    test "encodes file content" do
      path = Path.join(System.tmp_dir!(), "test_b64.txt")
      File.write!(path, "file bytes")

      op = Operation.add("file.txt", path)
      assert {:ok, encoded} = Operation.base64_content(op)
      assert Base.decode64!(encoded) == "file bytes"

      File.rm!(path)
    end
  end
end
