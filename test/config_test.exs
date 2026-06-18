defmodule LivebookTest.ConfigTest do
  use ExUnit.Case, async: true

  alias LivebookTest.Config

  doctest Config

  describe "resolve/1" do
    test "returns a Config struct with defaults" do
      config = Config.resolve()
      assert is_struct(config, Config)
      assert is_list(config.paths)
      assert is_list(config.exclude)
      assert config.dependency_mode in [:remote, :local]
      assert is_integer(config.timeout)
      assert is_list(config.local_deps)
      assert is_boolean(config.verbose)
    end

    test "accepts path overrides" do
      config = Config.resolve(paths: ["custom/**/*.livemd"])
      assert config.paths == ["custom/**/*.livemd"]
    end

    test "accepts exclude overrides" do
      config = Config.resolve(exclude: ["**/broken/**/*.livemd"])
      assert config.exclude == ["**/broken/**/*.livemd"]
    end

    test "accepts dependency_mode overrides" do
      config = Config.resolve(dependency_mode: :local)
      assert config.dependency_mode == :local
    end

    test "accepts timeout overrides" do
      config = Config.resolve(timeout: 120_000)
      assert config.timeout == 120_000
    end

    test "accepts local_deps overrides" do
      config = Config.resolve(local_deps: [my_lib: "."])
      assert config.local_deps == [my_lib: "."]
    end

    test "accepts verbose overrides" do
      config = Config.resolve(verbose: true)
      assert config.verbose == true
    end
  end
end
