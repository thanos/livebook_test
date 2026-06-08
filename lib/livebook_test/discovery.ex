defmodule LivebookTest.Discovery do
  @moduledoc """
  Notebook discovery via filesystem glob patterns.

  Uses `Path.wildcard/2` to find `.livemd` files matching
  configured path patterns, then excludes any matching
  exclusion patterns. This module is the first stage
  in the LivebookTest pipeline:

      Discovery → Exporter → DependencyPatcher → Runner → Report

  ## How notebook discovery works

  1. A list of glob patterns is provided (from config or CLI)
  2. Each pattern is expanded using `Path.wildcard/2`
  3. Results are deduplicated and sorted for deterministic execution
  4. Only files ending in `.livemd` are included
  5. Files matching any exclusion pattern are removed

  ## Exclusion

  The `exclude` option filters out notebooks that should not be
  run by default — for example, intentionally broken notebooks
  kept as test fixtures:

      LivebookTest.Discovery.find(["examples/**/*.livemd"],
        exclude: ["**/broken/**/*.livemd"]
      )

  ## Examples

      iex> paths = LivebookTest.Discovery.find(["examples/**/*.livemd"])
      iex> is_list(paths)
      true
  """

  @typedoc "Result of discovery: a list of paths to .livemd files"
  @type discovery_result :: [Path.t()]

  @doc """
  Discovers Livebook notebooks matching the given glob patterns,
  excluding any that match the exclusion patterns.

  Returns a sorted, deduplicated list of paths.

  ## Examples

      iex> LivebookTest.Discovery.find(["nonexistent/**/*.livemd"])
      []

      iex> paths = LivebookTest.Discovery.find(["examples/**/*.livemd"])
      iex> Enum.all?(paths, &String.ends_with?(&1, ".livemd"))
      true
  """
  @spec find([String.t()], keyword()) :: discovery_result()
  def find(patterns, opts \\ [])

  def find(patterns, opts) when is_list(patterns) do
    exclude_patterns = Keyword.get(opts, :exclude, [])

    excluded_paths =
      exclude_patterns
      |> Enum.flat_map(&Path.wildcard(&1, match_dot: true))
      |> MapSet.new()

    patterns
    |> Enum.flat_map(&Path.wildcard(&1, match_dot: true))
    |> Enum.filter(&String.ends_with?(&1, ".livemd"))
    |> Enum.reject(&MapSet.member?(excluded_paths, &1))
    |> Enum.uniq()
    |> Enum.sort()
  end

  @spec find(String.t(), keyword()) :: discovery_result()
  def find(pattern, opts) when is_binary(pattern) do
    find([pattern], opts)
  end

  @doc """
  Counts discovered notebooks without returning the full list.

  Useful for quick status checks or summary reporting.

  ## Examples

      iex> LivebookTest.Discovery.count(["nonexistent/**/*.livemd"])
      0
  """
  @spec count([String.t()], keyword()) :: non_neg_integer()
  def count(patterns, opts \\ [])

  def count(patterns, opts) when is_list(patterns) do
    patterns |> find(opts) |> length()
  end

  def count(pattern, opts) when is_binary(pattern) do
    count([pattern], opts)
  end
end
