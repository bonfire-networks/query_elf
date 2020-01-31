defmodule QueryElf.MixProject do
  use Mix.Project

  def project do
    [
      app: :query_elf,
      version: "0.2.0",
      description: description(),
      source_url: "https://gitlab.com/up-learn-uk/query-elf",
      package: package(),
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  defp description do
    "A helper to build the most common database queries for Ecto."
  end

  defp package() do
    [
      licenses: ["Apache-2.0"],
      links: %{"GitLab" => "https://gitlab.com/up-learn-uk/query-elf"}
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
      {:ecto, "~> 2.1 or ~> 3.0"},
      {:credo, "~> 1.1.0", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end
end
