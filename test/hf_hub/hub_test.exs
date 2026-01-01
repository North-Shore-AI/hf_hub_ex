defmodule HfHub.HubTest do
  use ExUnit.Case, async: true

  alias HfHub.Hub

  describe "file_url/3" do
    test "builds URL with default revision (nil)" do
      url = Hub.file_url("bert-base-uncased", "config.json", nil)
      assert url =~ "huggingface.co"
      assert url =~ "bert-base-uncased"
      assert url =~ "resolve/main"
      assert url =~ "config.json"
    end

    test "builds URL with custom revision" do
      url = Hub.file_url("bert-base-uncased", "config.json", "v1.0")
      assert url =~ "resolve/v1.0"
    end
  end

  describe "file_listing_url/3" do
    test "builds listing URL without subdir" do
      url = Hub.file_listing_url("bert-base-uncased", nil, nil)
      assert url =~ "api/models"
      assert url =~ "bert-base-uncased"
      assert url =~ "tree/main"
      refute url =~ "tree/main/"
    end

    test "builds listing URL with subdir" do
      url = Hub.file_listing_url("bert-base-uncased", "tokenizer", nil)
      assert url =~ "tree/main/tokenizer"
    end

    test "builds listing URL with custom revision" do
      url = Hub.file_listing_url("bert-base-uncased", nil, "v1.0")
      assert url =~ "tree/v1.0"
    end
  end
end
