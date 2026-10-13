import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :luxpkgs, Luxpkgs.Repo,
  username: System.get_env("DATABASE_USER"),
  password: System.get_env("DATABASE_PASS"),
  hostname: "localhost",
  port: System.get_env("PGPORT", System.get_env("DATABASE_PORT")),
  database: "luxpkgs_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :luxpkgs, LuxpkgsWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "e+honEGDbw+vawI8JQGcGQYv1ziaQftWuji8m7FdE+sd3jQZaFuZ7ibbKDCEr5ms",
  server: false

# In test we don't send emails
config :luxpkgs, Luxpkgs.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Configure rockspec storage for tests
config :luxpkgs, :rockspec_storage, Path.join(System.tmp_dir!(), "luxpkgs_test_rockspecs")

config :luxpkgs, :rockspec_parse_endpoint, "http://127.0.0.1:1/parse"

config :luxpkgs,
  rockspec_verification_endpoint:
    "http://localhost:#{System.get_env("LUXPKGS_ROCKSPEC_VERIFIER_PORT", "5000")}/verify"

# Configure Guardian for tests
config :luxpkgs, Luxpkgs.Guardian,
  issuer: "luxpkgs",
  secret_key: "6edg497dRRnjrb4vVkC3tKtjUa8murczurc66WajBraegP3Bf9Hl3+c74ldwhg8H"

config :luxpkgs, Luxpkgs.Vault,
  ciphers: [
    default: {
      Cloak.Ciphers.AES.GCM,
      tag: "AES.GCM.V1", key: :crypto.hash(:sha256, "luxpkgs test vault key"), iv_length: 12
    }
  ]

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
