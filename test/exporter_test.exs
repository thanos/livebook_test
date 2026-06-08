defmodule LivebookTest.ExporterTest do
  use ExUnit.Case, async: true

  alias LivebookTest.Exporter

  describe "to_elixir/1" do
    test "exports a valid notebook to Elixir script" do
      {:ok, script} = Exporter.to_elixir("examples/basic.livemd")
      assert is_binary(script)
    end

    test "returns error for non-existent file" do
      assert {:error, _} = Exporter.to_elixir("/nonexistent/notebook.livemd")
    end
  end

  describe "to_elixir_from_string/1" do
    test "converts notebook content to script" do
      content = "# Test\n\n## Section\n\n```elixir\nIO.puts(:hello)\n```"
      assert {:ok, script} = Exporter.to_elixir_from_string(content)
      assert is_binary(script)
    end

    test "handles empty content" do
      assert {:ok, _script} = Exporter.to_elixir_from_string("# Empty\n")
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
  end
end
