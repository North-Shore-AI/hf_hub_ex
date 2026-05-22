defmodule HfHub.PathTest do
  use ExUnit.Case, async: true

  alias HfHub.Path

  describe "encode_repo_id/1" do
    test "preserves the literal owner/name separator" do
      assert Path.encode_repo_id("org/repo") == "org/repo"
      assert Path.encode_repo_id("bare-model") == "bare-model"
    end

    test "encodes owner and repo-name components without encoding the slash" do
      assert Path.encode_repo_id("my org/model #1") == "my%20org/model%20%231"
      assert Path.encode_repo_id("org/model+plus") == "org/model%2Bplus"
    end
  end

  describe "encode_segment/1" do
    test "encodes slash and other reserved characters inside branch/tag/revision segments" do
      assert Path.encode_segment("feature/foo") == "feature%2Ffoo"
      assert Path.encode_segment("v1.0 # release") == "v1.0%20%23%20release"
    end
  end

  describe "encode_path/1" do
    test "encodes each file path segment while preserving separators" do
      assert Path.encode_path("checkpoints/model #1.safetensors") ==
               "checkpoints/model%20%231.safetensors"
    end
  end
end
