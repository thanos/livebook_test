defmodule LivebookTest.Preflight do
  @moduledoc """
  Runtime checks for Elixir, OTP, and Livebook compatibility.

  Runs before notebook discovery to fail fast with actionable messages
  when the environment cannot support `livebook_test`.

  ## Supported versions

  | Component | Requirement |
  |-----------|-------------|
  | Elixir    | `~> 1.18` (1.18.0 and later) |
  | OTP       | 26, 27, or 28 |
  | Livebook  | `~> 0.19.0` with `live_markdown_to_elixir/1` |

  Livebook is pulled in as a Mix dependency. If your project cannot compile
  Livebook, see the troubleshooting section in the README.
  """

  @min_elixir_version "1.18.0"
  @supported_otp_versions [26, 27, 28]
  @required_livebook_version "0.19.0"
  @livebook_export_function :live_markdown_to_elixir

  @typedoc "Preflight check result"
  @type result :: :ok | {:error, String.t()}

  @doc """
  Runs all preflight checks.

  Returns `:ok` when the environment is supported, or `{:error, message}`
  with a human-readable explanation.

  ## Examples

      iex> LivebookTest.Preflight.check() == :ok
      true
  """
  @spec check() :: result()
  def check do
    with :ok <- check_elixir(),
         :ok <- check_otp() do
      check_livebook()
    end
  end

  @doc """
  Runs preflight checks and raises on failure.

  Suitable for Mix tasks where a raised error is the desired outcome.
  """
  @spec check!() :: :ok
  def check! do
    case check() do
      :ok ->
        :ok

      {:error, message} ->
        raise __MODULE__.Error, message
    end
  end

  @doc """
  Returns the formatted preflight error message for display.
  """
  @spec format_error(String.t()) :: String.t()
  def format_error(message) do
    """
    #{message}

    #{troubleshooting_hint()}
    """
    |> String.trim()
  end

  @spec check_elixir() :: result()
  def check_elixir do
    current = System.version()

    if Version.match?(current, ">= #{@min_elixir_version}") do
      :ok
    else
      {:error,
       """
       Unsupported Elixir version: #{current}.

       livebook_test requires Elixir #{@min_elixir_version} or later.
       This project declares `elixir: "~> 1.18"` in mix.exs.
       """}
    end
  end

  @spec check_otp() :: result()
  def check_otp do
    otp_release =
      case :erlang.system_info(:otp_release) do
        release when is_binary(release) -> String.to_integer(release)
        release when is_integer(release) -> release
        release -> release |> to_string() |> String.to_integer()
      end

    if otp_release in @supported_otp_versions do
      :ok
    else
      {:error,
       """
       Unsupported OTP version: #{otp_release}.

       livebook_test is tested on OTP #{Enum.join(@supported_otp_versions, ", ")}.
       Livebook as a Mix dependency is especially fragile on untested OTP releases.
       """}
    end
  end

  @spec check_livebook() :: result()
  def check_livebook do
    cond do
      not Code.ensure_loaded?(Livebook) ->
        {:error, livebook_unavailable_message()}

      not function_exported?(Livebook, @livebook_export_function, 1) ->
        {:error, livebook_incompatible_message(:missing_export)}

      not livebook_version_supported?() ->
        {:error, livebook_incompatible_message(:version)}

      true ->
        :ok
    end
  end

  defp livebook_version_supported? do
    case Application.spec(:livebook, :vsn) do
      nil ->
        false

      vsn ->
        vsn
        |> to_string()
        |> Version.parse!()
        |> Version.match?("~> #{@required_livebook_version}")
    end
  rescue
    _ -> false
  end

  defp livebook_unavailable_message do
    """
    Livebook is not available.

    livebook_test depends on the `livebook` Hex package to export notebooks
    via `Livebook.live_markdown_to_elixir/1`. Your project must compile
    Livebook successfully before running notebook tests.

    If Livebook fails to compile in your project, this is a known limitation:
    Livebook is officially distributed as a CLI tool and is not fully supported
    as a Mix dependency across all Elixir/OTP combinations.
    """
  end

  defp livebook_incompatible_message(:missing_export) do
    """
    Livebook is installed but does not export `live_markdown_to_elixir/1`.

    The installed Livebook version is incompatible with livebook_test.
    Ensure your mix.exs pins Livebook to `~> #{@required_livebook_version}`.
    """
  end

  defp livebook_incompatible_message(:version) do
    installed =
      case Application.spec(:livebook, :vsn) do
        nil -> "unknown"
        vsn -> to_string(vsn)
      end

    """
      Incompatible Livebook version: #{installed}.

      livebook_test requires Livebook ~> #{@required_livebook_version}.
    """
  end

  defp troubleshooting_hint do
    """
    Troubleshooting:
      • Verify Elixir #{@min_elixir_version}+ and OTP #{Enum.join(@supported_otp_versions, "/")} are installed
      • Run `mix deps.get && mix compile` and check for Livebook compile errors
      • Pin `{:livebook, "~> 0.19.0", runtime: false}` if another dep pulls a conflicting version
      • See docs/guides/kino_limitations.md for notebook export caveats
    """
  end

  defmodule Error do
    @moduledoc false
    defexception [:message]

    @impl true
    def exception(message) do
      %__MODULE__{message: LivebookTest.Preflight.format_error(message)}
    end
  end
end
