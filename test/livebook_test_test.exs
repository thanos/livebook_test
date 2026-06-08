defmodule LivebookTestTest do
  use ExUnit.Case, async: false

  import Mox

  alias LivebookTest.{Config, Report, Runner}

  setup :verify_on_exit!

  describe "run/1" do
    test "returns tuple with config and report" do
      {config, report} = LivebookTest.run(paths: ["examples/basic.livemd"])

      assert is_struct(config, Config)
      assert is_struct(report, Report)
    end

    test "handles empty discovery" do
      {_config, report} = LivebookTest.run(paths: ["nonexistent/**/*.livemd"])
      assert report.empty == true
    end
  end

  describe "run/1 with local mode" do
    test "patches dependencies in local mode" do
      {config, report} =
        LivebookTest.run(
          paths: ["livebooks/local_dep.livemd"],
          mode: :local,
          local_deps: [livebook_test: "."]
        )

      assert config.dependency_mode == :local
      assert is_struct(report, Report)
    end
  end

  describe "run_with_config/2 with mock runner" do
    test "uses injected runner module" do
      mock_result = %Runner{
        notebook_path: "test.livemd",
        script_path: "test.exs",
        exit_status: 0,
        stdout: "ok",
        stderr: "",
        duration_ms: 50,
        timed_out: false
      }

      LivebookTest.MockRunner
      |> Mox.expect(:run_all, fn _pairs, _opts -> [mock_result] end)

      config = Config.resolve(paths: ["examples/basic.livemd"])
      report = LivebookTest.run_with_config(config, runner: LivebookTest.MockRunner)

      assert report.total == 1
      assert report.passed == 1
    end

    test "reports failures from mock runner" do
      mock_result = %Runner{
        notebook_path: "fail.livemd",
        script_path: "fail.exs",
        exit_status: 1,
        stdout: "",
        stderr: "boom",
        duration_ms: 100,
        timed_out: false
      }

      LivebookTest.MockRunner
      |> Mox.expect(:run_all, fn _pairs, _opts -> [mock_result] end)

      config = Config.resolve(paths: ["examples/basic.livemd"])
      report = LivebookTest.run_with_config(config, runner: LivebookTest.MockRunner)

      assert report.total == 1
      assert report.failed == 1
    end

    test "passes correct script pairs and timeout to runner" do
      mock_result = %Runner{
        notebook_path: "test.livemd",
        script_path: "test.exs",
        exit_status: 0,
        stdout: "ok",
        stderr: "",
        duration_ms: 50,
        timed_out: false
      }

      LivebookTest.MockRunner
      |> Mox.expect(:run_all, fn pairs, opts ->
        assert Enum.all?(pairs, fn {nb, script} ->
                 is_binary(nb) and is_binary(script)
               end)

        assert Keyword.get(opts, :timeout) == 60_000
        [mock_result]
      end)

      config = Config.resolve(paths: ["examples/basic.livemd"], timeout: 60_000)
      LivebookTest.run_with_config(config, runner: LivebookTest.MockRunner)
    end
  end

  describe "run_and_report/1" do
    test "prints report and returns exit code 0 for passing notebooks" do
      output =
        ExUnit.CaptureIO.capture_io(fn ->
          result =
            LivebookTest.run_and_report(
              paths: ["examples/basic.livemd"],
              runner: LivebookTest.Runner
            )

          assert result == 0
        end)

      assert output =~ "notebooks"
    end

    test "prints report and returns exit code for empty discovery" do
      output =
        ExUnit.CaptureIO.capture_io(fn ->
          result = LivebookTest.run_and_report(paths: ["nonexistent/**/*.livemd"])
          assert result == 2
        end)

      assert output =~ "0 notebooks found"
    end

    test "prints verbose report when verbose is true" do
      output =
        ExUnit.CaptureIO.capture_io(fn ->
          LivebookTest.run_and_report(
            paths: ["examples/basic.livemd"],
            verbose: true
          )
        end)

      assert output =~ "Notebook execution details:"
    end
  end
end
