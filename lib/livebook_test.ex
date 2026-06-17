defmodule LivebookTest do
  @moduledoc """
  Test your Livebook notebooks - "mix test for Livebooks".

  LivebookTest discovers `.livemd` notebooks, converts them to
  executable Elixir scripts, runs them, and reports failures.
  It supports local dependency overrides so standalone notebooks
  can be tested against the current repository checkout.

  ## Quick start

  Add to your Mix project:

      def deps do
        [{:livebook_test, "~> 0.1.0", only: [:dev, :test], runtime: false}]
      end

  Run:

      mix livebook.test

  ## Pipeline

  The library processes notebooks through a pipeline:

      1. **Discovery** - find `.livemd` files via glob patterns
      2. **Export** - convert notebooks to `.exs` scripts
      3. **Patch** - optionally rewrite Mix.install deps to local paths
      4. **Run** - execute each script as a subprocess
      5. **Report** - summarize results and return CI exit codes

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
  @type run_result :: {LivebookTest.Config.t(), LivebookTest.Report.t()}

  @doc """
  Discovers, exports, patches, runs, and reports on Livebook notebooks.

  This is the primary entry point. It orchestrates the full pipeline
  and returns a tuple with the resolved config and the report.

  ## Options

    - `:paths` - list of glob patterns (default from config)
    - `:exclude` - list of glob patterns to exclude from discovery
    - `:mode` - `:remote` or `:local` dependency mode
    - `:timeout` - per-notebook timeout in milliseconds
    - `:local_deps` - dependency name → path mapping
    - `:verbose` - enable verbose output

  ## Examples

      iex> {config, report} = LivebookTest.run(paths: ["examples/**/*.livemd"])
      iex> is_struct(config, LivebookTest.Config) and is_struct(report, LivebookTest.Report)
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
      iex> report = LivebookTest.run_with_config(config)
      iex> is_struct(report, LivebookTest.Report)
      true
  """
  @spec run_with_config(LivebookTest.Config.t(), keyword()) :: LivebookTest.Report.t()
  def run_with_config(%LivebookTest.Config{} = config, opts \\ []) do
    case Keyword.get(opts, :preflight, true) do
      true -> LivebookTest.Preflight.check!()
      false -> :ok
    end

    runner_mod = Keyword.get(opts, :runner, LivebookTest.Runner)
    notebooks = LivebookTest.Discovery.find(config.paths, exclude: config.exclude)

    log_verbose(config, "Discovered #{length(notebooks)} notebook(s)")

    script_pairs = export_notebooks(notebooks, config)

    try do
      results = runner_mod.run_all(script_pairs, timeout: config.timeout)
      LivebookTest.Report.build(results)
    after
      cleanup_scripts(script_pairs)
    end
  end

  defp log_verbose(config, message) do
    if config.verbose, do: IO.puts("[LivebookTest] #{message}")
  end

  defp export_notebooks(notebooks, config) do
    notebooks
    |> Enum.map(fn notebook_path ->
      case LivebookTest.Exporter.to_temp_file(notebook_path) do
        {:ok, script_path} ->
          {notebook_path, script_path}

        {:error, reason} ->
          log_verbose(config, "Failed to export #{notebook_path}: #{inspect(reason)}")
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> maybe_patch_deps(config)
  end

  defp maybe_patch_deps(script_pairs, config) do
    if config.dependency_mode == :local do
      Enum.map(script_pairs, &patch_local_deps(&1, config))
    else
      script_pairs
    end
  end

  defp patch_local_deps({notebook_path, script_path}, config) do
    log_verbose(config, "Patching #{notebook_path} with local deps")

    case File.read(script_path) do
      {:ok, script_content} ->
        patched =
          LivebookTest.DependencyPatcher.patch(script_content, :local, config.local_deps)

        case File.write(script_path, patched) do
          :ok ->
            {notebook_path, script_path}

          {:error, reason} ->
            log_verbose(
              config,
              "Failed to write patched script #{script_path}: #{inspect(reason)}"
            )

            {notebook_path, script_path}
        end

      {:error, reason} ->
        log_verbose(config, "Failed to read script #{script_path}: #{inspect(reason)}")
        {notebook_path, script_path}
    end
  end

  defp cleanup_scripts(script_pairs) do
    Enum.each(script_pairs, fn {_notebook_path, script_path} ->
      File.rm(script_path)
    end)
  end

  @doc """
  Convenience function that runs the pipeline and prints the report.

  Returns the exit code (0 for success, 1 for failure) suitable
  for CI/CD use.

  ## Examples

      iex> LivebookTest.run_and_report(paths: ["examples/**/*.livemd"]) in [0, 1, 2]
      true
  """
  @spec run_and_report([run_option()]) :: 0 | 1 | 2
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
    []
    |> maybe_put(opts, :paths, :paths)
    |> maybe_put_mode(opts)
    |> maybe_put(opts, :timeout, :timeout)
    |> maybe_put(opts, :local_deps, :local_deps)
    |> maybe_put(opts, :exclude, :exclude)
    |> maybe_put(opts, :verbose, :verbose)
  end

  defp maybe_put(overrides, opts, source_key, dest_key) do
    case Keyword.get(opts, source_key) do
      nil -> overrides
      value -> Keyword.put(overrides, dest_key, value)
    end
  end

  defp maybe_put_mode(overrides, opts) do
    case Keyword.get(opts, :mode) do
      nil -> overrides
      mode -> Keyword.put(overrides, :dependency_mode, mode)
    end
  end
end
