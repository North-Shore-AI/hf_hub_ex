defmodule HfHub.Cards.ModelCard do
  @moduledoc """
  Represents a Model Card from a HuggingFace Hub repository.

  A Model Card consists of YAML frontmatter (metadata) and markdown content.
  """

  alias HfHub.Cards.ModelCardData

  defstruct [:data, :content]

  @type t :: %__MODULE__{
          data: ModelCardData.t(),
          content: String.t()
        }
end
