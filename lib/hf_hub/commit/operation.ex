defmodule HfHub.Commit.Operation do
  @moduledoc """
  Commit operation types for file manipulation.

  Operations represent changes to be made in a single commit:
  - `Add` - Upload or update a file
  - `Delete` - Remove a file or folder
  - `Copy` - Copy an existing LFS file (efficient, no re-upload)

  ## Examples

      # Add a file from disk
      add_op = HfHub.Commit.Operation.add("model.bin", "/path/to/model.bin")

      # Add from binary content
      add_op = HfHub.Commit.Operation.add("config.json", ~s({"hidden_size": 768}))

      # Delete a file
      del_op = HfHub.Commit.Operation.delete("old_model.bin")

      # Delete a folder
      del_op = HfHub.Commit.Operation.delete("old_weights/", is_folder: true)

      # Copy an LFS file
      copy_op = HfHub.Commit.Operation.copy("v1/model.bin", "v2/model.bin")
  """

  alias HfHub.LFS.UploadInfo

  @type t :: add() | delete() | copy()
  @type add :: %__MODULE__.Add{}
  @type delete :: %__MODULE__.Delete{}
  @type copy :: %__MODULE__.Copy{}

  defmodule Add do
    @moduledoc "Operation to add or update a file."

    defstruct [
      :path_in_repo,
      :content,
      :upload_info,
      upload_mode: nil,
      is_uploaded: false,
      is_committed: false
    ]

    @type content_source :: binary() | Path.t()
    @type upload_mode :: :regular | :lfs | nil

    @type t :: %__MODULE__{
            path_in_repo: String.t(),
            content: content_source(),
            upload_info: HfHub.LFS.UploadInfo.t() | nil,
            upload_mode: upload_mode(),
            is_uploaded: boolean(),
            is_committed: boolean()
          }
  end

  defmodule Delete do
    @moduledoc "Operation to delete a file or folder."

    defstruct [:path_in_repo, is_folder: false]

    @type t :: %__MODULE__{
            path_in_repo: String.t(),
            is_folder: boolean()
          }
  end

  defmodule Copy do
    @moduledoc "Operation to copy an existing LFS file."

    defstruct [:src_path, :dst_path, :src_revision]

    @type t :: %__MODULE__{
            src_path: String.t(),
            dst_path: String.t(),
            src_revision: String.t() | nil
          }
  end

  @doc """
  Creates an add operation from a file path or binary content.

  Automatically computes UploadInfo (SHA256, size, sample) for the content.

  ## Options

  - `:upload_info` - Pre-computed upload info (skips computation)

  ## Examples

      # From file path
      op = Operation.add("model.safetensors", "/path/to/model.safetensors")

      # From binary
      op = Operation.add("config.json", Jason.encode!(%{hidden_size: 768}))
  """
  @spec add(String.t(), binary() | Path.t(), keyword()) :: Add.t()
  def add(path_in_repo, content, opts \\ []) do
    validate_path!(path_in_repo)

    upload_info = opts[:upload_info] || compute_upload_info(content)

    %Add{
      path_in_repo: normalize_path(path_in_repo),
      content: content,
      upload_info: upload_info
    }
  end

  @doc """
  Creates a delete operation.

  ## Options

  - `:is_folder` - Set to true to delete a folder and contents

  ## Examples

      Operation.delete("old_model.bin")
      Operation.delete("old_weights/", is_folder: true)
  """
  @spec delete(String.t(), keyword()) :: Delete.t()
  def delete(path_in_repo, opts \\ []) do
    validate_path!(path_in_repo)

    %Delete{
      path_in_repo: normalize_path(path_in_repo),
      is_folder: opts[:is_folder] || false
    }
  end

  @doc """
  Creates a copy operation for an existing LFS file.

  Copy operations are efficient because they don't re-upload the file content.
  The file must already exist in the repository (or at src_revision).

  ## Options

  - `:src_revision` - Source revision (default: current HEAD)

  ## Examples

      Operation.copy("v1/model.bin", "v2/model.bin")
      Operation.copy("model.bin", "archive/model.bin", src_revision: "v1.0")
  """
  @spec copy(String.t(), String.t(), keyword()) :: Copy.t()
  def copy(src_path, dst_path, opts \\ []) do
    validate_path!(src_path)
    validate_path!(dst_path)

    %Copy{
      src_path: normalize_path(src_path),
      dst_path: normalize_path(dst_path),
      src_revision: opts[:src_revision]
    }
  end

  @doc """
  Checks if content is from a file path vs binary data.
  """
  @spec file_path?(Add.t()) :: boolean()
  def file_path?(%Add{content: content}) when is_binary(content) do
    File.exists?(content) && File.regular?(content)
  end

  @doc """
  Gets the content as binary (reads file if path).
  """
  @spec get_content(Add.t()) :: {:ok, binary()} | {:error, term()}
  def get_content(%Add{content: content} = add_op) do
    if file_path?(add_op) do
      File.read(content)
    else
      {:ok, content}
    end
  end

  @doc """
  Gets base64-encoded content (for regular uploads).
  """
  @spec base64_content(Add.t()) :: {:ok, String.t()} | {:error, term()}
  def base64_content(add_op) do
    with {:ok, content} <- get_content(add_op) do
      {:ok, Base.encode64(content)}
    end
  end

  # Private functions

  defp validate_path!(path) do
    cond do
      String.starts_with?(path, "/") ->
        raise ArgumentError, "path_in_repo cannot start with '/': #{path}"

      String.contains?(path, "..") ->
        raise ArgumentError, "path_in_repo cannot contain '..': #{path}"

      String.contains?(path, "//") ->
        raise ArgumentError, "path_in_repo cannot contain '//': #{path}"

      true ->
        :ok
    end
  end

  defp normalize_path(path) do
    path
    |> String.trim_leading("./")
    |> String.replace(~r/\/+/, "/")
  end

  defp compute_upload_info(content) when is_binary(content) do
    if File.exists?(content) && File.regular?(content) do
      UploadInfo.from_path(content)
    else
      UploadInfo.from_binary(content)
    end
  end
end
