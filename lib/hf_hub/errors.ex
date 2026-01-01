defmodule HfHub.Errors do
  @moduledoc """
  Custom error types for HuggingFace Hub operations.

  Provides structured exceptions matching Python's `huggingface_hub.errors` module.
  Each exception includes relevant context fields for debugging.
  """

  # credo:disable-for-this-file Credo.Check.Consistency.ExceptionNames

  defmodule CacheNotFound do
    @moduledoc """
    Exception raised when the HuggingFace cache directory is not found.
    """
    defexception [:message, :cache_dir]

    @impl true
    def message(%__MODULE__{message: message}), do: message
  end

  defmodule CorruptedCache do
    @moduledoc """
    Exception for unexpected structure in the HuggingFace cache.
    """
    defexception [:message]

    @impl true
    def message(%__MODULE__{message: message}), do: message
  end

  defmodule RepositoryNotFound do
    @moduledoc """
    Raised when trying to access an invalid repository or one without access.

    Can occur with:
    - Non-existent repository
    - Private repository without authentication
    - Incorrect repo_id format
    """
    defexception [:message, :repo_id, :repo_type, :request_id]

    @impl true
    def message(%__MODULE__{message: message}), do: message
  end

  defmodule RevisionNotFound do
    @moduledoc """
    Raised when trying to access a valid repository but invalid revision.
    """
    defexception [:message, :repo_id, :revision, :request_id]

    @impl true
    def message(%__MODULE__{message: message}), do: message
  end

  defmodule EntryNotFound do
    @moduledoc """
    Raised when a file or entry is not found in a repository.

    Can be raised for both remote (Hub) and local (cache) entries.
    """
    defexception [:message, :repo_id, :path, :revision, :request_id]

    @impl true
    def message(%__MODULE__{message: message}), do: message
  end

  defmodule GatedRepo do
    @moduledoc """
    Raised when trying to access a gated repository without authorization.

    User must accept terms on the Hub website to gain access.
    """
    defexception [:message, :repo_id, :request_id]

    @impl true
    def message(%__MODULE__{message: message}), do: message
  end

  defmodule OfflineMode do
    @moduledoc """
    Raised when a network request is attempted with HF_HUB_OFFLINE=1.
    """
    defexception [:message]

    @impl true
    def message(%__MODULE__{message: message}), do: message
  end

  defmodule HTTPError do
    @moduledoc """
    Base HTTP error with request and response context.

    Stores metadata like request_id and server_message for debugging.
    """
    defexception [:message, :status, :request_id, :server_message, :response]

    @impl true
    def message(%__MODULE__{message: message}), do: message

    @doc """
    Appends additional context to the error message.

    Returns a new HTTPError with the updated message.
    """
    @spec append_to_message(%__MODULE__{}, String.t()) :: %__MODULE__{}
    def append_to_message(%__MODULE__{} = error, additional) do
      %{error | message: error.message <> additional}
    end
  end

  defmodule LocalTokenNotFound do
    @moduledoc """
    Raised when a local token is required but not found.
    """
    defexception [:message]

    @impl true
    def message(%__MODULE__{message: message}), do: message
  end

  # HTTP Error Extensions

  defmodule DisabledRepo do
    @moduledoc """
    Raised when trying to access a repository disabled by its author.
    """
    defexception [:message, :repo_id, :request_id]

    @impl true
    def message(%__MODULE__{message: message}), do: message
  end

  defmodule RemoteEntryNotFound do
    @moduledoc """
    Raised when a file is not found on the remote Hub.

    This is the HTTP error variant - the file doesn't exist remotely.
    """
    defexception [:message, :repo_id, :path, :revision, :request_id]

    @impl true
    def message(%__MODULE__{message: message}), do: message
  end

  defmodule LocalEntryNotFound do
    @moduledoc """
    Raised when a file is not found in the local cache.

    This occurs when network is disabled and the file isn't cached.
    """
    defexception [:message, :path]

    @impl true
    def message(%__MODULE__{message: message}), do: message
  end

  defmodule BadRequest do
    @moduledoc """
    Raised for HTTP 400 Bad Request errors.
    """
    defexception [:message, :status, :request_id, :server_message]

    @impl true
    def message(%__MODULE__{message: message}), do: message
  end

  # Inference Errors

  defmodule InferenceTimeout do
    @moduledoc """
    Raised when a model is unavailable or the request times out.
    """
    defexception [:message]

    @impl true
    def message(%__MODULE__{message: message}), do: message
  end

  defmodule InferenceEndpointError do
    @moduledoc """
    Generic exception when dealing with Inference Endpoints.
    """
    defexception [:message]

    @impl true
    def message(%__MODULE__{message: message}), do: message
  end

  defmodule InferenceEndpointTimeout do
    @moduledoc """
    Exception for timeouts while waiting for Inference Endpoint.
    """
    defexception [:message]

    @impl true
    def message(%__MODULE__{message: message}), do: message
  end

  # Safetensors Errors

  defmodule SafetensorsParsing do
    @moduledoc """
    Raised when failing to parse a safetensors file metadata.

    This can occur if the file is not a safetensors file or doesn't
    respect the specification.
    """
    defexception [:message]

    @impl true
    def message(%__MODULE__{message: message}), do: message
  end

  defmodule NotASafetensorsRepo do
    @moduledoc """
    Raised when a repo lacks safetensors files.

    A safetensors repo should have either `model.safetensors` or
    `model.safetensors.index.json`.
    """
    defexception [:message, :repo_id]

    @impl true
    def message(%__MODULE__{message: message}), do: message
  end

  # Text Generation Errors

  defmodule TextGeneration do
    @moduledoc """
    Generic error raised if text-generation went wrong.
    """
    defexception [:message]

    @impl true
    def message(%__MODULE__{message: message}), do: message
  end

  defmodule TextGenerationValidation do
    @moduledoc """
    Server-side validation error during text generation.
    """
    defexception [:message]

    @impl true
    def message(%__MODULE__{message: message}), do: message
  end

  defmodule TextGenerationOverloaded do
    @moduledoc """
    Raised when the text generation server is overloaded.
    """
    defexception [:message]

    @impl true
    def message(%__MODULE__{message: message}), do: message
  end

  defmodule TextGenerationIncomplete do
    @moduledoc """
    Raised when text generation is incomplete.
    """
    defexception [:message]

    @impl true
    def message(%__MODULE__{message: message}), do: message
  end

  # Validation Errors

  defmodule HFValidation do
    @moduledoc """
    Generic exception thrown by `huggingface_hub` validators.

    Inherits behavior similar to Python's `ValueError`.
    """
    defexception [:message]

    @impl true
    def message(%__MODULE__{message: message}), do: message
  end

  # File Metadata Errors

  defmodule DryRun do
    @moduledoc """
    Error triggered when a dry run cannot be performed.
    """
    defexception [:message]

    @impl true
    def message(%__MODULE__{message: message}), do: message
  end

  defmodule FileMetadata do
    @moduledoc """
    Error triggered when file metadata cannot be retrieved.

    This happens when ETag or commit_hash is missing from response.
    """
    defexception [:message, :url]

    @impl true
    def message(%__MODULE__{message: message}), do: message
  end

  # DDUF Format Errors

  defmodule DDUFError do
    @moduledoc """
    Base exception for errors related to the DDUF format.
    """
    defexception [:message]

    @impl true
    def message(%__MODULE__{message: message}), do: message
  end

  defmodule DDUFCorruptedFile do
    @moduledoc """
    Exception thrown when the DDUF file is corrupted.
    """
    defexception [:message]

    @impl true
    def message(%__MODULE__{message: message}), do: message
  end

  defmodule DDUFExport do
    @moduledoc """
    Exception for errors during DDUF export.
    """
    defexception [:message]

    @impl true
    def message(%__MODULE__{message: message}), do: message
  end

  defmodule DDUFInvalidEntryName do
    @moduledoc """
    Exception thrown when the DDUF entry name is invalid.
    """
    defexception [:message, :entry_name]

    @impl true
    def message(%__MODULE__{message: message}), do: message
  end

  # Xet Storage Errors

  defmodule XetError do
    @moduledoc """
    Base exception for errors related to Xet Storage.
    """
    defexception [:message]

    @impl true
    def message(%__MODULE__{message: message}), do: message
  end

  defmodule XetAuthorization do
    @moduledoc """
    Exception when user lacks authorization to use Xet Storage.
    """
    defexception [:message]

    @impl true
    def message(%__MODULE__{message: message}), do: message
  end

  defmodule XetRefreshToken do
    @moduledoc """
    Exception when the Xet refresh token is invalid.
    """
    defexception [:message]

    @impl true
    def message(%__MODULE__{message: message}), do: message
  end

  defmodule XetDownload do
    @moduledoc """
    Exception when download from Xet Storage fails.
    """
    defexception [:message]

    @impl true
    def message(%__MODULE__{message: message}), do: message
  end
end
