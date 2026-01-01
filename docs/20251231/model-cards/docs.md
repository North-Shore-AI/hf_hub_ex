# Model & Dataset Cards

## Overview

Model and Dataset Cards provide structured metadata in YAML frontmatter format, used for documentation and discoverability on the Hub.

## Python Reference

### Source Files
- `huggingface_hub/src/huggingface_hub/_model_cards.py`
- `huggingface_hub/src/huggingface_hub/repocard.py`
- `huggingface_hub/src/huggingface_hub/repocard_data.py`

### Card Structure

Cards consist of:
1. **YAML Frontmatter** - Structured metadata between `---` markers
2. **Markdown Content** - Free-form documentation

Example:
```markdown
---
language: en
license: mit
tags:
  - text-classification
  - bert
datasets:
  - glue
metrics:
  - accuracy
model-index:
  - name: BERT Base
    results:
      - task:
          type: text-classification
        dataset:
          name: GLUE
          type: glue
        metrics:
          - name: Accuracy
            type: accuracy
            value: 0.92
---

# BERT Base

This model is a fine-tuned version of BERT...
```

### ModelCard Class

```python
class ModelCard:
    content: str
    data: ModelCardData

    @classmethod
    def load(cls, repo_id_or_path: str, ...) -> "ModelCard"

    def push_to_hub(self, repo_id: str, ...)

    @classmethod
    def from_template(cls, card_data: ModelCardData, ...) -> "ModelCard"
```

### ModelCardData

```python
@dataclass
class ModelCardData:
    language: Optional[Union[str, List[str]]]
    license: Optional[str]
    license_name: Optional[str]
    license_link: Optional[str]
    library_name: Optional[str]
    tags: Optional[List[str]]
    datasets: Optional[List[str]]
    metrics: Optional[List[str]]
    eval_results: Optional[List[EvalResult]]
    model_name: Optional[str]
    base_model: Optional[Union[str, List[str]]]
    pipeline_tag: Optional[str]
    # ... many more fields
```

### DatasetCard Class

Similar structure to ModelCard but with dataset-specific fields:

```python
@dataclass
class DatasetCardData:
    language: Optional[Union[str, List[str]]]
    license: Optional[str]
    annotations_creators: Optional[List[str]]
    language_creators: Optional[List[str]]
    multilinguality: Optional[str]
    size_categories: Optional[List[str]]
    source_datasets: Optional[List[str]]
    task_categories: Optional[List[str]]
    task_ids: Optional[List[str]]
    configs: Optional[List[Dict]]
    # ... more fields
```

---

## Elixir Implementation Spec

### Module: `HfHub.Cards`

```elixir
defmodule HfHub.Cards do
  @moduledoc """
  Model and Dataset card parsing and creation.
  """

  alias HfHub.Cards.{ModelCard, DatasetCard, CardData}

  @doc """
  Loads a model card from a repository.

  ## Examples

      {:ok, card} = HfHub.Cards.load_model_card("bert-base-uncased")
      card.data.license  # "apache-2.0"
  """
  @spec load_model_card(String.t(), keyword()) ::
    {:ok, ModelCard.t()} | {:error, term()}
  def load_model_card(repo_id, opts \\ [])

  @doc """
  Loads a dataset card from a repository.
  """
  @spec load_dataset_card(String.t(), keyword()) ::
    {:ok, DatasetCard.t()} | {:error, term()}
  def load_dataset_card(repo_id, opts \\ [])

  @doc """
  Parses a card from markdown content.

  ## Examples

      {:ok, card} = HfHub.Cards.parse_model_card(readme_content)
  """
  @spec parse_model_card(String.t()) :: {:ok, ModelCard.t()} | {:error, term()}
  def parse_model_card(content)

  @spec parse_dataset_card(String.t()) :: {:ok, DatasetCard.t()} | {:error, term()}
  def parse_dataset_card(content)

  @doc """
  Creates a model card from data.

  ## Examples

      card = HfHub.Cards.create_model_card(%{
        language: "en",
        license: "mit",
        tags: ["text-classification"]
      })
  """
  @spec create_model_card(CardData.model_card_data()) :: ModelCard.t()
  def create_model_card(data)

  @spec create_dataset_card(CardData.dataset_card_data()) :: DatasetCard.t()
  def create_dataset_card(data)

  @doc """
  Renders a card to markdown string.
  """
  @spec render(ModelCard.t() | DatasetCard.t()) :: String.t()
  def render(card)
end
```

