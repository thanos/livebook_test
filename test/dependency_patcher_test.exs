defmodule LivebookTest.DependencyPatcherTest do
  use ExUnit.Case, async: true

  alias LivebookTest.DependencyPatcher

  doctest DependencyPatcher

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

      assert String.contains?(patched, "path: #{inspect(Path.expand("."))}")
      refute String.contains?(patched, "~> 0.5")
    end

    test "patches >= version specifier" do
      script = "Mix.install([{:ex_arrow, \">= 0.5.0\"}])"
      patched = DependencyPatcher.patch(script, :local, ex_arrow: ".")

      assert String.contains?(patched, "{:ex_arrow, path: #{inspect(Path.expand("."))}}")
      refute String.contains?(patched, ">=")
    end

    test "patches == version specifier" do
      script = "Mix.install([{:ex_arrow, \"== 1.2.3\"}])"
      patched = DependencyPatcher.patch(script, :local, ex_arrow: ".")

      assert String.contains?(patched, "{:ex_arrow, path: #{inspect(Path.expand("."))}}")
      refute String.contains?(patched, "==")
    end

    test "patches exact version specifier" do
      script = "Mix.install([{:ex_arrow, \"1.2.3\"}])"
      patched = DependencyPatcher.patch(script, :local, ex_arrow: ".")

      assert String.contains?(patched, "{:ex_arrow, path: #{inspect(Path.expand("."))}}")
    end

    test "patches multiple dependencies" do
      script = "Mix.install([{:ex_arrow, \"~> 0.5\"}, {:ex_datalog, \"~> 1.0\"}])"

      patched =
        DependencyPatcher.patch(script, :local, ex_arrow: ".", ex_datalog: "../ex_datalog")

      assert String.contains?(patched, "{:ex_arrow, path: #{inspect(Path.expand("."))}}")

      assert String.contains?(
               patched,
               "{:ex_datalog, path: #{inspect(Path.expand("../ex_datalog"))}}"
             )
    end

    test "leaves unlisted dependencies unchanged" do
      script = "Mix.install([{:ex_arrow, \"~> 0.5\"}, {:other_lib, \"~> 2.0\"}])"
      patched = DependencyPatcher.patch(script, :local, ex_arrow: ".")

      assert String.contains?(patched, "{:ex_arrow, path: #{inspect(Path.expand("."))}}")
      assert String.contains?(patched, "{:other_lib, \"~> 2.0\"}")
    end

    test "patches dependencies with additional options" do
      script = "Mix.install([{:ex_arrow, \"~> 0.5\", only: :dev}])"
      patched = DependencyPatcher.patch(script, :local, ex_arrow: ".")

      assert String.contains?(patched, "{:ex_arrow, path: #{inspect(Path.expand("."))}}")
      refute String.contains?(patched, "~> 0.5")
      refute String.contains?(patched, "only:")
    end

    test "patches dependencies with repo option" do
      script = "Mix.install([{:ex_arrow, \"~> 0.5\", repo: \"hexpm\"}])"
      patched = DependencyPatcher.patch(script, :local, ex_arrow: ".")

      assert String.contains?(patched, "{:ex_arrow, path: #{inspect(Path.expand("."))}}")
      refute String.contains?(patched, "hexpm")
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

      assert String.contains?(patched, "{:ex_arrow, path: #{inspect(Path.expand("."))}}")
      assert String.contains?(patched, "IO.puts(\"hello\")")
      assert String.contains?(patched, "# Header")
    end

    test "accepts map local_deps" do
      script = "Mix.install([{:ex_arrow, \"~> 0.5\"}])"
      patched = DependencyPatcher.patch(script, :local, %{ex_arrow: "."})

      assert String.contains?(patched, "path: #{inspect(Path.expand("."))}")
    end

    test "patches quoted path dependency to absolute local path" do
      script = ~s|Mix.install([{:ex_arrow, path: "../ex_arrow"}])|
      patched = DependencyPatcher.patch(script, :local, ex_arrow: ".")

      assert patched == ~s|Mix.install([{:ex_arrow, path: "#{Path.expand(".")}"}])|
    end

    test "patches Path.join path dependency to absolute local path" do
      script = ~s|Mix.install([{:ex_arrow, path: Path.join(__DIR__, "..")}])|
      patched = DependencyPatcher.patch(script, :local, ex_arrow: ".")

      assert patched == ~s|Mix.install([{:ex_arrow, path: "#{Path.expand(".")}"}])|
    end

    test "leaves path deps not listed in local_deps unchanged" do
      script = ~s|Mix.install([{:other_lib, path: "../other"}])|
      patched = DependencyPatcher.patch(script, :local, ex_arrow: ".")

      assert patched == script
    end
  end

  describe "patch/3 with edge cases" do
    test "returns script unchanged for empty string" do
      assert DependencyPatcher.patch("", :local, []) == ""
    end

    test "returns script unchanged when no Mix.install present" do
      script = "IO.puts(:hello)"
      assert DependencyPatcher.patch(script, :local, ex_arrow: ".") == script
    end
  end
end
