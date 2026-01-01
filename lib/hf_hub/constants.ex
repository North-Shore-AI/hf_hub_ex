defmodule HfHub.Constants do
  @moduledoc """
  Constants for HuggingFace Hub operations.

  Provides file names, headers, timeouts, and other constants matching
  Python's `huggingface_hub.constants` module.
  """

  # File name constants

  @doc "PyTorch model weights filename"
  @spec pytorch_weights_name() :: String.t()
  def pytorch_weights_name, do: "pytorch_model.bin"

  @doc "TensorFlow 2.x model weights filename"
  @spec tf2_weights_name() :: String.t()
  def tf2_weights_name, do: "tf_model.h5"

  @doc "Flax/JAX model weights filename"
  @spec flax_weights_name() :: String.t()
  def flax_weights_name, do: "flax_model.msgpack"

  @doc "Model configuration filename"
  @spec config_name() :: String.t()
  def config_name, do: "config.json"

  @doc "Repository README card filename"
  @spec repocard_name() :: String.t()
  def repocard_name, do: "README.md"

  @doc "Safetensors single file model"
  @spec safetensors_single_file() :: String.t()
  def safetensors_single_file, do: "model.safetensors"

  @doc "Safetensors index file for sharded models"
  @spec safetensors_index_file() :: String.t()
  def safetensors_index_file, do: "model.safetensors.index.json"

  # Timeout constants (in seconds)

  @doc "Default timeout for ETag requests"
  @spec default_etag_timeout() :: pos_integer()
  def default_etag_timeout, do: 10

  @doc "Default timeout for downloads"
  @spec default_download_timeout() :: pos_integer()
  def default_download_timeout, do: 10

  @doc "Default timeout for general requests"
  @spec default_request_timeout() :: pos_integer()
  def default_request_timeout, do: 10

  # Size constants

  @doc "Download chunk size (10 MB)"
  @spec download_chunk_size() :: pos_integer()
  def download_chunk_size, do: 10 * 1024 * 1024

  @doc "Maximum safetensors header length (25 MB)"
  @spec safetensors_max_header_length() :: pos_integer()
  def safetensors_max_header_length, do: 25_000_000

  # Repository types

  @doc "Model repository type"
  @spec repo_type_model() :: String.t()
  def repo_type_model, do: "model"

  @doc "Dataset repository type"
  @spec repo_type_dataset() :: String.t()
  def repo_type_dataset, do: "dataset"

  @doc "Space repository type"
  @spec repo_type_space() :: String.t()
  def repo_type_space, do: "space"

  @doc "All supported repository types"
  @spec repo_types() :: [:model | :dataset | :space]
  def repo_types, do: [:model, :dataset, :space]

  @doc """
  Returns the URL prefix for a repository type.

  Models have no prefix; datasets use "datasets/"; spaces use "spaces/".
  """
  @spec repo_type_url_prefix(:model | :dataset | :space) :: String.t()
  def repo_type_url_prefix(:model), do: ""
  def repo_type_url_prefix(:dataset), do: "datasets/"
  def repo_type_url_prefix(:space), do: "spaces/"

  # HTTP headers

  @doc "Header for commit hash in responses"
  @spec header_x_repo_commit() :: String.t()
  def header_x_repo_commit, do: "X-Repo-Commit"

  @doc "Header for linked ETag"
  @spec header_x_linked_etag() :: String.t()
  def header_x_linked_etag, do: "X-Linked-Etag"

  @doc "Header for linked file size"
  @spec header_x_linked_size() :: String.t()
  def header_x_linked_size, do: "X-Linked-Size"

  # URL and revision constants

  @doc "Default HuggingFace Hub endpoint"
  @spec default_endpoint() :: String.t()
  def default_endpoint, do: "https://huggingface.co"

  @doc "Separator used in repo IDs for cache directories"
  @spec repo_id_separator() :: String.t()
  def repo_id_separator, do: "--"

  @doc "Default git revision"
  @spec default_revision() :: String.t()
  def default_revision, do: "main"
end
