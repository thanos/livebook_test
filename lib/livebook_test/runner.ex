defmodule LivebookTest.Runner do
  @moduledoc """
  Executes exported Elixir scripts and collects results.

  This is the fourth stage in the LivebookTest pipeline:

      Discovery → Exporter → DependencyPatcher → **Runner** → Report

  The runner executes each `.exs` script as a subprocess using
  `System.cmd/3`, collecting:

    - Exit status (0 = success, non-zero = failure)
    - Captured stdout
    - Captured stderr (merged into stdout via `stderr_to_stdout: true`)
    - Execution timing

  ## Why subprocess execution?

  Livebook notebooks often call `Mix.install/2`, which modifies the
  global application environment. Running scripts in isolated subprocesses
  prevents side effects from leaking between notebook tests.

  > **Note on timeouts**: When a notebook execution times out, the BEAM
  > task is shut down via `Task.shutdown/2`. However, the underlying
  > `elixir` OS process may continue running (e.g., during a lengthy
  > `Mix.install` compilation). This is a known limitation of
  > `System.cmd`-based subprocess management. If this becomes an issue,
  > consider configuring a shorter timeout or using a process supervision
  > strategy that tracks OS process lifecycles.

  ## Examples

      iex> {:ok, script_path} = LivebookTest.Exporter.to_temp_file("examples/basic.livemd")
      iex> {:ok, result} = LivebookTest.Runner.run(script_path)
      iex> result.exit_status
      0
  """

  @behaviour LivebookTest.Runner.Behaviour

  @typedoc "Result of a single notebook execution"
  @type run_result :: %__MODULE__{
          notebook_path: Path.t(),
          script_path: Path.t(),
          exit_status: non_neg_integer(),
          stdout: String.t(),
          stderr: String.t(),
          duration_ms: non_neg_integer(),
          timed_out: boolean()
        }

  @enforce_keys [
    :notebook_path,
    :script_path,
    :exit_status,
    :stdout,
    :stderr,
    :duration_ms,
    :timed_out
  ]

  defstruct [
    :notebook_path,
    :script_path,
    :exit_status,
    :stdout,
    :stderr,
    :duration_ms,
    :timed_out
  ]

  @typedoc "Outcome of running a single script"
  @type run_outcome :: {:ok, run_result()} | {:error, term()}

  @doc """
  Runs an Elixir script and collects execution results.

  Executes `elixir <script_path>` as a subprocess with the
  given timeout. Returns a structured result with exit status,
  output, and timing information.

  ## Examples

      iex> {:ok, script_path} = LivebookTest.Exporter.to_temp_file("examples/basic.livemd")
      iex> {:ok, result} = LivebookTest.Runner.run(script_path)
      iex> is_integer(result.exit_status)
      true
  """
  @spec run(Path.t(), keyword()) :: run_outcome()
  @impl true
  def run(script_path, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 60_000)
    notebook_path = Keyword.get(opts, :notebook_path, script_path)

    start_time = System.monotonic_time(:millisecond)

    task =
      Task.async(fn ->
        System.cmd("elixir", [script_path],
          stderr_to_stdout: true,
          env: [{"MIX_ENV", "test"}]
        )
      end)

    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, {output, exit_status}} ->
        duration_ms = System.monotonic_time(:millisecond) - start_time

        {:ok,
         %__MODULE__{
           notebook_path: notebook_path,
           script_path: script_path,
           exit_status: exit_status,
           stdout: output,
           stderr: "",
           duration_ms: duration_ms,
           timed_out: false
         }}

      nil ->
        duration_ms = System.monotonic_time(:millisecond) - start_time

        {:ok,
         %__MODULE__{
           notebook_path: notebook_path,
           script_path: script_path,
           exit_status: 1,
           stdout: "",
           stderr: "Execution timed out after #{timeout}ms",
           duration_ms: duration_ms,
           timed_out: true
         }}
    end
  rescue
    e -> {:error, {:execution_failed, Exception.message(e)}}
  end

  @doc """
  Runs multiple scripts sequentially, collecting all results.

  Returns a list of results in the same order as the input scripts.

  ## Examples

      iex> paths = []
      iex> results = LivebookTest.Runner.run_all(paths)
      iex> results
      []
  """
  @spec run_all([{Path.t(), Path.t()}], keyword()) :: [run_result()]
  @impl true
  def run_all(script_pairs, opts \\ []) when is_list(script_pairs) do
    timeout = Keyword.get(opts, :timeout, 60_000)

    Enum.map(script_pairs, fn {notebook_path, script_path} ->
      run_opts = Keyword.put(opts, :timeout, timeout)
      run_opts = Keyword.put(run_opts, :notebook_path, notebook_path)

      case run(script_path, run_opts) do
        {:ok, result} -> result
        {:error, reason} -> error_result(reason, notebook_path)
      end
    end)
  end

  @doc """
  Returns whether a run result indicates success.

  ## Examples

      iex> result = %LivebookTest.Runner{notebook_path: "a.livemd", script_path: "a.exs", exit_status: 0, stdout: "", stderr: "", duration_ms: 100, timed_out: false}
      iex> LivebookTest.Runner.success?(result)
      true

      iex> result = %LivebookTest.Runner{notebook_path: "a.livemd", script_path: "a.exs", exit_status: 1, stdout: "", stderr: "error", duration_ms: 100, timed_out: false}
      iex> LivebookTest.Runner.success?(result)
      false
  """
  @spec success?(run_result()) :: boolean()
  def success?(%__MODULE__{exit_status: 0, timed_out: false}), do: true
  def success?(%__MODULE__{}), do: false

  defp error_result(reason, notebook_path) do
    %__MODULE__{
      notebook_path: notebook_path,
      script_path: "",
      exit_status: 1,
      stdout: "",
      stderr: inspect(reason),
      duration_ms: 0,
      timed_out: false
    }
  end
end
