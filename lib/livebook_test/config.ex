defmodule LivebookTest.Config do
  @moduledoc """
  Configuration management for LivebookTest.

  Handles defaults, runtime options, and Mix config resolution.
  Configuration can be set via:

    * `config/config.exs` — application environment
    * CLI options — `mix livebook.test --mode local --timeout 120_000`
    * Programmatic — `LivebookTest.run(paths: [...], mode: :local)`

  ## Application configuration

      config :livebook_test,
        paths: ["livebooks/**/*.livemd"],
        exclude: ["**/broken/**/*.livemd"],
        dependency_mode: :remote,
        timeout: 60_000,
        local_deps: []

  ## Option precedence

  CLI options > programmatic keyword list > application environment > defaults
  """

  @typedoc "Dependency resolution mode"
  @type dependency_mode :: :remote | :local

  @typedoc "Local dependency specification: keyword list mapping package names to filesystem paths"
  @type local_deps :: keyword()

  @typedoc "Resolved configuration"
  @type t :: %__MODULE__{
          paths: [String.t()],
          exclude: [String.t()],
          dependency_mode: dependency_mode(),
          timeout: non_neg_integer(),
          local_deps: local_deps(),
          verbose: boolean()
        }

  @enforce_keys [:paths, :exclude, :dependency_mode, :timeout, :local_deps, :verbose]
  defstruct [:paths, :exclude, :dependency_mode, :timeout, :local_deps, :verbose]

  @default_paths ["livebooks/**/*.livemd", "examples/**/*.livemd"]
  @default_exclude ["**/broken/**/*.livemd"]
  @default_dependency_mode :remote
  @default_timeout 60_000
  @default_local_deps []
  @default_verbose false

  @doc """
  Resolves configuration by merging defaults, application env, and overrides.

  ## Examples

      iex> config = LivebookTest.Config.resolve()
      iex> is_struct(config, LivebookTest.Config)
      true

      iex> config = LivebookTest.Config.resolve(paths: ["my_notebooks/**/*.livemd"])
      iex> config.paths
      ["my_notebooks/**/*.livemd"]
  """
  @spec resolve(keyword()) :: t()
  def resolve(overrides \\ []) do
    %__MODULE__{
      paths: resolve_paths(overrides),
      exclude: resolve_exclude(overrides),
      dependency_mode: resolve_dependency_mode(overrides),
      timeout: resolve_timeout(overrides),
      local_deps: resolve_local_deps(overrides),
      verbose: resolve_verbose(overrides)
    }
  end

  @doc """
  Resolves configuration from CLI option tuples.

  Accepts the option list parsed by `OptionParser` and merges
  with application environment and defaults.

  ## Examples

      iex> config = LivebookTest.Config.from_cli([mode: "local", timeout: "120"])
      iex> config.dependency_mode
      :local

      iex> config = LivebookTest.Config.from_cli([verbose: true])
      iex> config.verbose
      true
  """
  @spec from_cli(keyword()) :: t()
  def from_cli(cli_opts) do
    overrides =
      []
      |> maybe_put_paths(cli_opts)
      |> maybe_put_mode(cli_opts)
      |> maybe_put_timeout(cli_opts)
      |> maybe_put_verbose(cli_opts)

    resolve(overrides)
  end

  defp resolve_paths(overrides) do
    Keyword.get(overrides, :paths, app_env(:paths, @default_paths))
  end

  defp resolve_exclude(overrides) do
    Keyword.get(overrides, :exclude, app_env(:exclude, @default_exclude))
  end

  defp resolve_dependency_mode(overrides) do
    Keyword.get(overrides, :dependency_mode, app_env(:dependency_mode, @default_dependency_mode))
  end

  defp resolve_timeout(overrides) do
    Keyword.get(overrides, :timeout, app_env(:timeout, @default_timeout))
  end

  defp resolve_local_deps(overrides) do
    Keyword.get(overrides, :local_deps, app_env(:local_deps, @default_local_deps))
  end

  defp resolve_verbose(overrides) do
    Keyword.get(overrides, :verbose, app_env(:verbose, @default_verbose))
  end

  defp app_env(key, default) do
    Application.get_env(:livebook_test, key, default)
  end

  defp maybe_put_paths(acc, cli_opts) do
    case Keyword.get_values(cli_opts, :path) do
      [] -> acc
      paths -> Keyword.put(acc, :paths, paths)
    end
  end

  defp maybe_put_mode(acc, cli_opts) do
    case Keyword.get(cli_opts, :mode) do
      nil -> acc
      "local" -> Keyword.put(acc, :dependency_mode, :local)
      "remote" -> Keyword.put(acc, :dependency_mode, :remote)
      mode when is_atom(mode) -> Keyword.put(acc, :dependency_mode, mode)
    end
  end

  defp maybe_put_timeout(acc, cli_opts) do
    case Keyword.get(cli_opts, :timeout) do
      nil ->
        acc

      timeout when is_binary(timeout) ->
        Keyword.put(acc, :timeout, String.to_integer(timeout) * 1000)

      timeout when is_integer(timeout) ->
        Keyword.put(acc, :timeout, timeout)
    end
  end

  defp maybe_put_verbose(acc, cli_opts) do
    case Keyword.get(cli_opts, :verbose) do
      nil -> acc
      true -> Keyword.put(acc, :verbose, true)
      false -> Keyword.put(acc, :verbose, false)
    end
  end
end
