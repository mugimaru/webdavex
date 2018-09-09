defmodule Webdavex.MixProject do
  use Mix.Project

  def project do
    [
      app: :webdavex,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      description: "hackney based WebDAV client.",
      package: package(),
      deps: deps(),
      source_url: "https://github.com/mugimaru73/webdavex",
      docs: docs()
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
      {:hackney, "~> 1.0"},
      {:ex_doc, "~> 0.14", only: :dev},
      {:credo, "~> 0.9.2", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0.0-rc.3", only: [:dev], runtime: false},
      {:bypass, "~> 0.8", only: :test}
    ]
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README.md", "LICENSE", ".credo.exs"],
      maintainers: ["mugimaru73"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/mugimaru73/webdavex"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md"]
    ]
  end
end
