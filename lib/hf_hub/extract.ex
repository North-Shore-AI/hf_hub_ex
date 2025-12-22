defmodule HfHub.Extract do
  @moduledoc """
  Archive detection and extraction utilities.
  """

  @type archive_type :: :zip | :tar | :tar_gz | :tar_xz | :gz

  @doc """
  Detects the archive type from a path.
  """
  @spec detect_archive_type(Path.t()) :: archive_type() | nil
  def detect_archive_type(path) when is_binary(path) do
    down = String.downcase(path)

    cond do
      String.ends_with?(down, ".tar.gz") -> :tar_gz
      String.ends_with?(down, ".tgz") -> :tar_gz
      String.ends_with?(down, ".tar.xz") -> :tar_xz
      String.ends_with?(down, ".tar") -> :tar
      String.ends_with?(down, ".zip") -> :zip
      String.ends_with?(down, ".gz") -> :gz
      true -> nil
    end
  end

  @doc """
  Returns the default extraction path for an archive.

  For gzip files, this is the target file path.
  For other archives, this is a directory path.
  """
  @spec default_extract_path(Path.t()) :: Path.t()
  def default_extract_path(path) when is_binary(path) do
    case detect_archive_type(path) do
      :tar_gz -> strip_suffix(path, [".tar.gz", ".tgz"])
      :tar_xz -> strip_suffix(path, ".tar.xz")
      :tar -> strip_suffix(path, ".tar")
      :zip -> strip_suffix(path, ".zip")
      :gz -> strip_suffix(path, ".gz")
      nil -> path
    end
  end

  @doc """
  Extracts an archive to the destination path.

  For gzip files, `dest` is the output file path. For other archive types,
  `dest` is the destination directory.
  """
  @spec extract(Path.t(), Path.t()) :: {:ok, Path.t()} | {:error, term()}
  def extract(path, dest) when is_binary(path) and is_binary(dest) do
    case detect_archive_type(path) do
      :zip -> extract_zip(path, dest)
      :tar -> extract_tar(path, dest, [])
      :tar_gz -> extract_tar(path, dest, [:compressed])
      :tar_xz -> extract_tar_xz(path, dest)
      :gz -> extract_gz(path, dest)
      nil -> {:error, :not_archive}
    end
  end

  defp extract_zip(path, dest) do
    with :ok <- File.mkdir_p(dest),
         {:ok, _files} <-
           :zip.extract(to_charlist(path), cwd: to_charlist(dest)) do
      {:ok, dest}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp extract_tar(path, dest, options) do
    with :ok <- File.mkdir_p(dest),
         :ok <- :erl_tar.extract(to_charlist(path), options ++ [{:cwd, to_charlist(dest)}]) do
      {:ok, dest}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp extract_tar_xz(path, dest) do
    case System.find_executable("tar") do
      nil ->
        {:error, :tar_not_found}

      _ ->
        with :ok <- File.mkdir_p(dest),
             {_, 0} <- System.cmd("tar", ["-xJf", path, "-C", dest]) do
          {:ok, dest}
        else
          {:error, reason} ->
            {:error, reason}

          {error, status} when is_integer(status) ->
            {:error, {:tar_failed, status, error}}
        end
    end
  end

  defp extract_gz(path, dest) do
    with :ok <- File.mkdir_p(Path.dirname(dest)),
         {:ok, compressed} <- File.read(path),
         decompressed <- :zlib.gunzip(compressed),
         :ok <- File.write(dest, decompressed) do
      {:ok, dest}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp strip_suffix(path, suffixes) when is_list(suffixes) do
    Enum.reduce_while(suffixes, path, fn suffix, _acc ->
      if String.ends_with?(path, suffix) do
        {:halt, strip_suffix(path, suffix)}
      else
        {:cont, path}
      end
    end)
  end

  defp strip_suffix(path, suffix) do
    if String.ends_with?(path, suffix) do
      String.slice(path, 0, byte_size(path) - byte_size(suffix))
    else
      path
    end
  end
end
