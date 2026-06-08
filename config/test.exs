import Config

config :livebook_test,
  paths: ["examples/**/*.livemd"],
  exclude: ["**/broken/**/*.livemd"],
  timeout: 30_000
