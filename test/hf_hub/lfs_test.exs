defmodule HfHub.LFSTest do
  use ExUnit.Case, async: true

  alias HfHub.LFS
  alias HfHub.LFS.UploadInfo

  @sample_content "Hello, World! This is test content for LFS testing."

  setup do
    # Create a temporary test file
    tmp_dir = System.tmp_dir!()
    test_file = Path.join(tmp_dir, "lfs_test_file_#{:rand.uniform(100_000)}.txt")
    File.write!(test_file, @sample_content)
    on_exit(fn -> File.rm(test_file) end)
    {:ok, test_file: test_file}
  end

  describe "UploadInfo struct" do
    test "has required fields" do
      info = %UploadInfo{sha256: <<1, 2, 3>>, size: 100, sample: <<4, 5, 6>>}
      assert info.sha256 == <<1, 2, 3>>
      assert info.size == 100
      assert info.sample == <<4, 5, 6>>
    end
  end

  describe "UploadInfo.from_path/1" do
    test "calculates sha256 hash from file", %{test_file: test_file} do
      info = UploadInfo.from_path(test_file)

      # SHA256 should be 32 bytes (256 bits)
      assert byte_size(info.sha256) == 32
    end

    test "returns correct file size", %{test_file: test_file} do
      info = UploadInfo.from_path(test_file)
      expected_size = byte_size(@sample_content)
      assert info.size == expected_size
    end

    test "captures first 512 bytes as sample", %{test_file: test_file} do
      info = UploadInfo.from_path(test_file)

      # For small files, sample is the whole content
      assert info.sample == @sample_content
    end

    test "truncates sample to 512 bytes for large files" do
      tmp_dir = System.tmp_dir!()
      large_file = Path.join(tmp_dir, "large_lfs_test_#{:rand.uniform(100_000)}.bin")
      large_content = :crypto.strong_rand_bytes(1024)
      File.write!(large_file, large_content)
      on_exit(fn -> File.rm(large_file) end)

      info = UploadInfo.from_path(large_file)
      assert byte_size(info.sample) == 512
      assert info.sample == binary_part(large_content, 0, 512)
    end
  end

  describe "UploadInfo.from_binary/1" do
    test "calculates sha256 hash from binary" do
      info = UploadInfo.from_binary(@sample_content)
      assert byte_size(info.sha256) == 32
    end

    test "returns correct binary size" do
      info = UploadInfo.from_binary(@sample_content)
      assert info.size == byte_size(@sample_content)
    end

    test "captures sample from binary" do
      info = UploadInfo.from_binary(@sample_content)
      assert info.sample == @sample_content
    end

    test "truncates sample for large binaries" do
      large_binary = :crypto.strong_rand_bytes(1024)
      info = UploadInfo.from_binary(large_binary)

      assert byte_size(info.sample) == 512
      assert info.sample == binary_part(large_binary, 0, 512)
    end
  end

  describe "sha256_hex/1" do
    test "converts binary sha256 to hex string" do
      info = UploadInfo.from_binary("test content")
      hex = LFS.sha256_hex(info)

      # SHA256 as hex is 64 characters
      assert String.length(hex) == 64
      assert String.match?(hex, ~r/^[0-9a-f]{64}$/)
    end
  end

  describe "oid/1" do
    test "returns sha256 in LFS OID format" do
      info = UploadInfo.from_binary("test content")
      oid = LFS.oid(info)

      # OID matches LFS format
      assert String.match?(oid, ~r/^[0-9a-f]{64}$/)
    end
  end

  describe "LFS headers" do
    test "lfs_headers returns correct content type" do
      headers = LFS.lfs_headers()

      assert Enum.find(headers, fn {k, _} -> k == "Accept" end) ==
               {"Accept", "application/vnd.git-lfs+json"}

      assert Enum.find(headers, fn {k, _} -> k == "Content-Type" end) ==
               {"Content-Type", "application/vnd.git-lfs+json"}
    end
  end
end
