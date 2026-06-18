defmodule LivebookTest.DiscoveryTest do
  use ExUnit.Case, async: true

  alias LivebookTest.Discovery

  doctest Discovery

  describe "find/1" do
    test "finds notebooks matching glob patterns" do
      paths = Discovery.find(["examples/**/*.livemd"])
      assert is_list(paths)
      assert length(paths) > 0
    end

    test "returns empty list for non-matching patterns" do
      paths = Discovery.find(["nonexistent/**/*.livemd"])
      assert paths == []
    end

    test "returns only .livemd files" do
      paths = Discovery.find(["examples/**/*.livemd"])
      assert Enum.all?(paths, &String.ends_with?(&1, ".livemd"))
    end

    test "deduplicates results" do
      paths = Discovery.find(["examples/**/*.livemd", "examples/**/*.livemd"])
      assert length(paths) == length(Enum.uniq(paths))
    end

    test "returns sorted results" do
      paths = Discovery.find(["examples/**/*.livemd"])
      assert paths == Enum.sort(paths)
    end
  end

  describe "find/1 with single pattern" do
    test "accepts a binary pattern" do
      paths = Discovery.find("examples/**/*.livemd")
      assert is_list(paths)
    end

    test "returns empty list for non-matching pattern" do
      paths = Discovery.find("nonexistent/**/*.livemd")
      assert paths == []
    end
  end

  describe "find/2 with exclude" do
    test "excludes notebooks matching exclusion patterns" do
      all_paths = Discovery.find(["examples/**/*.livemd"])

      excluded_paths =
        Discovery.find(["examples/**/*.livemd"], exclude: ["**/broken/**/*.livemd"])

      assert length(all_paths) > length(excluded_paths)
      refute Enum.any?(excluded_paths, &String.contains?(&1, "/broken/"))
    end

    test "excludes broken notebooks" do
      paths = Discovery.find(["examples/**/*.livemd"], exclude: ["**/broken/**/*.livemd"])

      refute Enum.any?(paths, &String.contains?(&1, "/broken/"))
    end

    test "does not exclude when no exclusion patterns" do
      paths = Discovery.find(["examples/**/*.livemd"], exclude: [])
      all_paths = Discovery.find(["examples/**/*.livemd"])

      assert paths == all_paths
    end

    test "exclude matches expanded paths by exact string identity" do
      all = Discovery.find(["examples/**/*.livemd"])
      assert length(all) > 0

      # Equivalent globs expand to the same path strings on all platforms checked in CI.
      with_dot_prefix =
        Discovery.find(["examples/**/*.livemd"], exclude: ["./examples/**/*.livemd"])

      assert with_dot_prefix == []

      # A non-matching exclude pattern expands to nothing and leaves discovery unchanged.
      with_typo = Discovery.find(["examples/**/*.livemd"], exclude: ["examples/**/basix.livemd"])
      assert with_typo == all
    end
  end

  describe "count/1" do
    test "returns 0 for non-matching patterns" do
      assert Discovery.count(["nonexistent/**/*.livemd"]) == 0
    end

    test "returns count for matching patterns" do
      count = Discovery.count(["examples/**/*.livemd"])
      assert count > 0
    end
  end
end
