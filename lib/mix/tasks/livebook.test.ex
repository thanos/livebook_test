defmodule Mix.Tasks.Livebook.Test do
  @moduledoc """
  Runs Livebook notebooks as tests.

  This task discovers `.livemd` files, converts them to Elixir
  scripts, executes them, and reports results — similar to
  `mix test` but for Livebook notebooks.

  ## Usage

      mix livebook.test
      mix livebook.test --path livebooks/**/*.livemd
      mix livebook.test --exclude '**/broken/**/*.livemd'
      mix livebook.test --mode local
      mix livebook.test --mode remote
      mix livebook.test --timeout 120
      mix livebook.test --verbose

  ## Options

    - `--path` — glob pattern for notebook discovery (can be repeated)
    - `--exclude` — glob pattern to exclude from discovery (can be repeated)
    - `--mode` — dependency mode: `local` or `remote` (default: from config)
    - `--timeout` — per-notebook timeout in seconds (default: from config)
    - `--verbose` — enable verbose output with per-notebook details

  ## Exit codes

    - `0` — all notebooks passed
    - `1` — one or more notebooks failed

  ## CI/CD integration

  Add to your CI workflow:

      - name: Test Livebooks
        run: mix livebook.test

  For local dependency testing:

      - name: Test Livebooks (local deps)
        run: mix livebook.test --mode local

  ## Configuration

  See `LivebookTest.Config` for application environment configuration.
  """

  use Mix.Task

  @shortdoc "Runs Livebook notebooks as tests"

  @switches [
    path: :keep,
    exclude: :keep,
    mode: :string,
    timeout: :string,
    verbose: :boolean
  ]

  @impl Mix.Task
  def run(args) do
    {opts, _args, _errors} = OptionParser.parse(args, switches: @switches)

    Mix.Task.run("app.start", [])

    cli_config = build_config_from_opts(opts)

    {config, report} = LivebookTest.run(cli_config)

    output =
      if config.verbose do
        LivebookTest.Report.format_verbose(report)
      else
        LivebookTest.Report.format(report)
      end

    Mix.shell().info(output)

    exit_code = LivebookTest.Report.exit_code(report)

    if exit_code != 0 do
      Mix.raise("Livebook tests failed")
    end
  end

  defp build_config_from_opts(opts) do
    paths =
      opts
      |> Keyword.get_values(:path)
      |> case do
        [] -> nil
        paths -> paths
      end

    excludes =
      opts
      |> Keyword.get_values(:exclude)
      |> case do
        [] -> nil
        excludes -> excludes
      end

    overrides = []

    overrides =
      if paths, do: Keyword.put(overrides, :paths, paths), else: overrides

    overrides =
      cond do
        paths && is_nil(excludes) -> Keyword.put(overrides, :exclude, [])
        excludes -> Keyword.put(overrides, :exclude, excludes)
        true -> overrides
      end

    overrides =
      case Keyword.get(opts, :mode) do
        nil -> overrides
        "local" -> Keyword.put(overrides, :dependency_mode, :local)
        "remote" -> Keyword.put(overrides, :dependency_mode, :remote)
        mode -> Keyword.put(overrides, :dependency_mode, String.to_atom(mode))
      end

    overrides =
      case Keyword.get(opts, :timeout) do
        nil -> overrides
        timeout -> Keyword.put(overrides, :timeout, String.to_integer(timeout) * 1000)
      end

    overrides =
      case Keyword.get(opts, :verbose) do
        nil -> overrides
        true -> Keyword.put(overrides, :verbose, true)
        false -> overrides
      end

    overrides
  end
end
