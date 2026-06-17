defmodule Mix.Tasks.Livebook.TestTest do
  use ExUnit.Case, async: false

  alias Mix.Tasks.Livebook.Test, as: LivebookTestTask

  describe "build_config_from_opts/1" do
    test "parses path option" do
      config = LivebookTestTask.build_config_from_opts(path: "notebooks/**/*.livemd")
      assert config.paths == ["notebooks/**/*.livemd"]
    end

    test "parses multiple path options" do
      config = LivebookTestTask.build_config_from_opts(path: "a.livemd", path: "b.livemd")
      assert config.paths == ["a.livemd", "b.livemd"]
    end

    test "parses exclude option" do
      config = LivebookTestTask.build_config_from_opts(exclude: "**/broken/**/*.livemd")
      assert config.exclude == ["**/broken/**/*.livemd"]
    end

    test "parses multiple exclude options" do
      config =
        LivebookTestTask.build_config_from_opts(exclude: "**/broken/**", exclude: "**/skip/**")

      assert config.exclude == ["**/broken/**", "**/skip/**"]
    end

    test "preserves default excludes when explicit path given without excludes" do
      config = LivebookTestTask.build_config_from_opts(path: "specific.livemd")
      assert config.paths == ["specific.livemd"]
      assert config.exclude == LivebookTest.Config.resolve([]).exclude
    end

    test "parses mode: local" do
      config = LivebookTestTask.build_config_from_opts(mode: "local")
      assert config.dependency_mode == :local
    end

    test "parses mode: remote" do
      config = LivebookTestTask.build_config_from_opts(mode: "remote")
      assert config.dependency_mode == :remote
    end

    test "parses timeout as seconds string" do
      config = LivebookTestTask.build_config_from_opts(timeout: "60")
      assert config.timeout == 60_000
    end

    test "raises on invalid timeout value" do
      assert_raise Mix.Error, ~r/Invalid --timeout/, fn ->
        LivebookTestTask.build_config_from_opts(timeout: "abc")
      end
    end

    test "raises on invalid mode value" do
      assert_raise Mix.Error, ~r/Invalid --mode/, fn ->
        LivebookTestTask.build_config_from_opts(mode: "invalid")
      end
    end

    test "parses verbose: true" do
      config = LivebookTestTask.build_config_from_opts(verbose: true)
      assert config.verbose == true
    end

    test "parses mode as atom" do
      config = LivebookTestTask.build_config_from_opts(mode: :local)
      assert config.dependency_mode == :local
    end

    test "parses timeout as integer seconds" do
      config = LivebookTestTask.build_config_from_opts(timeout: 90_000)
      assert config.timeout == 90_000
    end

    test "parses verbose: false" do
      config = LivebookTestTask.build_config_from_opts(verbose: false)
      assert config.verbose == false
    end

    test "returns config with defaults for empty options" do
      config = LivebookTestTask.build_config_from_opts([])
      assert is_struct(config, LivebookTest.Config)
      assert is_list(config.paths)
      assert config.dependency_mode in [:remote, :local]
    end
  end

  describe "run/1" do
    test "runs successfully for passing notebooks" do
      output =
        ExUnit.CaptureIO.capture_io(fn ->
          LivebookTestTask.run(["--path", "examples/basic.livemd"])
        end)

      assert output =~ "notebooks"
    end

    test "raises when notebooks fail" do
      broken_path =
        Path.join(System.tmp_dir!(), "lt_broken_#{:erlang.unique_integer([:positive])}.livemd")

      File.write!(broken_path, """
      # Test

      ```elixir
      raise "deliberate failure"
      ```
      """)

      on_exit(fn -> File.rm(broken_path) end)

      assert_raise Mix.Error, ~r/Livebook tests failed/, fn ->
        ExUnit.CaptureIO.capture_io(fn ->
          LivebookTestTask.run(["--path", broken_path])
        end)
      end
    end

    test "raises when no notebooks discovered" do
      assert_raise Mix.Error, ~r/Livebook tests failed/, fn ->
        ExUnit.CaptureIO.capture_io(fn ->
          LivebookTestTask.run(["--path", "nonexistent/**/*.livemd"])
        end)
      end
    end

    test "raises on invalid --timeout value via CLI" do
      assert_raise Mix.Error, ~r/Invalid --timeout value/, fn ->
        ExUnit.CaptureIO.capture_io(fn ->
          LivebookTestTask.run(["--path", "examples/basic.livemd", "--timeout", "abc"])
        end)
      end
    end

    test "passes with verbose flag" do
      output =
        ExUnit.CaptureIO.capture_io(fn ->
          LivebookTestTask.run(["--path", "examples/basic.livemd", "--verbose"])
        end)

      assert output =~ "Notebook execution details:"
    end

    test "raises on invalid CLI options" do
      assert_raise Mix.Error, ~r/Invalid options provided/, fn ->
        ExUnit.CaptureIO.capture_io(fn ->
          LivebookTestTask.run(["--path", "examples/basic.livemd", "--verbose=not-a-boolean"])
        end)
      end
    end
  end
end
