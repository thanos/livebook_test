defmodule LivebookTest.Report do
  @moduledoc """
  Summarizes and formats test run results.

  This is the final stage in the LivebookTest pipeline:

      Discovery → Exporter → DependencyPatcher → Runner → **Report**

  Produces human-readable output and CI-friendly exit codes
  from a collection of `LivebookTest.Runner.run_result` structs.

  ## Output format

      12 notebooks
      11 passed
      1 failed
      Total time: 14.2s

  Failed notebooks are listed with their stderr output for
  quick debugging.
  """

  @typedoc "Aggregated summary of a test run"
  @type t :: %__MODULE__{
          total: non_neg_integer(),
          passed: non_neg_integer(),
          failed: non_neg_integer(),
          duration_ms: non_neg_integer(),
          results: [LivebookTest.Runner.run_result()],
          failed_notebooks: [LivebookTest.Runner.run_result()],
          empty: boolean()
        }

  @enforce_keys [:total, :passed, :failed, :duration_ms, :results, :failed_notebooks, :empty]
  defstruct [:total, :passed, :failed, :duration_ms, :results, :failed_notebooks, :empty]

  @doc """
  Builds a report from a list of run results.

  Aggregates pass/fail counts, total duration, and isolates
  failed notebooks for detailed reporting.

  ## Examples

      iex> results = [
      ...>   %LivebookTest.Runner{notebook_path: "a.livemd", script_path: "a.exs", exit_status: 0, stdout: "", stderr: "", duration_ms: 100, timed_out: false},
      ...>   %LivebookTest.Runner{notebook_path: "b.livemd", script_path: "b.exs", exit_status: 1, stdout: "", stderr: "oops", duration_ms: 200, timed_out: false}
      ...> ]
      iex> report = LivebookTest.Report.build(results)
      iex> report.total
      2
      iex> report.passed
      1
      iex> report.failed
      1
  """
  @spec build([LivebookTest.Runner.run_result()]) :: t()
  def build(results) when is_list(results) do
    passed = Enum.count(results, &LivebookTest.Runner.success?/1)
    failed = length(results) - passed
    duration_ms = Enum.sum(Enum.map(results, & &1.duration_ms))
    failed_notebooks = Enum.reject(results, &LivebookTest.Runner.success?/1)

    %__MODULE__{
      total: length(results),
      passed: passed,
      failed: failed,
      duration_ms: duration_ms,
      results: results,
      failed_notebooks: failed_notebooks,
      empty: results == []
    }
  end

  @doc """
  Formats a report as a human-readable string.

  Output includes:
  - Total notebook count
  - Pass/fail counts
  - Total execution time
  - Details of any failures

  ## Examples

      iex> report = %LivebookTest.Report{total: 2, passed: 1, failed: 1, duration_ms: 300, results: [], failed_notebooks: [%LivebookTest.Runner{notebook_path: "b.livemd", script_path: "b.exs", exit_status: 1, stdout: "", stderr: "oops", duration_ms: 200, timed_out: false}], empty: false}
      iex> output = LivebookTest.Report.format(report)
      iex> String.contains?(output, "2 notebooks")
      true
  """
  @spec format(t()) :: String.t()
  def format(%__MODULE__{empty: true}) do
    Enum.join(
      [
        "",
        "0 notebooks found — nothing to test.",
        "Check your paths and exclude patterns.",
        ""
      ],
      "\n"
    )
  end

  def format(%__MODULE__{} = report) do
    lines =
      [
        "",
        "#{report.total} notebooks",
        "#{report.passed} passed",
        "#{report.failed} failed",
        "Total time: #{format_duration(report.duration_ms)}",
        ""
      ] ++ format_result_suffix(report)

    Enum.join(lines, "\n")
  end

  defp format_result_suffix(%__MODULE__{failed: 0}), do: ["All notebooks passed! ✅"]

  defp format_result_suffix(%__MODULE__{failed_notebooks: failed_notebooks}) do
    format_failures(failed_notebooks)
  end

  @doc """
  Returns the CI exit code for a report.

  Returns `0` if all notebooks passed, `1` if any failed,
  and `2` if no notebooks were discovered.

  Suitable for use in CI/CD pipelines.

  ## Examples

      iex> report = %LivebookTest.Report{total: 1, passed: 1, failed: 0, duration_ms: 100, results: [], failed_notebooks: [], empty: false}
      iex> LivebookTest.Report.exit_code(report)
      0

      iex> report = %LivebookTest.Report{total: 1, passed: 0, failed: 1, duration_ms: 100, results: [], failed_notebooks: [], empty: false}
      iex> LivebookTest.Report.exit_code(report)
      1

      iex> report = %LivebookTest.Report{total: 0, passed: 0, failed: 0, duration_ms: 0, results: [], failed_notebooks: [], empty: true}
      iex> LivebookTest.Report.exit_code(report)
      2
  """
  @spec exit_code(t()) :: 0 | 1 | 2
  def exit_code(%__MODULE__{empty: true}), do: 2
  def exit_code(%__MODULE__{failed: 0}), do: 0
  def exit_code(%__MODULE__{}), do: 1

  @doc """
  Formats a report in verbose mode, including per-notebook details.

  Shows each notebook's status, duration, and output.

  ## Examples

      iex> results = [%LivebookTest.Runner{notebook_path: "a.livemd", script_path: "a.exs", exit_status: 0, stdout: "hello", stderr: "", duration_ms: 50, timed_out: false}]
      iex> report = LivebookTest.Report.build(results)
      iex> output = LivebookTest.Report.format_verbose(report)
      iex> String.contains?(output, "a.livemd")
      true
  """
  @spec format_verbose(t()) :: String.t()
  def format_verbose(%__MODULE__{} = report) do
    header = [
      "",
      "Notebook execution details:",
      String.duplicate("=", 40)
    ]

    details =
      Enum.map(report.results, fn result ->
        status = if LivebookTest.Runner.success?(result), do: "PASS", else: "FAIL"
        duration = format_duration(result.duration_ms)

        lines = [
          "",
          "  #{status} #{result.notebook_path} (#{duration})"
        ]

        lines =
          if result.stdout != "" do
            lines ++ ["    stdout:", indent(result.stdout, 6)]
          else
            lines
          end

        lines =
          if result.stderr != "" do
            lines ++ ["    stderr:", indent(result.stderr, 6)]
          else
            lines
          end

        Enum.join(lines, "\n")
      end)

    Enum.join(header ++ details ++ [format(report)], "\n")
  end

  defp format_failures(failed_notebooks) do
    [
      "",
      "Failed notebooks:",
      String.duplicate("-", 20)
      | Enum.flat_map(failed_notebooks, fn result ->
          [
            "",
            "  #{result.notebook_path}",
            "  exit: #{result.exit_status}"
          ] ++
            if(result.stderr != "",
              do: ["  stderr:", indent(result.stderr, 4)],
              else: []
            )
        end)
    ]
  end

  defp format_duration(ms) when ms < 1000, do: "#{ms}ms"
  defp format_duration(ms), do: "#{Float.round(ms / 1000, 1)}s"

  defp indent(string, spaces) do
    padding = String.duplicate(" ", spaces)

    string
    |> String.split("\n")
    |> Enum.map_join("\n", &"#{padding}#{&1}")
  end
end
