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
    - `2` — no notebooks discovered

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
    {opts, _args, errors} = OptionParser.parse(args, switches: @switches)

    if errors != [] do
      errors
      |> Enum.each(fn {key, value} ->
        Mix.shell().error("Unknown option: #{key} #{inspect(value)}")
      end)

      Mix.raise("Invalid options provided. Run \"mix help livebook.test\" for usage information")
    end

    Mix.Task.run("app.start", [])

    config = build_config_from_opts(opts)

    report = LivebookTest.run_with_config(config)

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

  @doc false
  def build_config_from_opts(opts) do
    paths = parse_repeated_opt(opts, :path)
    excludes = parse_repeated_opt(opts, :exclude)

    overrides =
      []
      |> put_paths(paths)
      |> put_excludes(paths, excludes)
      |> put_mode(opts)
      |> put_timeout(opts)
      |> put_verbose(opts)

    LivebookTest.Config.resolve(overrides)
  end

  defp parse_repeated_opt(opts, key) do
    case Keyword.get_values(opts, key) do
      [] -> nil
      values -> values
    end
  end

  defp put_paths(overrides, nil), do: overrides
  defp put_paths(overrides, paths), do: Keyword.put(overrides, :paths, paths)

  defp put_excludes(overrides, _paths, nil), do: overrides
  defp put_excludes(overrides, _paths, excludes), do: Keyword.put(overrides, :exclude, excludes)

  defp put_mode(overrides, opts) do
    case Keyword.get(opts, :mode) do
      nil -> overrides
      "local" -> Keyword.put(overrides, :dependency_mode, :local)
      "remote" -> Keyword.put(overrides, :dependency_mode, :remote)
      mode when is_atom(mode) -> Keyword.put(overrides, :dependency_mode, mode)
      other -> Mix.raise("Invalid --mode value: #{inspect(other)}. Expected: local or remote")
    end
  end

  defp put_timeout(overrides, opts) do
    case Keyword.get(opts, :timeout) do
      nil ->
        overrides

      timeout when is_binary(timeout) ->
        case Integer.parse(timeout) do
          {value, ""} ->
            Keyword.put(overrides, :timeout, value * 1000)

          _ ->
            Mix.raise(
              "Invalid --timeout value: #{inspect(timeout)}. Expected a number in seconds"
            )
        end

      timeout when is_integer(timeout) ->
        Keyword.put(overrides, :timeout, timeout)
    end
  end

  defp put_verbose(overrides, opts) do
    case Keyword.get(opts, :verbose) do
      nil -> overrides
      true -> Keyword.put(overrides, :verbose, true)
      false -> overrides
    end
  end
end
