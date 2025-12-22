defmodule HfHub.ExtractTest do
  use ExUnit.Case, async: true

  defp tmp_dir(prefix) do
    Path.join(System.tmp_dir!(), "#{prefix}_#{System.unique_integer([:positive])}")
  end

  describe "extract/2" do
    test "extracts zip archives" do
      dir = tmp_dir("hf_hub_zip")
      File.mkdir_p!(dir)

      source_path = Path.join(dir, "hello.txt")
      File.write!(source_path, "hello zip")

      zip_path = Path.join(dir, "archive.zip")

      {:ok, _} =
        :zip.create(
          to_charlist(zip_path),
          [~c"hello.txt"],
          cwd: to_charlist(dir)
        )

      dest_dir = Path.join(dir, "unzipped")
      assert {:ok, ^dest_dir} = HfHub.Extract.extract(zip_path, dest_dir)
      assert File.read!(Path.join(dest_dir, "hello.txt")) == "hello zip"
    end

    if System.find_executable("tar") do
      test "extracts tar.gz archives" do
        dir = tmp_dir("hf_hub_targz")
        File.mkdir_p!(dir)

        source_path = Path.join(dir, "hello.txt")
        File.write!(source_path, "hello tar")

        tar_path = Path.join(dir, "archive.tar.gz")
        {_, 0} = System.cmd("tar", ["-czf", tar_path, "-C", dir, "hello.txt"])

        dest_dir = Path.join(dir, "untarred")
        assert {:ok, ^dest_dir} = HfHub.Extract.extract(tar_path, dest_dir)
        assert File.read!(Path.join(dest_dir, "hello.txt")) == "hello tar"
      end
    end

    test "extracts gzip files" do
      dir = tmp_dir("hf_hub_gz")
      File.mkdir_p!(dir)

      gz_path = Path.join(dir, "hello.txt.gz")
      File.write!(gz_path, :zlib.gzip("hello gz"))

      output_path = Path.join(dir, "hello.txt")
      assert {:ok, ^output_path} = HfHub.Extract.extract(gz_path, output_path)
      assert File.read!(output_path) == "hello gz"
    end

    if System.find_executable("tar") do
      test "extracts tar.xz archives" do
        dir = tmp_dir("hf_hub_tarxz")
        File.mkdir_p!(dir)

        source_path = Path.join(dir, "hello.txt")
        File.write!(source_path, "hello xz")

        tar_path = Path.join(dir, "archive.tar.xz")
        {_, 0} = System.cmd("tar", ["-cJf", tar_path, "-C", dir, "hello.txt"])

        dest_dir = Path.join(dir, "untarred_xz")
        assert {:ok, ^dest_dir} = HfHub.Extract.extract(tar_path, dest_dir)
        assert File.read!(Path.join(dest_dir, "hello.txt")) == "hello xz"
      end
    end
  end
end
