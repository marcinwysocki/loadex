defmodule Loadex.MixProject do
  use Mix.Project

  def project do
    [
      app: :loadex,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: description(),

      # Docs
      name: "Loadex",
      source_url: "https://github.com/marcinwysocki/loadex",
      homepage_url: "https://hexdocs.pm/loadex",
      docs: [
        main: "Loadex",
        extras: ["README.md"],
        authors: ["Marcin Wysocki"]
      ],
      licenses: ["MIT"]
    ]
  end

  defp description() do
    "A simple distributed load test runner."
  end

  defp package() do
    [
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE),
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/marcinwysocki/taskmaster"},
      maintainers: ["Marcin Wysocki"]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Loadex.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_hash_ring, "~> 3.0"},
      {:ex_doc, "~> 0.22", only: :dev, runtime: false}
    ]
  end
end
