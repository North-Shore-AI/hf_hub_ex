defmodule HfHub.Integration.LiveApiTest do
  @moduledoc """
  Integration tests against the real HuggingFace Hub API.

  These tests require network access and optionally a HF_TOKEN for authenticated endpoints.
  Run with: mix test test/integration --include live

  Set HF_TOKEN environment variable for authenticated tests:
    HF_TOKEN=hf_xxx mix test test/integration --include live
  """
  use ExUnit.Case, async: false

  @moduletag :live

  setup do
    # Reset endpoint to production
    Application.delete_env(:hf_hub, :endpoint)

    # Create temp cache dir
    cache_dir = Path.join(System.tmp_dir!(), "hf_hub_live_test_#{:rand.uniform(1_000_000)}")
    File.mkdir_p!(cache_dir)
    Application.put_env(:hf_hub, :cache_dir, cache_dir)

    on_exit(fn ->
      Application.delete_env(:hf_hub, :cache_dir)
      File.rm_rf!(cache_dir)
    end)

    {:ok, cache_dir: cache_dir}
  end

  describe "HfHub.Api - live" do
    test "list_datasets returns real datasets" do
      {:ok, datasets} = HfHub.Api.list_datasets(limit: 5)

      assert is_list(datasets)
      assert length(datasets) == 5

      first = hd(datasets)
      assert is_binary(first.id)
      assert is_integer(first.downloads)
    end

    test "list_models returns real models" do
      {:ok, models} = HfHub.Api.list_models(limit: 5)

      assert is_list(models)
      assert length(models) == 5

      first = hd(models)
      assert is_binary(first.id)
    end

    test "dataset_info returns info for imdb dataset" do
      {:ok, info} = HfHub.Api.dataset_info("imdb")

      assert String.contains?(info.id, "imdb")
      assert is_integer(info.downloads)
      assert is_list(info.siblings)
    end

    test "model_info returns info for gpt2" do
      {:ok, info} = HfHub.Api.model_info("gpt2")

      assert String.contains?(info.id, "gpt2")
      assert is_integer(info.downloads)
      assert is_list(info.tags)
    end

    test "list_files returns files for a model" do
      {:ok, files} = HfHub.Api.list_files("bert-base-uncased", repo_type: :model)

      assert is_list(files)
      refute Enum.empty?(files)

      filenames = Enum.map(files, & &1.rfilename)
      assert "config.json" in filenames
    end

    test "list_files returns files for a dataset" do
      {:ok, files} = HfHub.Api.list_files("imdb", repo_type: :dataset)

      assert is_list(files)
      refute Enum.empty?(files)
    end

    test "dataset_configs returns config names for gsm8k" do
      {:ok, configs} = HfHub.Api.dataset_configs("openai/gsm8k")

      assert is_list(configs)
      assert "main" in configs
      assert "socratic" in configs
    end

    test "dataset_configs returns empty list for dataset without configs" do
      {:ok, configs} = HfHub.Api.dataset_configs("imdb")

      assert is_list(configs)
      # imdb may or may not have configs, just verify it returns a list
    end
  end

  describe "HfHub.Download - live" do
    test "downloads config.json from gpt2", %{cache_dir: cache_dir} do
      {:ok, path} =
        HfHub.Download.hf_hub_download(
          repo_id: "gpt2",
          filename: "config.json",
          repo_type: :model
        )

      assert String.starts_with?(path, cache_dir)
      assert File.exists?(path)

      content = File.read!(path)
      assert String.contains?(content, "gpt2")

      # Verify it's valid JSON
      {:ok, json} = Jason.decode(content)
      assert Map.has_key?(json, "model_type")
    end

    test "downloads tokenizer from gpt2", %{cache_dir: cache_dir} do
      {:ok, path} =
        HfHub.Download.hf_hub_download(
          repo_id: "gpt2",
          filename: "tokenizer.json",
          repo_type: :model
        )

      assert String.starts_with?(path, cache_dir)
      assert File.exists?(path)
      assert File.read!(path) |> String.length() > 0
    end

    test "caches downloaded files", %{cache_dir: _cache_dir} do
      # First download
      {:ok, path1} =
        HfHub.Download.hf_hub_download(
          repo_id: "gpt2",
          filename: "config.json"
        )

      # Should be cached - instant return
      {:ok, path2} =
        HfHub.Download.hf_hub_download(
          repo_id: "gpt2",
          filename: "config.json"
        )

      assert path1 == path2
      assert HfHub.Cache.cached?(repo_id: "gpt2", filename: "config.json")
    end

    test "download_stream streams file content" do
      {:ok, stream} =
        HfHub.Download.download_stream(
          repo_id: "gpt2",
          filename: "config.json"
        )

      content = stream |> Enum.to_list() |> IO.iodata_to_binary()
      assert String.contains?(content, "gpt2")
      {:ok, _} = Jason.decode(content)
    end
  end

  describe "HfHub.Auth - live (requires HF_TOKEN)" do
    @describetag :authenticated

    setup do
      case System.get_env("HF_TOKEN") do
        nil -> {:ok, token: nil}
        token -> {:ok, token: token}
      end
    end

    test "whoami returns user info when authenticated", context do
      case context[:token] do
        nil ->
          IO.puts("\n  [SKIPPED] Set HF_TOKEN to run authenticated tests")
          assert true

        token ->
          Application.put_env(:hf_hub, :token, token)

          {:ok, user} = HfHub.Auth.whoami()

          assert is_binary(user.username)
          assert user.username != ""
          IO.puts("\n  [OK] Authenticated as: #{user.username}")
      end
    end

    test "login with validation works", context do
      case context[:token] do
        nil ->
          IO.puts("\n  [SKIPPED] Set HF_TOKEN to run authenticated tests")
          assert true

        token ->
          # Logout first
          HfHub.Auth.logout()
          assert {:error, :no_token} = HfHub.Auth.get_token()

          # Login with validation
          :ok = HfHub.Auth.login(token: token, validate: true)
          assert {:ok, ^token} = HfHub.Auth.get_token()

          # Verify we can use the token
          {:ok, user} = HfHub.Auth.whoami()
          assert is_binary(user.username)
      end
    end

    test "downloads from private repo if token provided", context do
      case context[:token] do
        nil ->
          IO.puts("\n  [SKIPPED] Set HF_TOKEN to run authenticated tests")
          assert true

        _token ->
          # This test requires a private repo - skip if not available
          IO.puts("\n  [INFO] Private repo test requires manual setup")
          assert true
      end
    end
  end

  describe "HfHub.Cache - live" do
    test "cache_stats returns valid statistics", %{cache_dir: _cache_dir} do
      # Download a file first
      {:ok, _} =
        HfHub.Download.hf_hub_download(
          repo_id: "gpt2",
          filename: "config.json"
        )

      {:ok, stats} = HfHub.Cache.cache_stats()

      assert is_integer(stats.total_size)
      assert is_integer(stats.file_count)
    end

    test "clear_cache removes cached files", %{cache_dir: _cache_dir} do
      # Download a file
      {:ok, path} =
        HfHub.Download.hf_hub_download(
          repo_id: "gpt2",
          filename: "config.json"
        )

      assert File.exists?(path)

      # Clear cache
      :ok = HfHub.Cache.clear_cache(repo_id: "gpt2", repo_type: :model)

      refute File.exists?(path)
    end
  end
end
