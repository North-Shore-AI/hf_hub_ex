defmodule HfHub.CardsTest do
  use ExUnit.Case, async: true

  alias HfHub.Cards
  alias HfHub.Cards.{DatasetCard, DatasetCardData, EvalResult, ModelCard, ModelCardData}

  describe "parse_model_card/1" do
    test "parses card with full frontmatter" do
      content = """
      ---
      language: en
      license: mit
      license_name: MIT License
      library_name: transformers
      tags:
        - text-classification
        - bert
      datasets:
        - glue
      metrics:
        - accuracy
      model_name: My BERT Model
      base_model: bert-base-uncased
      pipeline_tag: text-classification
      ---

      # My Model

      This is a great model.
      """

      assert {:ok, %ModelCard{} = card} = Cards.parse_model_card(content)
      assert %ModelCardData{} = card.data
      assert card.data.language == "en"
      assert card.data.license == "mit"
      assert card.data.license_name == "MIT License"
      assert card.data.library_name == "transformers"
      assert card.data.tags == ["text-classification", "bert"]
      assert card.data.datasets == ["glue"]
      assert card.data.metrics == ["accuracy"]
      assert card.data.model_name == "My BERT Model"
      assert card.data.base_model == "bert-base-uncased"
      assert card.data.pipeline_tag == "text-classification"
      assert card.content == "# My Model\n\nThis is a great model."
    end

    test "parses card without frontmatter" do
      content = """
      # My Model

      No frontmatter here.
      """

      assert {:ok, %ModelCard{} = card} = Cards.parse_model_card(content)
      assert card.data.language == nil
      assert card.data.license == nil
      assert card.content =~ "# My Model"
    end

    test "parses card with empty frontmatter" do
      content = """
      ---
      ---

      # My Model
      """

      assert {:ok, %ModelCard{} = card} = Cards.parse_model_card(content)
      assert card.data.language == nil
      assert card.content == "# My Model"
    end

    test "parses card with multiple languages" do
      content = """
      ---
      language:
        - en
        - fr
        - de
      ---
      """

      assert {:ok, %ModelCard{} = card} = Cards.parse_model_card(content)
      assert card.data.language == ["en", "fr", "de"]
    end

    test "parses card with model-name key (hyphenated)" do
      content = """
      ---
      model-name: BERT Base
      ---
      """

      assert {:ok, %ModelCard{} = card} = Cards.parse_model_card(content)
      assert card.data.model_name == "BERT Base"
    end

    test "stores extra fields" do
      content = """
      ---
      license: mit
      custom_field: custom_value
      another_field: another_value
      ---
      """

      assert {:ok, %ModelCard{} = card} = Cards.parse_model_card(content)
      assert card.data.license == "mit"
      assert card.data.extra["custom_field"] == "custom_value"
      assert card.data.extra["another_field"] == "another_value"
    end
  end

  describe "parse_dataset_card/1" do
    test "parses card with dataset-specific fields" do
      content = """
      ---
      language: en
      license: cc-by-4.0
      annotations_creators:
        - crowdsourced
      language_creators:
        - found
      multilinguality: monolingual
      size_categories:
        - 10K<n<100K
      source_datasets:
        - original
      task_categories:
        - question-answering
      task_ids:
        - extractive-qa
      pretty_name: My Dataset
      tags:
        - benchmark
      ---

      # Dataset Description
      """

      assert {:ok, %DatasetCard{} = card} = Cards.parse_dataset_card(content)
      assert %DatasetCardData{} = card.data
      assert card.data.language == "en"
      assert card.data.license == "cc-by-4.0"
      assert card.data.annotations_creators == ["crowdsourced"]
      assert card.data.language_creators == ["found"]
      assert card.data.multilinguality == "monolingual"
      assert card.data.size_categories == ["10K<n<100K"]
      assert card.data.source_datasets == ["original"]
      assert card.data.task_categories == ["question-answering"]
      assert card.data.task_ids == ["extractive-qa"]
      assert card.data.pretty_name == "My Dataset"
      assert card.data.tags == ["benchmark"]
    end
  end

  describe "create_model_card/1" do
    test "creates card from map" do
      card =
        Cards.create_model_card(%{
          language: "en",
          license: "mit",
          tags: ["nlp"]
        })

      assert %ModelCard{} = card
      assert card.data.language == "en"
      assert card.data.license == "mit"
      assert card.data.tags == ["nlp"]
      assert card.content == ""
    end

    test "creates card from keyword list" do
      card =
        Cards.create_model_card(
          language: "en",
          license: "apache-2.0"
        )

      assert %ModelCard{} = card
      assert card.data.language == "en"
      assert card.data.license == "apache-2.0"
    end
  end

  describe "create_dataset_card/1" do
    test "creates card from map" do
      card =
        Cards.create_dataset_card(%{
          language: ["en", "fr"],
          license: "cc0-1.0",
          task_categories: ["text-classification"]
        })

      assert %DatasetCard{} = card
      assert card.data.language == ["en", "fr"]
      assert card.data.license == "cc0-1.0"
      assert card.data.task_categories == ["text-classification"]
    end
  end

  describe "render/1" do
    test "renders model card to markdown" do
      card =
        Cards.create_model_card(%{
          license: "mit",
          language: "en"
        })

      markdown = Cards.render(card)
      assert markdown =~ "---"
      assert markdown =~ "license: mit"
      assert markdown =~ "language: en"
    end

    test "renders card with list values" do
      card =
        Cards.create_model_card(%{
          language: "en",
          tags: ["bert", "nlp"]
        })

      markdown = Cards.render(card)
      assert markdown =~ "tags:"
      assert markdown =~ "  - bert"
      assert markdown =~ "  - nlp"
    end

    test "renders card without frontmatter when data is empty" do
      card = %ModelCard{
        data: %ModelCardData{extra: %{}},
        content: "# My Model"
      }

      markdown = Cards.render(card)
      assert markdown == "# My Model"
    end

    test "renders card with content" do
      card =
        Cards.create_model_card(%{
          license: "mit"
        })

      card = %{card | content: "# My Model\n\nDescription here."}
      markdown = Cards.render(card)
      assert markdown =~ "# My Model"
      assert markdown =~ "Description here."
    end
  end

  describe "extract_frontmatter/1" do
    test "extracts frontmatter and body" do
      content = """
      ---
      key: value
      ---

      Body content
      """

      assert {:ok, {frontmatter, body}} = Cards.extract_frontmatter(content)
      assert frontmatter["key"] == "value"
      assert body == "Body content"
    end

    test "handles Windows line endings" do
      content = "---\r\nkey: value\r\n---\r\n\r\nBody"

      assert {:ok, {frontmatter, body}} = Cards.extract_frontmatter(content)
      assert frontmatter["key"] == "value"
      assert body == "Body"
    end

    test "returns empty map when no frontmatter" do
      content = "# Just a title\n\nNo frontmatter."

      assert {:ok, {frontmatter, body}} = Cards.extract_frontmatter(content)
      assert frontmatter == %{}
      assert body =~ "# Just a title"
    end
  end

  describe "EvalResult.from_map/1" do
    test "parses nested format" do
      data = %{
        "task" => %{"type" => "text-classification", "name" => "Text Classification"},
        "dataset" => %{
          "type" => "glue",
          "name" => "GLUE",
          "config" => "sst2",
          "split" => "test"
        },
        "metrics" => [
          %{"type" => "accuracy", "name" => "Accuracy", "value" => 0.92}
        ],
        "verified" => true
      }

      result = EvalResult.from_map(data)
      assert result.task_type == "text-classification"
      assert result.task_name == "Text Classification"
      assert result.dataset_type == "glue"
      assert result.dataset_name == "GLUE"
      assert result.dataset_config == "sst2"
      assert result.dataset_split == "test"
      assert result.metric_type == "accuracy"
      assert result.metric_name == "Accuracy"
      assert result.metric_value == 0.92
      assert result.verified == true
    end
  end
end
