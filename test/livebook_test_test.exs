defmodule LivebookTestTest do
  use ExUnit.Case, async: false

  import Mox

  alias LivebookTest.{Config, Report, Runner}

  doctest LivebookTest, only: [run_with_config: 2]

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
    test "rewrites notebook Mix.install deps to local paths" do
      abs_path = Path.expand(".")

      mock_result = %Runner{
        notebook_path: "livebooks/local_dep.livemd",
        script_path: "patched.exs",
        exit_status: 0,
        stdout: "",
        stderr: "",
        duration_ms: 50,
        timed_out: false
      }

      LivebookTest.MockRunner
      |> Mox.expect(:run_all, fn pairs, _opts ->
        assert length(pairs) == 1

        {notebook_path, script_path} = hd(pairs)
        assert notebook_path == "livebooks/local_dep.livemd"

        content = File.read!(script_path)
        assert content =~ "{:jason, path: #{inspect(abs_path)}}"
        refute content =~ "~> 1.4"

        [mock_result]
      end)

      config =
        Config.resolve(
          paths: ["livebooks/local_dep.livemd"],
          dependency_mode: :local,
          local_deps: [jason: "."]
        )

      report = LivebookTest.run_with_config(config, runner: LivebookTest.MockRunner)

      assert report.passed == 1
      assert report.failed == 0
    end
  end

  describe "run/1 options" do
    test "passes runner and preflight through run/1" do
      LivebookTest.MockRunner
      |> Mox.expect(:run_all, fn _pairs, _opts -> [] end)

      {_config, report} =
        LivebookTest.run(
          paths: ["nonexistent/**/*.livemd"],
          runner: LivebookTest.MockRunner,
          preflight: false
        )

      assert report.empty == true
    end
  end

  describe "run_with_config/2 with mock runner" do
    test "skips preflight when disabled" do
      LivebookTest.MockRunner
      |> Mox.expect(:run_all, fn _pairs, _opts -> [] end)

      config = Config.resolve(paths: ["nonexistent/**/*.livemd"])

      assert %Report{empty: true} =
               LivebookTest.run_with_config(config,
                 runner: LivebookTest.MockRunner,
                 preflight: false
               )
    end

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

  describe "run_with_config/2 verbose error logging" do
    setup do
      on_exit(fn ->
        Application.delete_env(:livebook_test, :exporter_module)
      end)

      Application.put_env(:livebook_test, :exporter_module, LivebookTest.TestExporter)
      :ok
    end

    test "logs export failures when verbose" do
      path = Path.join(System.tmp_dir!(), "fail_export.livemd")
      File.write!(path, "# noop\n")
      on_exit(fn -> File.rm(path) end)

      LivebookTest.MockRunner
      |> Mox.expect(:run_all, fn pairs, _opts ->
        assert pairs == []
        []
      end)

      config = Config.resolve(paths: [path], verbose: true)

      output =
        ExUnit.CaptureIO.capture_io(fn ->
          LivebookTest.run_with_config(config,
            runner: LivebookTest.MockRunner,
            preflight: false
          )
        end)

      assert output =~ "Failed to export #{path}"
    end

    test "logs patch read failures when verbose" do
      path = Path.join(System.tmp_dir!(), "fail_read.livemd")
      File.write!(path, "# noop\n")
      on_exit(fn -> File.rm(path) end)

      LivebookTest.MockRunner
      |> Mox.expect(:run_all, fn pairs, _opts ->
        assert length(pairs) == 1
        []
      end)

      config =
        Config.resolve(
          paths: [path],
          dependency_mode: :local,
          local_deps: [my_lib: "."],
          verbose: true
        )

      output =
        ExUnit.CaptureIO.capture_io(fn ->
          LivebookTest.run_with_config(config,
            runner: LivebookTest.MockRunner,
            preflight: false
          )
        end)

      assert output =~ "Failed to read script"
    end

    test "logs patch write failures when verbose" do
      path = Path.join(System.tmp_dir!(), "fail_write.livemd")
      File.write!(path, "# noop\n")
      on_exit(fn -> File.rm(path) end)

      LivebookTest.MockRunner
      |> Mox.expect(:run_all, fn pairs, _opts ->
        assert length(pairs) == 1
        []
      end)

      config =
        Config.resolve(
          paths: [path],
          dependency_mode: :local,
          local_deps: [my_lib: "."],
          verbose: true
        )

      output =
        ExUnit.CaptureIO.capture_io(fn ->
          LivebookTest.run_with_config(config,
            runner: LivebookTest.MockRunner,
            preflight: false
          )
        end)

      assert output =~ "Failed to write patched script"
    end
  end

  describe "run_and_report/1" do
    test "prints report and returns exit code 0 for passing notebooks" do
      output =
        ExUnit.CaptureIO.capture_io(fn ->
          result =
            LivebookTest.run_and_report(paths: ["examples/basic.livemd"])

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

    test "passes runner through run_and_report/1" do
      LivebookTest.MockRunner
      |> Mox.expect(:run_all, fn _pairs, _opts -> [] end)

      output =
        ExUnit.CaptureIO.capture_io(fn ->
          result =
            LivebookTest.run_and_report(
              paths: ["nonexistent/**/*.livemd"],
              runner: LivebookTest.MockRunner,
              preflight: false
            )

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
