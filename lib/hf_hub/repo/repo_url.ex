defmodule HfHub.Repo.RepoUrl do
  @moduledoc """
  Repository URL returned from create/move operations.
  """

  @derive Jason.Encoder
  defstruct [:url, :repo_id, :repo_type]

  @type t :: %__MODULE__{
          url: String.t(),
          repo_id: String.t(),
          repo_type: :model | :dataset | :space
        }

  @doc """
  Create a RepoUrl struct from an API response.
  """
  def from_response(response, repo_type) do
    %__MODULE__{
      url: response["url"],
      repo_id: response["repo_id"] || extract_repo_id_from_url(response["url"]),
      repo_type: repo_type
    }
  end

  defp extract_repo_id_from_url(url) when is_binary(url) do
    uri = URI.parse(url)
    path_parts = String.split(uri.path, "/", trim: true)

    # URL format: .../org/repo_name or .../user/repo_name
    # Often it is https://huggingface.co/org/repo_name
    # Or https://huggingface.co/datasets/org/repo_name
    # Or https://huggingface.co/spaces/org/repo_name

    case path_parts do
      ["datasets", org, name] -> "#{org}/#{name}"
      ["spaces", org, name] -> "#{org}/#{name}"
      [org, name] -> "#{org}/#{name}"
      # Fallback or error? For now nil.
      _ -> nil
    end
  end

  defp extract_repo_id_from_url(_), do: nil
end
