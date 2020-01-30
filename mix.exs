defmodule QueryElf.MixProject do
  use Mix.Project

  def project do
    [
      app: :query_elf,
      version: "0.1.0",
      description: description(),
      source_url: "https://gitlab.com/up-learn-uk/query-elf",
      package: package(),
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  defp description do
    "A helper to build the most common database queries for Ecto (and potentially other backends)."
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
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
