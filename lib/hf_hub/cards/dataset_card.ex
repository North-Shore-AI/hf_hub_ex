defmodule HfHub.Cards.DatasetCard do
  @moduledoc """
  Represents a Dataset Card from a HuggingFace Hub repository.

  A Dataset Card consists of YAML frontmatter (metadata) and markdown content.
  """

  alias HfHub.Cards.DatasetCardData

  defstruct [:data, :content]

  @type t :: %__MODULE__{
          data: DatasetCardData.t(),
          content: String.t()
        }
end
