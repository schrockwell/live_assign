defmodule Love.MixProject do
  use Mix.Project

  def project do
    [
      app: :love_ex,
      version: "0.2.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      elixirc_paths: elixirc_paths(Mix.env()),

      # Hex
      description: description(),
      package: package(),
      source_url: "https://github.com/schrockwell/love_ex"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.28.4", only: :dev},
      {:floki, ">= 0.30.0", only: :test},
      {:jason, "~> 1.0", only: :test},
      {:live_isolated_component, "~> 0.3", only: [:test], runtime: false},
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false},
      {:phoenix_live_view, "~> 0.16"}
    ]
  end

  defp description do
    "Extends Phoenix.LiveComponent with additional features."
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/elixir-ecto/postgrex"}
    ]
  end

  defp docs do
    [
      extras: ["README.md"],
      groups_for_functions: [
        {"Field Definitions", &(&1[:group] == :fields)},
        {"Guards", &(&1[:group] == :guards)}
      ],
      main: "Love"
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
