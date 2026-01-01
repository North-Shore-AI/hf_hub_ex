defmodule HfHub.RepositoryTest do
  use ExUnit.Case, async: true

  alias HfHub.Repository

  describe "normalize!/1" do
    test "normalizes simple {:hf, id} tuple" do
      assert Repository.normalize!({:hf, "bert-base-uncased"}) ==
               {:hf, "bert-base-uncased", []}
    end

    test "normalizes {:hf, id, opts} tuple" do
      assert Repository.normalize!({:hf, "bert-base-uncased", revision: "v1.0"}) ==
               {:hf, "bert-base-uncased", [revision: "v1.0"]}
    end

    test "normalizes {:local, dir} tuple" do
      assert Repository.normalize!({:local, "/path/to/model"}) ==
               {:local, "/path/to/model"}
    end

    test "raises on invalid input" do
      assert_raise ArgumentError, fn ->
        Repository.normalize!("invalid")
      end
    end

    test "validates allowed options" do
      # These should work
      assert Repository.normalize!({:hf, "id", revision: "main"})
      assert Repository.normalize!({:hf, "id", cache_dir: "/tmp"})
      assert Repository.normalize!({:hf, "id", offline: true})
      assert Repository.normalize!({:hf, "id", auth_token: "token"})
      assert Repository.normalize!({:hf, "id", subdir: "dir"})

      # Unknown option should raise
      assert_raise ArgumentError, fn ->
        Repository.normalize!({:hf, "id", unknown_opt: true})
      end
    end
  end

  describe "file_url/2" do
    test "builds URL with default revision" do
      url = Repository.file_url({:hf, "bert-base-uncased", []}, "config.json")
      assert url =~ "huggingface.co"
      assert url =~ "bert-base-uncased"
      assert url =~ "resolve/main"
      assert url =~ "config.json"
    end

    test "builds URL with custom revision" do
      url = Repository.file_url({:hf, "bert-base-uncased", revision: "v1.0"}, "config.json")
      assert url =~ "resolve/v1.0"
    end

    test "includes subdir in filename" do
      url = Repository.file_url({:hf, "repo", subdir: "text_encoder"}, "config.json")
      assert url =~ "text_encoder/config.json"
    end
  end

  describe "file_listing_url/1" do
    test "builds listing URL" do
      url = Repository.file_listing_url({:hf, "bert-base-uncased", []})
      assert url =~ "api/models"
      assert url =~ "tree/main"
    end
  end

  describe "cache_scope/1" do
    test "converts slashes to dashes" do
      assert Repository.cache_scope("openai/gpt-2") == "openai--gpt-2"
    end

    test "removes special characters" do
      assert Repository.cache_scope("user/model@v1") == "user--modelv1"
    end
  end
end
