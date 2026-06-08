defmodule LivebookTest do
  @moduledoc """
  Test your Livebook notebooks — "mix test for Livebooks".

  LivebookTest discovers `.livemd` notebooks, converts them to
  executable Elixir scripts, runs them, and reports failures.
  It supports local dependency overrides so standalone notebooks
  can be tested against the current repository checkout.

  ## Quick start

  Add to your Mix project:

      def deps do
        [{:livebook_test, "~> 0.1.0", only: [:dev, :test]}]
      end

  Run:

      mix livebook.test

  ## Pipeline

  The library processes notebooks through a pipeline:

      1. **Discovery** — find `.livemd` files via glob patterns
      2. **Export** — convert notebooks to `.exs` scripts
      3. **Patch** — optionally rewrite Mix.install deps to local paths
      4. **Run** — execute each script as a subprocess
      5. **Report** — summarize results and return CI exit codes

  ## Local dependency testing

  The key feature: notebooks that use `Mix.install` can be
  automatically patched to use your local checkout instead of
  published Hex packages.

      # In config/config.exs
      config :livebook_test,
        dependency_mode: :local,
        local_deps: [
          my_lib: "."
        ]

  ## Programmatic API

      LivebookTest.run()
      LivebookTest.run(paths: ["examples/**/*.livemd"], mode: :local, timeout: 120_000)

  ## Configuration

  See `LivebookTest.Config` for full configuration options.
  """

  @typedoc "Options accepted by `run/1`"
  @type run_option ::
          {:paths, [String.t()]}
          | {:exclude, [String.t()]}
          | {:mode, LivebookTest.Config.dependency_mode()}
          | {:timeout, non_neg_integer()}
          | {:local_deps, LivebookTest.Config.local_deps()}
          | {:verbose, boolean()}

  @typedoc "Result of a complete test run"
  @type run_result :: %{
          config: LivebookTest.Config.t(),
          report: LivebookTest.Report.t()
        }

  @doc """
  Discovers, exports, patches, runs, and reports on Livebook notebooks.

  This is the primary entry point. It orchestrates the full pipeline
  and returns a map with the resolved config and the report.

  ## Options

    - `:paths` — list of glob patterns (default from config)
    - `:exclude` — list of glob patterns to exclude from discovery
    - `:mode` — `:remote` or `:local` dependency mode
    - `:timeout` — per-notebook timeout in milliseconds
    - `:local_deps` — dependency name → path mapping
    - `:verbose` — enable verbose output

  ## Examples

      iex> result = LivebookTest.run(paths: ["examples/**/*.livemd"])
      iex> is_map(result) and Map.has_key?(result, :report)
      true
  """
  @spec run([run_option()]) :: run_result()
  def run(opts \\ []) do
    overrides = build_overrides(opts)
    config = LivebookTest.Config.resolve(overrides)

    {config, run_with_config(config)}
  end

  @doc """
  Runs the full pipeline using a pre-resolved config.

  Useful when you need fine-grained control over configuration
  before running.

  ## Examples

      iex> config = LivebookTest.Config.resolve(paths: ["examples/**/*.livemd"])
      iex> {config, report} = LivebookTest.run_with_config(config)
      iex> is_struct(report, LivebookTest.Report)
      true
  """
  @spec run_with_config(LivebookTest.Config.t()) :: LivebookTest.Report.t()
  def run_with_config(%LivebookTest.Config{} = config) do
    notebooks = LivebookTest.Discovery.find(config.paths, exclude: config.exclude)

    if config.verbose do
      IO.puts("[LivebookTest] Discovered #{length(notebooks)} notebook(s)")
    end

    script_pairs =
      notebooks
      |> Enum.map(fn notebook_path ->
        {:ok, script_path} = LivebookTest.Exporter.to_temp_file(notebook_path)
        {notebook_path, script_path}
      end)

    script_pairs =
      if config.dependency_mode == :local do
        Enum.map(script_pairs, fn {notebook_path, script_path} ->
          if config.verbose do
            IO.puts("[LivebookTest] Patching #{notebook_path} with local deps")
          end

          {:ok, script_content} = File.read(script_path)

          patched =
            LivebookTest.DependencyPatcher.patch(script_content, :local, config.local_deps)

          :ok = File.write(script_path, patched)
          {notebook_path, script_path}
        end)
      else
        script_pairs
      end

    results =
      LivebookTest.Runner.run_all(script_pairs,
        timeout: config.timeout
      )

    Enum.each(script_pairs, fn {_notebook_path, script_path} ->
      File.rm(script_path)
    end)

    LivebookTest.Report.build(results)
  end

  @doc """
  Convenience function that runs the pipeline and prints the report.

  Returns the exit code (0 for success, 1 for failure) suitable
  for CI/CD use.

  ## Examples

      iex> LivebookTest.run_and_report(paths: ["examples/**/*.livemd"]) in [0, 1]
      true
  """
  @spec run_and_report([run_option()]) :: 0 | 1
  def run_and_report(opts \\ []) do
    {config, report} = run(opts)

    output =
      if config.verbose do
        LivebookTest.Report.format_verbose(report)
      else
        LivebookTest.Report.format(report)
      end

    IO.puts(output)

    LivebookTest.Report.exit_code(report)
  end

  defp build_overrides(opts) do
    overrides = []

    overrides =
      case Keyword.get(opts, :paths) do
        nil -> overrides
        paths -> Keyword.put(overrides, :paths, paths)
      end

    overrides =
      case Keyword.get(opts, :mode) do
        nil -> overrides
        mode -> Keyword.put(overrides, :dependency_mode, mode)
      end

    overrides =
      case Keyword.get(opts, :timeout) do
        nil -> overrides
        timeout -> Keyword.put(overrides, :timeout, timeout)
      end

    overrides =
      case Keyword.get(opts, :local_deps) do
        nil -> overrides
        local_deps -> Keyword.put(overrides, :local_deps, local_deps)
      end

    overrides =
      case Keyword.get(opts, :exclude) do
        nil -> overrides
        exclude -> Keyword.put(overrides, :exclude, exclude)
      end

    case Keyword.get(opts, :verbose) do
      nil -> overrides
      verbose -> Keyword.put(overrides, :verbose, verbose)
    end
  end
end
