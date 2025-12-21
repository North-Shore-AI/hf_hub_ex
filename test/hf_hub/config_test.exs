defmodule HfHub.ConfigTest do
  use ExUnit.Case, async: false

  describe "endpoint/0" do
    test "returns default endpoint" do
      assert HfHub.Config.endpoint() == "https://huggingface.co"
    end

    test "returns configured endpoint" do
      Application.put_env(:hf_hub, :endpoint, "https://custom.endpoint.com")
      assert HfHub.Config.endpoint() == "https://custom.endpoint.com"
      Application.delete_env(:hf_hub, :endpoint)
    end
  end

  describe "cache_dir/0" do
    setup do
      # Clear environment variables
      original_cache = System.get_env("HF_HUB_CACHE")
      original_home = System.get_env("HF_HOME")
      System.delete_env("HF_HUB_CACHE")
      System.delete_env("HF_HOME")

      on_exit(fn ->
        if original_cache, do: System.put_env("HF_HUB_CACHE", original_cache)
        if original_home, do: System.put_env("HF_HOME", original_home)
        Application.delete_env(:hf_hub, :cache_dir)
      end)

      :ok
    end

    test "returns default cache directory" do
      expected = Path.expand("~/.cache/huggingface")
      assert HfHub.Config.cache_dir() == expected
    end

    test "returns directory from HF_HUB_CACHE environment variable" do
      System.put_env("HF_HUB_CACHE", "/tmp/hf_cache")
      assert HfHub.Config.cache_dir() == "/tmp/hf_cache"
    end

    test "returns directory from HF_HOME environment variable" do
      System.put_env("HF_HOME", "/tmp/hf_home")
      assert HfHub.Config.cache_dir() == "/tmp/hf_home/hub"
    end

    test "prefers application config over environment variables" do
      Application.put_env(:hf_hub, :cache_dir, "/custom/cache")
      System.put_env("HF_HUB_CACHE", "/tmp/hf_cache")
      assert HfHub.Config.cache_dir() == "/custom/cache"
    end

    test "prefers HF_HUB_CACHE over HF_HOME" do
      System.put_env("HF_HUB_CACHE", "/tmp/hf_cache")
      System.put_env("HF_HOME", "/tmp/hf_home")
      assert HfHub.Config.cache_dir() == "/tmp/hf_cache"
    end
  end

  describe "http_opts/0" do
    test "returns default HTTP options" do
      opts = HfHub.Config.http_opts()
      assert opts[:receive_timeout] == 30_000
      assert opts[:pool_timeout] == 5_000
    end

    test "returns configured HTTP options" do
      Application.put_env(:hf_hub, :http_opts, receive_timeout: 60_000)
      opts = HfHub.Config.http_opts()
      assert opts[:receive_timeout] == 60_000
      Application.delete_env(:hf_hub, :http_opts)
    end
  end

  describe "cache_opts/0" do
    test "returns default cache options" do
      opts = HfHub.Config.cache_opts()
      assert opts[:max_size] == 10 * 1024 * 1024 * 1024
      assert opts[:eviction_policy] == :lru
    end

    test "returns configured cache options" do
      Application.put_env(:hf_hub, :cache_opts, max_size: 5_000_000_000)
      opts = HfHub.Config.cache_opts()
      assert opts[:max_size] == 5_000_000_000
      Application.delete_env(:hf_hub, :cache_opts)
    end
  end
end
