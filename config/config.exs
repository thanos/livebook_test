import Config

# Livebook requires these Endpoint/PubSub/Bandit configs to compile,
# even though livebook_test only calls the pure Livebook.live_markdown_to_elixir/1
# function and never starts the Livebook application at runtime.
config :livebook, LivebookWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  url: [host: "localhost", path: "/"],
  pubsub_server: Livebook.PubSub,
  live_view: [signing_salt: "livebook"],
  drainer: [shutdown: 1000],
  render_errors: [formats: [html: LivebookWeb.ErrorHTML], layout: false]

config :phoenix, :json_library, JSON

config :livebook, Livebook.Apps.Manager, retry_backoff_base_ms: 5_000

config :livebook_test,
  paths: ["livebooks/**/*.livemd", "examples/**/*.livemd"],
  exclude: ["**/broken/**/*.livemd"],
  dependency_mode: :remote,
  timeout: 60_000

import_config "#{config_env()}.exs"
