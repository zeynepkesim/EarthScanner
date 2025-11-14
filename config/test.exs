import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :earth_scanner, EarthScanner.Repo,
  username: System.get_env("POSTGRES_USER", "postgres"),
  # Default to "postgres" for local devs; override with POSTGRES_PASSWORD env if needed
  password: System.get_env("POSTGRES_PASSWORD", "postgres"),
  hostname: System.get_env("POSTGRES_HOST", "localhost"),
  port: String.to_integer(System.get_env("POSTGRES_PORT", "5433")),
  database: System.get_env("POSTGRES_DB", "earth_scanner_test"),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :earth_scanner, EarthScannerWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "/NwrOk7PMEuOqynsnaaW4tbNRwZFi538h9LdSIVIXBqq2S2DE14Vnh74sU7qAZeI",
  server: true

# In test we don't send emails
config :earth_scanner, EarthScanner.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

config :hound,
  driver: "chrome_driver",
  browser: "chrome",
  host: "http://localhost",
  port: 50633
