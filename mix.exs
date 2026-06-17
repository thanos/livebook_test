defmodule LivebookTest.MixProject do
  use Mix.Project

  @version "0.1.1"
  @source_url "https://github.com/thanos/livebook_test"

  def project do
    [
      app: :livebook_test,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package(),
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.html": :test,
        "coveralls.github": :test
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:livebook, "~> 0.19.0", runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7.17", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:mox, "~> 1.2", only: :test}
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: [
        "README.md",
        "LICENSE",
        "docs/guides/why_test_livebooks.md",
        "docs/guides/cicd_for_livebook_notebooks.md",
        "docs/guides/local_dependency_testing.md",
        "docs/guides/kino_limitations.md",
        "docs/guides/executable_documentation.md"
      ],
      extra_section: "Guides",
      groups_for_modules: [
        Core: [LivebookTest, LivebookTest.Config, LivebookTest.Preflight],
        Pipeline: [
          LivebookTest.Discovery,
          LivebookTest.Exporter,
          LivebookTest.DependencyPatcher,
          LivebookTest.Runner,
          LivebookTest.Report
        ]
      ]
    ]
  end

  defp package do
    [
      name: "livebook_test",
      description:
        "Bring mix test-style workflows to Livebook. Test .livemd notebooks locally and in CI/CD.",
      licenses: ["MIT"],
      maintainers: ["Thanos Vassilakis"],
      links: %{
        "GitHub" => @source_url,
        "HexDocs" => "https://hexdocs.pm/livebook_test"
      },
      files:
        ~w(lib mix.exs README.md LICENSE CHANGELOG.md CODE_OF_CONDUCT.md CONTRIBUTING.md docs)
    ]
  end

  defp aliases do
    []
  end
end
