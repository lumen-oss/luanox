# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :luanox, :scopes,
  user: [
    default: true,
    module: LuaNox.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :id,
    schema_table: :users,
    test_data_fixture: LuaNox.AccountsFixtures,
    test_login_helper: :register_and_log_in_user
  ]

config :luanox,
  namespace: LuaNox,
  ecto_repos: [LuaNox.Repo],
  generators: [timestamp_type: :utc_datetime],
  key_ttl_weeks_default: 4,
  key_ttl_weeks_max: 4

# Configures the endpoint
config :luanox, LuaNoxWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: LuaNoxWeb.ErrorHTML, json: LuaNoxWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: LuaNox.PubSub,
  live_view: [signing_salt: "BLDXxYv8"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :luanox, LuaNox.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  luanox: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.3",
  path: System.get_env("MIX_TAILWIND_PATH"),
  luanox: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Tablerone (Tabler icons)
config :tablerone, :otp_app, :luanox

# Configure ueberauth (OAuth provider)
config :ueberauth, Ueberauth,
  providers: [
    github: {Ueberauth.Strategy.Github, []}
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :flop, repo: LuaNox.Repo

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
