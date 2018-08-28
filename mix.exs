defmodule FireAct.MixProject do
  use Mix.Project

  def project do
    [
      app: :fire_act,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: [extras: ["README.md"], main: "readme"],
      package: package()
    ]
  end

  defp package do
    [
      files: ["lib", "LICENSE", "mix.exs", "README.md"],
      maintainers: ["arathunku"],
      licenses: ["MIT"],
      links: %{
        "github" => "https://github.com/arathunku/fire-act"
      }
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
      {:ecto, "~> 2.2"},
      {:ex_doc, "~> 0.13", only: :dev},
      {:plug, "~> 1.6.2", only: :test},
      {:mix_test_watch, "~> 0.8", only: :dev, runtime: false}
    ]
  end
end
