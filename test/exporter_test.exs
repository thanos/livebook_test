defmodule LivebookTest.ExporterTest do
  use ExUnit.Case, async: false

  alias LivebookTest.Exporter
  alias LivebookTest.TestSupport

  doctest Exporter, except: [to_temp_file: 1, to_temp_file_from_string: 1]

  describe "to_elixir/1" do
    test "exports a valid notebook to Elixir script" do
      {:ok, script} = Exporter.to_elixir("examples/basic.livemd")
      assert is_binary(script)
    end

    test "returns error for non-existent file when exporting" do
      assert {:error, :enoent} = Exporter.to_elixir("/nonexistent/notebook.livemd")
    end

    test "returns error for non-existent file when writing temp file" do
      assert {:error, :enoent} = Exporter.to_temp_file("/nonexistent/notebook.livemd")
    end
  end

  describe "to_elixir_from_string/1" do
    test "converts notebook content to script" do
      content = "# Test\n\n## Section\n\n```elixir\nIO.puts(:hello)\n```"
      {:ok, script} = Exporter.to_elixir_from_string(content)
      assert is_binary(script)
    end

    test "handles empty content" do
      assert {:ok, _script} = Exporter.to_elixir_from_string("# Empty\n")
    end

    test "returns error when file does not exist" do
      assert {:error, :enoent} = Exporter.to_elixir("/definitely/not/a/real/file/path.livemd")
    end
  end

  describe "to_temp_file/1" do
    test "creates a temporary .exs file" do
      {:ok, path} = Exporter.to_temp_file("examples/basic.livemd")
      assert String.ends_with?(path, ".exs")
      assert File.exists?(path)

      on_exit(fn -> File.rm(path) end)
    end
  end

  describe "to_temp_file_from_string/1" do
    test "creates a temporary .exs file from content" do
      content = "# Content Test\n\n## Section\n\n```elixir\nIO.puts(\"test\")\n```"

      {:ok, path} = Exporter.to_temp_file_from_string(content)
      assert String.ends_with?(path, ".exs")
      assert File.exists?(path)

      on_exit(fn -> File.rm(path) end)
    end

    test "returns write_failed error when temp directory is not writable" do
      content = "# Test\n\n```elixir\n1 + 1\n```"

      read_only_dir =
        Path.join(System.tmp_dir!(), "lt_ro_#{:erlang.unique_integer([:positive])}")

      File.mkdir!(read_only_dir)
      File.chmod!(read_only_dir, 0o555)
      on_exit(fn -> File.chmod(read_only_dir, 0o755) && File.rm_rf(read_only_dir) end)

      assert {:error, {:write_failed, :eacces}} =
               TestSupport.with_env(:livebook_test, :temp_dir, read_only_dir, fn ->
                 Exporter.to_temp_file_from_string(content)
               end)
    end

    test "returns livebook_unavailable when Livebook is not loaded" do
      content = "# Test\n\n```elixir\n1 + 1\n```"

      assert {:error, {:livebook_unavailable, message}} =
               TestSupport.with_env(
                 :livebook_test,
                 :livebook_preflight_override,
                 :unavailable,
                 fn ->
                   Exporter.to_elixir_from_string(content)
                 end
               )

      assert message =~ "Livebook is not available"
    end

    test "returns export_failed with troubleshooting when converter raises" do
      content = "# Test\n\n```elixir\n1 + 1\n```"

      converter = fn _content -> raise "Livebook parser exploded" end

      assert {:error, {:export_failed, message}} =
               TestSupport.with_env(:livebook_test, :markdown_converter, converter, fn ->
                 Exporter.to_elixir_from_string(content)
               end)

      assert message =~ "Livebook parser exploded"
      assert message =~ "Troubleshooting:"
    end

    test "returns export_failed without troubleshooting for generic errors" do
      content = "# Test\n\n```elixir\n1 + 1\n```"

      converter = fn _content -> raise "unexpected export failure" end

      assert {:error, {:export_failed, message}} =
               TestSupport.with_env(:livebook_test, :markdown_converter, converter, fn ->
                 Exporter.to_elixir_from_string(content)
               end)

      assert message == "unexpected export failure"
      refute message =~ "Troubleshooting:"
    end
  end
end
