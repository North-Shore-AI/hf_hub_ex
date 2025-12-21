defmodule HfHub.ApiTest do
  use ExUnit.Case, async: true

  describe "dataset_configs/2" do
    test "extracts config names from configs list" do
      card_data = %{
        "configs" => [
          %{"config_name" => "main", "data_files" => []},
          %{"config_name" => "socratic", "data_files" => []}
        ]
      }

      configs = HfHub.Api.extract_config_names(card_data)
      assert configs == ["main", "socratic"]
    end

    test "extracts from dataset_config_names (legacy format)" do
      card_data = %{
        "dataset_config_names" => ["train", "validation", "test"]
      }

      configs = HfHub.Api.extract_config_names(card_data)
      assert configs == ["train", "validation", "test"]
    end

    test "returns empty list when no configs" do
      assert HfHub.Api.extract_config_names(%{}) == []
      assert HfHub.Api.extract_config_names(nil) == []
    end

    test "prefers configs over dataset_config_names" do
      card_data = %{
        "configs" => [%{"config_name" => "new"}],
        "dataset_config_names" => ["old"]
      }

      configs = HfHub.Api.extract_config_names(card_data)
      assert configs == ["new"]
    end
  end
end
