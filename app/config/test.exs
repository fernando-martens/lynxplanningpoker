import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :lynxplanningpoker, Lynxplanningpoker.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "lynxplanningpoker_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :lynxplanningpoker, LynxplanningpokerWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "sGh3COa29yhkfC6Xh2OZZbX6QzHlZeXd22+mSlzAepbdLCF8nclUd51m5n9Y/tLo",
  server: false

# In test we don't send emails
config :lynxplanningpoker, Lynxplanningpoker.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

# Make rate limits effectively a no-op in the test suite. Dedicated plug
# tests construct their own plug options with low limits.
config :lynxplanningpoker, :rate_limit,
  global: [limit: 1_000_000, scale_ms: 60_000],
  room_create: [limit: 1_000_000, scale_ms: 60_000]

# Disable Turnstile in tests — no widget rendered, no network call.
# Verifier tests flip this on locally with `Application.put_env/3`.
config :lynxplanningpoker, :turnstile,
  enabled: false,
  site_key: nil,
  secret_key: nil

# Don't start the periodic room sweeper in tests — its cleanup logic is
# exercised directly via `Lynxplanningpoker.Rooms.delete_orphaned_rooms/1`,
# so the timer-driven GenServer would just add nondeterminism.
config :lynxplanningpoker, :room_cleaner, enabled: false

# Run presence-leave cleanup synchronously in tests (no grace delay). Tests
# that exercise the grace window flip this on with `Application.put_env/3`.
config :lynxplanningpoker, :leave_grace_ms, 0