### Data Structures

```elixir
defmodule HfHub.Cards.ModelCard do
  defstruct [:data, :content]

  @type t :: %__MODULE__{
    data: HfHub.Cards.ModelCardData.t(),
    content: String.t()
  }
end

defmodule HfHub.Cards.ModelCardData do
  defstruct [
    :language,
    :license,
    :license_name,
    :license_link,
    :library_name,
    :tags,
    :datasets,
    :metrics,
    :eval_results,
    :model_name,
    :base_model,
    :pipeline_tag,
    :widget,
    :inference,
    :co2_eq_emissions,
    :extra
  ]

  @type t :: %__MODULE__{
    language: String.t() | [String.t()] | nil,
    license: String.t() | nil,
    license_name: String.t() | nil,
    license_link: String.t() | nil,
    library_name: String.t() | nil,
    tags: [String.t()] | nil,
    datasets: [String.t()] | nil,
    metrics: [String.t()] | nil,
    eval_results: [HfHub.Cards.EvalResult.t()] | nil,
    model_name: String.t() | nil,
    base_model: String.t() | [String.t()] | nil,
    pipeline_tag: String.t() | nil,
    widget: [map()] | nil,
    inference: boolean() | map() | nil,
    co2_eq_emissions: map() | nil,
    extra: map()
  }
end

defmodule HfHub.Cards.EvalResult do
  defstruct [:task_type, :task_name, :dataset_type, :dataset_name,
             :dataset_config, :dataset_split, :metric_type,
             :metric_name, :metric_value, :verified]

  @type t :: %__MODULE__{
    task_type: String.t(),
    task_name: String.t() | nil,
    dataset_type: String.t(),
    dataset_name: String.t(),
    dataset_config: String.t() | nil,
    dataset_split: String.t() | nil,
    metric_type: String.t(),
    metric_name: String.t() | nil,
    metric_value: number(),
    verified: boolean()
  }
end

defmodule HfHub.Cards.DatasetCard do
  defstruct [:data, :content]

  @type t :: %__MODULE__{
    data: HfHub.Cards.DatasetCardData.t(),
    content: String.t()
  }
end

defmodule HfHub.Cards.DatasetCardData do
  defstruct [
    :language,
    :license,
    :annotations_creators,
    :language_creators,
    :multilinguality,
    :size_categories,
    :source_datasets,
    :task_categories,
    :task_ids,
    :pretty_name,
    :configs,
    :tags,
    :extra
  ]

  @type t :: %__MODULE__{
    language: String.t() | [String.t()] | nil,
    license: String.t() | nil,
    annotations_creators: [String.t()] | nil,
    language_creators: [String.t()] | nil,
    multilinguality: String.t() | nil,
    size_categories: [String.t()] | nil,
    source_datasets: [String.t()] | nil,
    task_categories: [String.t()] | nil,
    task_ids: [String.t()] | nil,
    pretty_name: String.t() | nil,
    configs: [map()] | nil,
    tags: [String.t()] | nil,
    extra: map()
  }
end
```

### Module: `HfHub.Cards.Parser`

```elixir
defmodule HfHub.Cards.Parser do
  @moduledoc """
  YAML frontmatter parser for cards.
  """

  @doc """
  Extracts YAML frontmatter from markdown.

  Returns `{frontmatter_map, remaining_content}`.
  """
  @spec extract_frontmatter(String.t()) ::
    {:ok, {map(), String.t()}} | {:error, term()}
  def extract_frontmatter(markdown)

  @doc """
  Serializes data to YAML frontmatter.
  """
  @spec to_frontmatter(map()) :: String.t()
  def to_frontmatter(data)
end
```

---

## Test Scenarios

1. Load model card from repo
2. Load dataset card from repo
3. Parse card with frontmatter
4. Parse card without frontmatter
5. Parse complex eval_results
6. Parse multiple languages
7. Create card from data
8. Render card to markdown
9. Handle unknown fields (extra)
10. Handle malformed YAML
11. Handle empty frontmatter
12. Parse model-index section
