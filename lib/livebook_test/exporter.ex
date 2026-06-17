defmodule LivebookTest.Exporter do
  @moduledoc """
  Converts Livebook `.livemd` notebooks into executable Elixir scripts.

  This module is the second stage in the LivebookTest pipeline:

      Discovery → **Exporter** → DependencyPatcher → Runner → Report

  It uses `Livebook.live_markdown_to_elixir/1` to transform the
  Markdown-based Livebook format into a standalone `.exs` script
  that can be executed by the Elixir runtime.

  ## How exporting works

  1. Read the `.livemd` file content
  2. Pass it to `Livebook.live_markdown_to_elixir/1`
  3. Receive an Elixir script string
  4. Optionally write the script to a temporary file for execution

  ## Examples

      iex> {:ok, script} = LivebookTest.Exporter.to_elixir("examples/basic.livemd")
      iex> is_binary(script)
      true
  """

  @typedoc "Export result"
  @type export_result :: {:ok, String.t()} | {:error, term()}

  @doc """
  Converts a `.livemd` notebook file to an Elixir script string.

  Reads the file and passes its content through
  `Livebook.live_markdown_to_elixir/1`.

  ## Examples

      iex> {:ok, script} = LivebookTest.Exporter.to_elixir("examples/basic.livemd")
      iex> String.contains?(script, "IO")
      true
  """
  @spec to_elixir(Path.t()) :: export_result()
  def to_elixir(notebook_path) when is_binary(notebook_path) do
    with {:ok, content} <- File.read(notebook_path) do
      to_elixir_from_string(content)
    end
  end

  @doc """
  Converts notebook content (already read) to an Elixir script string.

  Useful when the notebook content has already been read, or when
  working with in-memory notebook strings.

  ## Examples

      iex> content = "# \\\\n\\\\n## Section\\\\n\\\\n```elixir\\\\nIO.puts(:hello)\\\\n```"
      iex> {:ok, _script} = LivebookTest.Exporter.to_elixir_from_string(content)
  """
  @spec to_elixir_from_string(String.t()) :: export_result()
  def to_elixir_from_string(content) when is_binary(content) do
    case LivebookTest.Preflight.check_livebook() do
      :ok ->
        {:ok, Livebook.live_markdown_to_elixir(content)}

      {:error, message} ->
        {:error, {:livebook_unavailable, message}}
    end
  rescue
    e -> {:error, {:export_failed, export_failure_message(e)}}
  end

  defp export_failure_message(exception) do
    base = Exception.message(exception)

    if String.contains?(base, "Livebook") or not Code.ensure_loaded?(Livebook) do
      base <> "\n\n" <> LivebookTest.Preflight.format_error("Notebook export failed.")
    else
      base
    end
  end

  @doc """
  Exports a notebook to a temporary `.exs` file.

  Converts the notebook and writes the resulting script to
  a temporary file, returning the path. The caller is responsible
  for cleaning up the file after use.

  ## Examples

      iex> {:ok, path} = LivebookTest.Exporter.to_temp_file("examples/basic.livemd")
      iex> String.ends_with?(path, ".exs")
      true
  """
  @spec to_temp_file(Path.t()) :: {:ok, Path.t()} | {:error, term()}
  def to_temp_file(notebook_path) when is_binary(notebook_path) do
    with {:ok, script} <- to_elixir(notebook_path) do
      write_temp_script(notebook_path, script)
    end
  end

  @doc """
  Exports notebook content to a temporary `.exs` file.

  Like `to_temp_file/1` but accepts already-read content.

  ## Examples

      iex> content = "# \\\\n\\\\n## Section\\\\n\\\\n```elixir\\\\n1 + 1\\\\n```"
      iex> {:ok, path} = LivebookTest.Exporter.to_temp_file_from_string(content)
      iex> File.exists?(path)
      true
  """
  @spec to_temp_file_from_string(String.t()) :: {:ok, Path.t()} | {:error, term()}
  def to_temp_file_from_string(content) when is_binary(content) do
    with {:ok, script} <- to_elixir_from_string(content) do
      write_temp_script("notebook", script)
    end
  end

  defp write_temp_script(source_name, script) do
    basename = Path.basename(source_name, ".livemd")

    temp_path =
      Path.join(System.tmp_dir!(), "#{basename}_#{:erlang.unique_integer([:positive])}.exs")

    case File.write(temp_path, script) do
      :ok -> {:ok, temp_path}
      {:error, reason} -> {:error, {:write_failed, reason}}
    end
  end
end
