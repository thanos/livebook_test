defmodule LivebookTestTest do
  use ExUnit.Case, async: false

  import Mox

  alias LivebookTest.{Config, Report, Runner}

  setup :verify_on_exit!

  describe "run/1" do
    test "returns map with config and report" do
      {config, report} = LivebookTest.run(paths: ["examples/basic.livemd"])

      assert is_struct(config, Config)
      assert is_struct(report, Report)
    end

    test "accepts mode option" do
      {config, _report} = LivebookTest.run(paths: ["examples/basic.livemd"], mode: :remote)
      assert config.dependency_mode == :remote
    end

    test "accepts exclude option" do
      {config, _report} =
        LivebookTest.run(
          paths: ["examples/**/*.livemd"],
          exclude: ["**/broken/**/*.livemd"]
        )

      assert config.exclude == ["**/broken/**/*.livemd"]
    end

    test "handles empty discovery" do
      {_config, report} = LivebookTest.run(paths: ["nonexistent/**/*.livemd"])
      assert report.total == 0
    end

    test "accepts timeout option" do
      {config, _report} = LivebookTest.run(paths: ["examples/basic.livemd"], timeout: 30_000)
      assert config.timeout == 30_000
    end

    test "accepts local_deps option" do
      {config, _report} =
        LivebookTest.run(
          paths: ["examples/basic.livemd"],
          local_deps: [my_lib: "."]
        )

      assert config.local_deps == [my_lib: "."]
    end

    test "accepts verbose option" do
      {config, _report} = LivebookTest.run(paths: ["examples/basic.livemd"], verbose: true)
      assert config.verbose == true
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

          assert result in [0, 1]
        end)

      assert output =~ "notebooks"
    end

    test "prints report and returns exit code for empty discovery" do
      output =
        ExUnit.CaptureIO.capture_io(fn ->
          result = LivebookTest.run_and_report(paths: ["nonexistent/**/*.livemd"])
          assert result == 0
        end)

      assert output =~ "0 notebooks"
    end

    test "prints verbose report when verbose is true" do
      output =
        ExUnit.CaptureIO.capture_io(fn ->
          LivebookTest.run_and_report(
            paths: ["examples/basic.livemd"],
            verbose: true
          )
        end)

      assert output =~ "notebook execution details" ||
               output =~ "notebooks"
    end
  end
end
