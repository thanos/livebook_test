defmodule LivebookTest.DependencyPatcherTest do
  use ExUnit.Case, async: true

  alias LivebookTest.DependencyPatcher

  describe "patch/3 with :remote mode" do
    test "returns script unchanged" do
      script = "Mix.install([{:ex_arrow, \"~> 0.5\"}])"
      assert DependencyPatcher.patch(script, :remote, []) == script
    end

    test "ignores local_deps in remote mode" do
      script = "Mix.install([{:ex_arrow, \"~> 0.5\"}])"
      assert DependencyPatcher.patch(script, :remote, ex_arrow: ".") == script
    end
  end

  describe "patch/3 with :local mode" do
    test "patches a single Hex dependency to local path" do
      script = "Mix.install([{:ex_arrow, \"~> 0.5\"}])"
      patched = DependencyPatcher.patch(script, :local, ex_arrow: ".")

      assert String.contains?(patched, "path: \".\"")
      refute String.contains?(patched, "~> 0.5")
    end

    test "patches multiple dependencies" do
      script = "Mix.install([{:ex_arrow, \"~> 0.5\"}, {:ex_datalog, \"~> 1.0\"}])"

      patched =
        DependencyPatcher.patch(script, :local, ex_arrow: ".", ex_datalog: "../ex_datalog")

      assert String.contains?(patched, "{:ex_arrow, path: \".\"}")
      assert String.contains?(patched, "{:ex_datalog, path: \"../ex_datalog\"}")
    end

    test "leaves unlisted dependencies unchanged" do
      script = "Mix.install([{:ex_arrow, \"~> 0.5\"}, {:other_lib, \"~> 2.0\"}])"
      patched = DependencyPatcher.patch(script, :local, ex_arrow: ".")

      assert String.contains?(patched, "{:ex_arrow, path: \".\"}")
      assert String.contains?(patched, "{:other_lib, \"~> 2.0\"}")
    end

    test "patches dependencies with additional options" do
      script = "Mix.install([{:ex_arrow, \"~> 0.5\", only: :dev}])"
      patched = DependencyPatcher.patch(script, :local, ex_arrow: ".")

      assert String.contains?(patched, "{:ex_arrow, path: \".\"}")
    end

    test "handles empty local_deps" do
      script = "Mix.install([{:ex_arrow, \"~> 0.5\"}])"
      patched = DependencyPatcher.patch(script, :local, [])
      assert patched == script
    end

    test "preserves rest of script" do
      script = """
      # Header
      Mix.install([{:ex_arrow, "~> 0.5"}])

      IO.puts("hello")
      """

      patched = DependencyPatcher.patch(script, :local, ex_arrow: ".")

      assert String.contains?(patched, "{:ex_arrow, path: \".\"}")
      assert String.contains?(patched, "IO.puts(\"hello\")")
      assert String.contains?(patched, "# Header")
    end
  end
end
