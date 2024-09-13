defmodule Minamo.MixProject do
  use Mix.Project

  def project do
    [
      app: :minamo,
      version: "0.1.0",
      elixir: "~> 1.17.2",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Minamo.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:feeder, "~> 2.3.0"},
      {:feeder_ex, "~> 1.1"},
      {:floki, "~> 0.36.2"},
      {:distillery, "~> 2.0"},
      {:httpoison, "~> 2.2"},
      {:jason, "~> 1.4"},
      {:quantum, "~> 3.0"},
      {:tzdata, "~> 1.1"}
    ]
  end
end
