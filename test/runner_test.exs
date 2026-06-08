defmodule LivebookTest.RunnerTest do
  use ExUnit.Case, async: false

  alias LivebookTest.Runner

  describe "run/2" do
    test "executes a simple script successfully" do
      script_path =
        Path.join(System.tmp_dir!(), "lt_success_#{:erlang.unique_integer([:positive])}.exs")

      File.write!(script_path, "IO.puts(:hello)")
      on_exit(fn -> File.rm(script_path) end)

      {:ok, result} = Runner.run(script_path)
      assert result.exit_status == 0
      assert result.timed_out == false
    end

    test "captures stdout" do
      script_path =
        Path.join(System.tmp_dir!(), "lt_output_#{:erlang.unique_integer([:positive])}.exs")

      File.write!(script_path, "IO.puts(\"captured output\")")
      on_exit(fn -> File.rm(script_path) end)

      {:ok, result} = Runner.run(script_path)
      assert String.contains?(result.stdout, "captured output")
    end

    test "reports failure for raising script" do
      script_path =
        Path.join(System.tmp_dir!(), "lt_fail_#{:erlang.unique_integer([:positive])}.exs")

      File.write!(script_path, "raise \"test failure\"")
      on_exit(fn -> File.rm(script_path) end)

      {:ok, result} = Runner.run(script_path)
      assert result.exit_status != 0
    end

    test "reports failure for non-existent script" do
      {:ok, result} = Runner.run("/nonexistent/path/script.exs")
      assert result.exit_status != 0
    end

    test "reports timeout for long-running script" do
      script_path =
        Path.join(System.tmp_dir!(), "lt_slow_#{:erlang.unique_integer([:positive])}.exs")

      File.write!(script_path, "Process.sleep(5000)")

      on_exit(fn -> File.rm(script_path) end)

      {:ok, result} = Runner.run(script_path, timeout: 200)
      assert result.timed_out == true
      assert result.notebook_path == script_path
    end
  end

  describe "run_all/2" do
    test "runs multiple scripts" do
      id = :erlang.unique_integer([:positive])
      script1 = Path.join(System.tmp_dir!(), "lt_one_#{id}.exs")
      script2 = Path.join(System.tmp_dir!(), "lt_two_#{id}.exs")
      File.write!(script1, "IO.puts(:one)")
      File.write!(script2, "IO.puts(:two)")

      on_exit(fn ->
        File.rm(script1)
        File.rm(script2)
      end)

      pairs = [{"one.livemd", script1}, {"two.livemd", script2}]

      results = Runner.run_all(pairs)
      assert length(results) == 2
    end

    test "returns empty list for empty input" do
      assert Runner.run_all([]) == []
    end

    test "preserves notebook paths in results" do
      id = :erlang.unique_integer([:positive])
      script = Path.join(System.tmp_dir!(), "lt_nb_#{id}.exs")
      File.write!(script, "IO.puts(:ok)")
      on_exit(fn -> File.rm(script) end)

      pairs = [{"my_notebook.livemd", script}]
      [result] = Runner.run_all(pairs, timeout: 30_000)

      assert result.notebook_path == "my_notebook.livemd"
    end

    test "handles error results from run/2 preserving notebook path" do
      pairs = [{"missing.livemd", "/nonexistent/script.exs"}]
      [result] = Runner.run_all(pairs, timeout: 30_000)

      assert result.notebook_path == "missing.livemd"
      assert result.exit_status != 0
    end
  end

  describe "success?/1" do
    test "returns true for exit status 0 and no timeout" do
      result = %Runner{
        notebook_path: "a.livemd",
        script_path: "a.exs",
        exit_status: 0,
        stdout: "",
        stderr: "",
        duration_ms: 100,
        timed_out: false
      }

      assert Runner.success?(result) == true
    end

    test "returns false for non-zero exit status" do
      result = %Runner{
        notebook_path: "a.livemd",
        script_path: "a.exs",
        exit_status: 1,
        stdout: "",
        stderr: "error",
        duration_ms: 100,
        timed_out: false
      }

      assert Runner.success?(result) == false
    end

    test "returns false for timed out result" do
      result = %Runner{
        notebook_path: "a.livemd",
        script_path: "a.exs",
        exit_status: 0,
        stdout: "",
        stderr: "",
        duration_ms: 100,
        timed_out: true
      }

      assert Runner.success?(result) == false
    end
  end
end
