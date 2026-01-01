defmodule HfHub.ErrorsTest do
  use ExUnit.Case, async: true

  alias HfHub.Errors

  describe "CacheNotFound" do
    test "creates exception with message and cache_dir" do
      error =
        Errors.CacheNotFound.exception(
          message: "Cache not found",
          cache_dir: "/path/to/cache"
        )

      assert error.message == "Cache not found"
      assert error.cache_dir == "/path/to/cache"
    end

    test "includes cache_dir in formatted message" do
      error =
        Errors.CacheNotFound.exception(
          message: "Cache not found at /path/to/cache",
          cache_dir: "/path/to/cache"
        )

      assert Exception.message(error) =~ "/path/to/cache"
    end
  end

  describe "CorruptedCache" do
    test "creates exception with message" do
      error = Errors.CorruptedCache.exception(message: "Invalid cache structure")
      assert error.message == "Invalid cache structure"
    end
  end

  describe "RepositoryNotFound" do
    test "creates exception with repo details" do
      error =
        Errors.RepositoryNotFound.exception(
          message: "Repository not found",
          repo_id: "user/model",
          repo_type: :model
        )

      assert error.message == "Repository not found"
      assert error.repo_id == "user/model"
      assert error.repo_type == :model
    end

    test "includes request_id when provided" do
      error =
        Errors.RepositoryNotFound.exception(
          message: "Repository not found",
          repo_id: "user/model",
          request_id: "abc123"
        )

      assert error.request_id == "abc123"
    end
  end

  describe "RevisionNotFound" do
    test "creates exception with revision details" do
      error =
        Errors.RevisionNotFound.exception(
          message: "Revision not found",
          repo_id: "user/model",
          revision: "nonexistent-branch"
        )

      assert error.message == "Revision not found"
      assert error.repo_id == "user/model"
      assert error.revision == "nonexistent-branch"
    end
  end

  describe "EntryNotFound" do
    test "creates exception with file path details" do
      error =
        Errors.EntryNotFound.exception(
          message: "File not found",
          repo_id: "user/model",
          path: "config.json"
        )

      assert error.message == "File not found"
      assert error.repo_id == "user/model"
      assert error.path == "config.json"
    end
  end

  describe "GatedRepo" do
    test "creates exception for gated repository access" do
      error =
        Errors.GatedRepo.exception(
          message: "Access restricted",
          repo_id: "meta-llama/Llama-2-7b"
        )

      assert error.message == "Access restricted"
      assert error.repo_id == "meta-llama/Llama-2-7b"
    end
  end

  describe "OfflineMode" do
    test "creates exception when offline mode blocks request" do
      error = Errors.OfflineMode.exception(message: "Offline mode is enabled")

      assert error.message == "Offline mode is enabled"
    end
  end

  describe "HTTPError" do
    test "creates exception with status and response details" do
      error =
        Errors.HTTPError.exception(
          message: "HTTP request failed",
          status: 500,
          request_id: "xyz789"
        )

      assert error.message == "HTTP request failed"
      assert error.status == 500
      assert error.request_id == "xyz789"
    end

    test "stores server_message when provided" do
      error =
        Errors.HTTPError.exception(
          message: "Server error",
          status: 503,
          server_message: "Service temporarily unavailable"
        )

      assert error.server_message == "Service temporarily unavailable"
    end

    test "append_to_message adds text to error message" do
      error =
        Errors.HTTPError.exception(
          message: "Request failed",
          status: 400
        )

      updated = Errors.HTTPError.append_to_message(error, "\nAdditional context here.")
      assert Exception.message(updated) =~ "Additional context here."
    end
  end

  describe "LocalTokenNotFound" do
    test "creates exception for missing token" do
      error =
        Errors.LocalTokenNotFound.exception(
          message: "Token not found in ~/.cache/huggingface/token"
        )

      assert error.message =~ "Token not found"
    end
  end

  describe "DisabledRepo" do
    test "creates exception for disabled repository" do
      error =
        Errors.DisabledRepo.exception(
          message: "Repository is disabled",
          repo_id: "user/disabled-model"
        )

      assert error.message == "Repository is disabled"
      assert error.repo_id == "user/disabled-model"
    end

    test "includes request_id when provided" do
      error =
        Errors.DisabledRepo.exception(
          message: "Repository is disabled",
          repo_id: "user/model",
          request_id: "req123"
        )

      assert error.request_id == "req123"
    end
  end

  describe "RemoteEntryNotFound" do
    test "creates exception for remote file not found" do
      error =
        Errors.RemoteEntryNotFound.exception(
          message: "Entry not found on Hub",
          repo_id: "bert-base-uncased",
          path: "missing.json",
          revision: "main"
        )

      assert error.message == "Entry not found on Hub"
      assert error.repo_id == "bert-base-uncased"
      assert error.path == "missing.json"
      assert error.revision == "main"
    end

    test "includes request_id when provided" do
      error =
        Errors.RemoteEntryNotFound.exception(
          message: "Entry not found",
          repo_id: "user/model",
          path: "file.txt",
          request_id: "xyz789"
        )

      assert error.request_id == "xyz789"
    end
  end

  describe "LocalEntryNotFound" do
    test "creates exception for local file not found" do
      error =
        Errors.LocalEntryNotFound.exception(
          message: "Cannot find file in local cache",
          path: "/cache/models/bert/config.json"
        )

      assert error.message == "Cannot find file in local cache"
      assert error.path == "/cache/models/bert/config.json"
    end
  end

  describe "BadRequest" do
    test "creates exception for HTTP 400 error" do
      error =
        Errors.BadRequest.exception(
          message: "Bad request",
          status: 400
        )

      assert error.message == "Bad request"
      assert error.status == 400
    end

    test "includes server_message and request_id" do
      error =
        Errors.BadRequest.exception(
          message: "Invalid parameters",
          status: 400,
          server_message: "Missing required field: repo_id",
          request_id: "abc123"
        )

      assert error.server_message == "Missing required field: repo_id"
      assert error.request_id == "abc123"
    end
  end

  describe "InferenceTimeout" do
    test "creates exception for inference timeout" do
      error =
        Errors.InferenceTimeout.exception(message: "Model is unavailable or request timed out")

      assert error.message =~ "unavailable"
    end
  end

  describe "InferenceEndpointError" do
    test "creates exception for inference endpoint error" do
      error = Errors.InferenceEndpointError.exception(message: "Error with inference endpoint")

      assert error.message == "Error with inference endpoint"
    end
  end

  describe "InferenceEndpointTimeout" do
    test "creates exception for inference endpoint timeout" do
      error = Errors.InferenceEndpointTimeout.exception(message: "Inference endpoint timed out")

      assert error.message == "Inference endpoint timed out"
    end
  end

  describe "SafetensorsParsing" do
    test "creates exception for safetensors parsing error" do
      error = Errors.SafetensorsParsing.exception(message: "Failed to parse safetensors file")

      assert error.message == "Failed to parse safetensors file"
    end
  end

  describe "NotASafetensorsRepo" do
    test "creates exception for non-safetensors repo" do
      error =
        Errors.NotASafetensorsRepo.exception(
          message: "Repository does not have safetensors files",
          repo_id: "old-model/pytorch-only"
        )

      assert error.message == "Repository does not have safetensors files"
      assert error.repo_id == "old-model/pytorch-only"
    end
  end

  describe "TextGeneration" do
    test "creates exception for text generation error" do
      error = Errors.TextGeneration.exception(message: "Text generation failed")

      assert error.message == "Text generation failed"
    end
  end

  describe "TextGenerationValidation" do
    test "creates exception for server validation error" do
      error =
        Errors.TextGenerationValidation.exception(
          message: "Input validation failed: max_tokens too large"
        )

      assert error.message =~ "validation failed"
    end
  end

  describe "TextGenerationOverloaded" do
    test "creates exception for overloaded server" do
      error = Errors.TextGenerationOverloaded.exception(message: "Server is overloaded")

      assert error.message == "Server is overloaded"
    end
  end

  describe "TextGenerationIncomplete" do
    test "creates exception for incomplete generation" do
      error = Errors.TextGenerationIncomplete.exception(message: "Generation was incomplete")

      assert error.message == "Generation was incomplete"
    end
  end

  describe "HFValidation" do
    test "creates exception for validation error" do
      error = Errors.HFValidation.exception(message: "Invalid repo_id format")

      assert error.message == "Invalid repo_id format"
    end
  end

  describe "DryRun" do
    test "creates exception for dry run error" do
      error = Errors.DryRun.exception(message: "Dry run failed: invalid repository")

      assert error.message =~ "Dry run failed"
    end
  end

  describe "FileMetadata" do
    test "creates exception for missing file metadata" do
      error =
        Errors.FileMetadata.exception(
          message: "Missing ETag or commit_hash",
          url: "https://huggingface.co/bert-base-uncased/resolve/main/config.json"
        )

      assert error.message == "Missing ETag or commit_hash"
      assert error.url =~ "huggingface.co"
    end
  end

  describe "DDUFError" do
    test "creates exception for DDUF error" do
      error = Errors.DDUFError.exception(message: "DDUF format error")
      assert error.message == "DDUF format error"
    end
  end

  describe "DDUFCorruptedFile" do
    test "creates exception for corrupted DDUF file" do
      error = Errors.DDUFCorruptedFile.exception(message: "DDUF file is corrupted")

      assert error.message == "DDUF file is corrupted"
    end
  end

  describe "DDUFExport" do
    test "creates exception for DDUF export error" do
      error = Errors.DDUFExport.exception(message: "Failed to export DDUF")

      assert error.message == "Failed to export DDUF"
    end
  end

  describe "DDUFInvalidEntryName" do
    test "creates exception for invalid entry name" do
      error =
        Errors.DDUFInvalidEntryName.exception(
          message: "Invalid entry name",
          entry_name: "../escape/path"
        )

      assert error.message == "Invalid entry name"
      assert error.entry_name == "../escape/path"
    end
  end

  describe "XetError" do
    test "creates exception for Xet storage error" do
      error = Errors.XetError.exception(message: "Xet storage error")
      assert error.message == "Xet storage error"
    end
  end

  describe "XetAuthorization" do
    test "creates exception for Xet authorization error" do
      error = Errors.XetAuthorization.exception(message: "Not authorized to use Xet storage")

      assert error.message == "Not authorized to use Xet storage"
    end
  end

  describe "XetRefreshToken" do
    test "creates exception for Xet token refresh error" do
      error = Errors.XetRefreshToken.exception(message: "Failed to refresh Xet token")

      assert error.message == "Failed to refresh Xet token"
    end
  end

  describe "XetDownload" do
    test "creates exception for Xet download error" do
      error = Errors.XetDownload.exception(message: "Xet download failed")

      assert error.message == "Xet download failed"
    end
  end

  describe "all errors are proper Elixir exceptions" do
    test "CacheNotFound raises correctly" do
      assert_raise Errors.CacheNotFound, fn ->
        raise Errors.CacheNotFound, message: "test", cache_dir: "/tmp"
      end
    end

    test "RepositoryNotFound raises correctly" do
      assert_raise Errors.RepositoryNotFound, fn ->
        raise Errors.RepositoryNotFound, message: "test", repo_id: "x/y"
      end
    end

    test "HTTPError raises correctly" do
      assert_raise Errors.HTTPError, fn ->
        raise Errors.HTTPError, message: "test", status: 500
      end
    end

    test "DisabledRepo raises correctly" do
      assert_raise Errors.DisabledRepo, fn ->
        raise Errors.DisabledRepo, message: "disabled", repo_id: "x/y"
      end
    end

    test "BadRequest raises correctly" do
      assert_raise Errors.BadRequest, fn ->
        raise Errors.BadRequest, message: "bad", status: 400
      end
    end

    test "XetError raises correctly" do
      assert_raise Errors.XetError, fn ->
        raise Errors.XetError, message: "xet error"
      end
    end
  end
end
