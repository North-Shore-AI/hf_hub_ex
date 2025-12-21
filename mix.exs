defmodule HfHub.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/North-Shore-AI/hf_hub_ex"

  def project do
    [
      app: :hf_hub,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      name: "HfHub",
      description:
        "Elixir client for HuggingFace Hub—dataset/model metadata, file downloads, caching, and authentication",
      source_url: @source_url,
      homepage_url: @source_url,
      dialyzer: [
        plt_add_apps: [:mix, :ex_unit],
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
      ],
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {HfHub.Application, []}
    ]
  end

  defp deps do
    [
      # HTTP client
      {:req, "~> 0.5"},

      # JSON parsing
      {:jason, "~> 1.4"},

      # Optional: DataFrame support for dataset loading
      {:explorer, "~> 0.10", optional: true},

      # Development and testing
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:bypass, "~> 2.1", only: :test}
    ]
  end

  defp package do
    [
      name: "hf_hub",
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "HuggingFace" => "https://huggingface.co"
      },
      files: ~w(lib assets mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      assets: %{"assets" => "assets"},
      logo: "assets/hf_hub_ex.svg",
      extras: ["README.md", "CHANGELOG.md", "LICENSE", "docs/ROADMAP.md"],
      groups_for_modules: [
        "Core API": [
          HfHub.Api,
          HfHub.Download,
          HfHub.Cache,
          HfHub.FS,
          HfHub.Auth
        ],
        Internal: [
          HfHub.Application,
          HfHub.Config,
          HfHub.HTTP,
          HfHub.Cache.Server
        ]
      ],
      groups_for_extras: [
        Documentation: ["README.md", "docs/ROADMAP.md"],
        Changelog: ["CHANGELOG.md"],
        License: ["LICENSE"]
      ]
    ]
  end
end
