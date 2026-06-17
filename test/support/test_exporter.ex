defmodule LivebookTest.TestExporter do
  @moduledoc false

  def to_temp_file(notebook_path) do
    case Path.basename(notebook_path) do
      "fail_export.livemd" ->
        {:error, {:export_failed, "boom"}}

      "fail_read.livemd" ->
        {:ok, Path.join(System.tmp_dir!(), "missing_#{:erlang.unique_integer([:positive])}.exs")}

      "fail_write.livemd" ->
        path = Path.join(System.tmp_dir!(), "readonly_#{:erlang.unique_integer([:positive])}.exs")
        File.write!(path, "Mix.install([])\n")
        File.chmod!(path, 0o444)
        {:ok, path}

      _ ->
        LivebookTest.Exporter.to_temp_file(notebook_path)
    end
  end
end
