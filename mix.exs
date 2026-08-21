defmodule Exorrent.MixProject do
  use Mix.Project

  def project do
    [
      app: :exorrent,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :inets, :ssl]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bencoder, github: "Yhodhan/Bencoder", branch: "master"},
      {:exalia, github: "Yhodhan/Exalia", branch: "master"}
    ]
  end
end
