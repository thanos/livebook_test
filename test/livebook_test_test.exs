defmodule LivebookTestTest do
  use ExUnit.Case, async: false

  alias LivebookTest

  describe "run/1" do
    test "returns a map with config and report" do
      {config, report} = LivebookTest.run(paths: ["examples/basic.livemd"])

      assert is_struct(config, LivebookTest.Config)
      assert is_struct(report, LivebookTest.Report)
    end

    test "accepts mode option" do
      {config, _report} = LivebookTest.run(paths: ["examples/basic.livemd"], mode: :remote)
      assert config.dependency_mode == :remote
    end

    test "handles empty discovery" do
      {_config, report} = LivebookTest.run(paths: ["nonexistent/**/*.livemd"])
      assert report.total == 0
    end
  end
end
