defmodule HfHub.LFS do
  @moduledoc """
  LFS (Large File Storage) utilities for HuggingFace Hub.

  Provides functionality for calculating file hashes and preparing
  upload information for the LFS protocol.

  Based on Python's `huggingface_hub.lfs` module.
  """

  defmodule UploadInfo do
    @moduledoc """
    Information required to determine upload method for a file.

    Contains:
    - `sha256` - SHA256 hash of the file content (binary)
    - `size` - Total file size in bytes
    - `sample` - First 512 bytes of the file (for content detection)
    """
    defstruct [:sha256, :size, :sample]

    @type t :: %__MODULE__{
            sha256: binary(),
            size: non_neg_integer(),
            sample: binary()
          }

    @doc """
    Creates UploadInfo from a file path.

    Reads the file to calculate SHA256 hash and captures the first 512 bytes.
    """
    @spec from_path(Path.t()) :: t()
    def from_path(path) do
      {:ok, %{size: size}} = File.stat(path)
      sha256 = hash_file(path)
      sample = read_sample(path)

      %__MODULE__{
        sha256: sha256,
        size: size,
        sample: sample
      }
    end

    @doc """
    Creates UploadInfo from binary data.

    Calculates SHA256 hash on the binary directly.
    """
    @spec from_binary(binary()) :: t()
    def from_binary(data) when is_binary(data) do
      sha256 = :crypto.hash(:sha256, data)
      size = byte_size(data)
      sample = if size > 512, do: binary_part(data, 0, 512), else: data

      %__MODULE__{
        sha256: sha256,
        size: size,
        sample: sample
      }
    end

    defp hash_file(path) do
      File.stream!(path, 64 * 1024)
      |> Enum.reduce(:crypto.hash_init(:sha256), &:crypto.hash_update(&2, &1))
      |> :crypto.hash_final()
    end

    defp read_sample(path) do
      case File.open(path, [:read, :binary]) do
        {:ok, file} ->
          sample = IO.binread(file, 512)
          File.close(file)

          case sample do
            :eof -> <<>>
            data -> data
          end

        {:error, _} ->
          <<>>
      end
    end
  end

  @doc """
  Converts UploadInfo sha256 to lowercase hex string.
  """
  @spec sha256_hex(UploadInfo.t()) :: String.t()
  def sha256_hex(%UploadInfo{sha256: sha256}) do
    Base.encode16(sha256, case: :lower)
  end

  @doc """
  Returns the LFS OID (object identifier) for upload info.

  The OID is the lowercase hex representation of the SHA256 hash.
  """
  @spec oid(UploadInfo.t()) :: String.t()
  def oid(%UploadInfo{} = info) do
    sha256_hex(info)
  end

  @doc """
  Returns the standard LFS headers for API requests.
  """
  @spec lfs_headers() :: [{String.t(), String.t()}]
  def lfs_headers do
    [
      {"Accept", "application/vnd.git-lfs+json"},
      {"Content-Type", "application/vnd.git-lfs+json"}
    ]
  end
end
