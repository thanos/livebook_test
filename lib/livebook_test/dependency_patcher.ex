defmodule LivebookTest.DependencyPatcher do
  @moduledoc """
  Rewrites Mix.install dependency declarations for local testing.

  This is the core feature of LivebookTest and the third stage
  in the pipeline:

      Discovery → Exporter → **DependencyPatcher** → Runner → Report

  ## Why dependency patching matters

  Livebook notebooks are standalone documents. They declare their
  dependencies using `Mix.install/2` with Hex version specifiers:

      Mix.install([
        {:my_lib, "~> 0.5"}
      ])

  When testing notebooks as part of a project's CI pipeline, you want
  those notebooks to use the **current checkout** of `my_lib`, not the
  published Hex version. This module rewrites the dependency declarations
  to use local paths instead.

  ## Modes

  - **Remote** (`:remote`) - leave the script untouched
  - **Local** (`:local`) - rewrite Hex deps and existing `path:` deps to
    stable absolute paths from `local_deps`

  ## How patching works

  The patcher operates on the **exported Elixir script** (not the `.livemd`),
  using regex-based replacement to rewrite `Mix.install` calls:

      # Hex dep - before (remote)
      Mix.install([{:my_lib, "~> 0.5"}])

      # Hex dep - after (local)
      Mix.install([{:my_lib, path: "/abs/path/to/project"}])

      # Path dep - before
      Mix.install([{:my_lib, path: Path.join(__DIR__, "..")}])

      # Path dep - after (local, when my_lib is in local_deps)
      Mix.install([{:my_lib, path: "/abs/path/to/project"}])
  """

  @typedoc "Patch mode matching LivebookTest.Config.dependency_mode()"
  @type patch_mode :: :remote | :local

  @typedoc "Local dependency mapping"
  @type local_deps :: LivebookTest.Config.local_deps()

  @doc """
  Patches an Elixir script according to the given dependency mode.

  In `:remote` mode, the script is returned unchanged.
  In `:local` mode, dependency declarations within `Mix.install`
  are rewritten to use local paths.

  ## Examples

      iex> script = ~S|Mix.install([{:ex_arrow, "~> 0.5"}])|
      iex> LivebookTest.DependencyPatcher.patch(script, :remote, [])
      ~S|Mix.install([{:ex_arrow, "~> 0.5"}])|

      iex> script = ~S|Mix.install([{:ex_arrow, "~> 0.5"}])|
      iex> patched = LivebookTest.DependencyPatcher.patch(script, :local, ex_arrow: ".")
      iex> String.contains?(patched, "path:")
      true
  """
  @spec patch(String.t(), patch_mode(), local_deps()) :: String.t()
  def patch(script, :remote, _local_deps), do: script

  def patch(script, :local, local_deps) when is_binary(script) and is_list(local_deps) do
    patch_local(script, local_deps)
  end

  def patch(script, :local, local_deps) when is_binary(script) and is_map(local_deps) do
    patch_local(script, Enum.to_list(local_deps))
  end

  defp patch_local(script, local_deps) do
    Enum.reduce(local_deps, script, fn {dep_name, dep_path}, acc ->
      patch_single_dep(acc, dep_name, dep_path)
    end)
  end

  defp patch_single_dep(script, dep_name, dep_path) do
    dep_str = Atom.to_string(dep_name)
    abs_path = Path.expand(dep_path)
    replacement = "{:#{dep_str}, path: #{inspect(abs_path)}}"

    script
    |> patch_dep_with_opts(dep_str, replacement)
    |> patch_simple_dep(dep_str, replacement)
    |> patch_quoted_path_dep(dep_str, replacement)
    |> patch_path_join_dep(dep_str, replacement)
  end

  defp patch_dep_with_opts(script, dep_name, replacement) do
    pattern = Regex.compile!("\\{:#{Regex.escape(dep_name)},\\s*\"[^\"]+\",\\s*[^}]+\\}")

    Regex.replace(pattern, script, replacement)
  end

  defp patch_simple_dep(script, dep_name, replacement) do
    pattern = Regex.compile!("\\{:#{Regex.escape(dep_name)},\\s*\"[^\"]+\"\\}")

    Regex.replace(pattern, script, replacement)
  end

  defp patch_quoted_path_dep(script, dep_name, replacement) do
    pattern =
      Regex.compile!("\\{:#{Regex.escape(dep_name)},\\s*path:\\s*\"[^\"]*\"\\}")

    Regex.replace(pattern, script, replacement)
  end

  defp patch_path_join_dep(script, dep_name, replacement) do
    pattern =
      Regex.compile!(
        "\\{:#{Regex.escape(dep_name)},\\s*path:\\s*Path\\.join\\(__DIR__,\\s*\"[^\"]*\"\\)\\}"
      )

    Regex.replace(pattern, script, replacement)
  end
end
