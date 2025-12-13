defmodule LuaNox.MixProject do
  use Mix.Project

  def project do
    [
      app: :luanox,
      version: "0.3.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      listeners: [Phoenix.CodeReloader]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {LuaNox.Application, []},
      extra_applications: [:logger, :runtime_tools, :os_mon]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:bandit, "~> 1.5"},
      {:bcrypt_elixir, "~> 3.0"},
      {:dns_cluster, "~> 0.1.1"},
      {:ecto_sql, "~> 3.10"},
      {:esbuild, "~> 0.9", runtime: Mix.env() == :dev},
      {:floki, ">= 0.30.0", only: :test},
      {:gettext, "~> 0.26"},
      {:jason, "~> 1.2"},
      {:phoenix, "~> 1.8.0-rc.0", override: true},
      {:phoenix_ecto, "~> 4.5"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.0"},
      {:postgrex, ">= 0.0.0"},
      {:req, "~> 0.5"},
      {:swoosh, "~> 1.16"},
      {:tablerone, "~> 1.0"},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:ueberauth_github, "~> 0.8"},
      {:guardian, "~> 2.3"},
      {:open_api_spex, "~> 3.6"},
      {:flop, "~> 0.26"},
      {:flop_phoenix, "~> 0.25"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind luanox", "esbuild luanox"],
      "assets.deploy": [
        "tailwind luanox --minify",
        "esbuild luanox --minify",
        "phx.digest"
      ]
    ]
  end
end
