defmodule HfHub.ConstantsTest do
  use ExUnit.Case, async: true

  alias HfHub.Constants

  describe "file name constants" do
    test "PYTORCH_WEIGHTS_NAME returns correct filename" do
      assert Constants.pytorch_weights_name() == "pytorch_model.bin"
    end

    test "CONFIG_NAME returns config.json" do
      assert Constants.config_name() == "config.json"
    end

    test "SAFETENSORS_SINGLE_FILE returns model.safetensors" do
      assert Constants.safetensors_single_file() == "model.safetensors"
    end

    test "SAFETENSORS_INDEX_FILE returns index filename" do
      assert Constants.safetensors_index_file() == "model.safetensors.index.json"
    end

    test "REPOCARD_NAME returns README.md" do
      assert Constants.repocard_name() == "README.md"
    end

    test "FLAX_WEIGHTS_NAME returns flax_model.msgpack" do
      assert Constants.flax_weights_name() == "flax_model.msgpack"
    end
  end

  describe "timeout constants" do
    test "DEFAULT_ETAG_TIMEOUT returns 10 seconds" do
      assert Constants.default_etag_timeout() == 10
    end

    test "DEFAULT_DOWNLOAD_TIMEOUT returns 10 seconds" do
      assert Constants.default_download_timeout() == 10
    end

    test "DEFAULT_REQUEST_TIMEOUT returns 10 seconds" do
      assert Constants.default_request_timeout() == 10
    end
  end

  describe "size constants" do
    test "DOWNLOAD_CHUNK_SIZE returns 10MB" do
      assert Constants.download_chunk_size() == 10 * 1024 * 1024
    end

    test "SAFETENSORS_MAX_HEADER_LENGTH returns 25MB" do
      assert Constants.safetensors_max_header_length() == 25_000_000
    end
  end

  describe "repository types" do
    test "REPO_TYPE_MODEL returns model" do
      assert Constants.repo_type_model() == "model"
    end

    test "REPO_TYPE_DATASET returns dataset" do
      assert Constants.repo_type_dataset() == "dataset"
    end

    test "REPO_TYPE_SPACE returns space" do
      assert Constants.repo_type_space() == "space"
    end

    test "repo_types returns all types" do
      types = Constants.repo_types()
      assert :model in types
      assert :dataset in types
      assert :space in types
    end
  end

  describe "repo type URL prefixes" do
    test "repo_type_url_prefix returns correct prefix for dataset" do
      assert Constants.repo_type_url_prefix(:dataset) == "datasets/"
    end

    test "repo_type_url_prefix returns correct prefix for space" do
      assert Constants.repo_type_url_prefix(:space) == "spaces/"
    end

    test "repo_type_url_prefix returns empty string for model" do
      assert Constants.repo_type_url_prefix(:model) == ""
    end
  end

  describe "header constants" do
    test "HEADER_X_REPO_COMMIT returns correct header name" do
      assert Constants.header_x_repo_commit() == "X-Repo-Commit"
    end

    test "HEADER_X_LINKED_ETAG returns correct header name" do
      assert Constants.header_x_linked_etag() == "X-Linked-Etag"
    end

    test "HEADER_X_LINKED_SIZE returns correct header name" do
      assert Constants.header_x_linked_size() == "X-Linked-Size"
    end
  end

  describe "URL templates" do
    test "default_endpoint returns huggingface.co" do
      assert Constants.default_endpoint() == "https://huggingface.co"
    end

    test "REPO_ID_SEPARATOR returns double dash" do
      assert Constants.repo_id_separator() == "--"
    end
  end

  describe "revision constants" do
    test "DEFAULT_REVISION returns main" do
      assert Constants.default_revision() == "main"
    end
  end
end
