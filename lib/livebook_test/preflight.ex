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

  Livebook is a transitive dependency of `livebook_test`. If `:livebook`
  fails to compile in your project, see the troubleshooting section in the README.
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

  @spec check_elixir(String.t()) :: result()
  def check_elixir(version \\ System.version())

  def check_elixir(version) do
    if Version.match?(version, ">= #{@min_elixir_version}") do
      :ok
    else
      {:error,
       """
       Unsupported Elixir version: #{version}.

       livebook_test requires Elixir #{@min_elixir_version} or later.
       This project declares `elixir: "~> 1.18"` in mix.exs.
       """}
    end
  end

  @spec check_otp(non_neg_integer()) :: result()
  def check_otp(otp_release \\ current_otp_release())

  def check_otp(otp_release) do
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

  @doc false
  @spec supports_livebook_version?(term()) :: boolean()
  def supports_livebook_version?(vsn) do
    case vsn do
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

  defp current_otp_release do
    parse_otp_release(:erlang.system_info(:otp_release))
  end

  @doc false
  @spec parse_otp_release(term()) :: non_neg_integer()
  def parse_otp_release(release) do
    case release do
      release when is_binary(release) -> String.to_integer(release)
      release when is_integer(release) -> release
      release -> release |> to_string() |> String.to_integer()
    end
  end

  defp livebook_application_version do
    Application.get_env(:livebook_test, :livebook_version_override) ||
      Application.spec(:livebook, :vsn)
  end

  @spec check_livebook() :: result()
  def check_livebook do
    case Application.get_env(:livebook_test, :livebook_preflight_override) do
      :unavailable ->
        {:error, livebook_unavailable_message()}

      :missing_export ->
        {:error, livebook_incompatible_message(:missing_export)}

      _ ->
        check_livebook_loaded()
    end
  end

  defp check_livebook_loaded do
    cond do
      not Code.ensure_loaded?(Livebook) ->
        {:error, livebook_unavailable_message()}

      not function_exported?(Livebook, @livebook_export_function, 1) ->
        {:error, livebook_incompatible_message(:missing_export)}

      not supports_livebook_version?(livebook_application_version()) ->
        {:error, livebook_incompatible_message(:version)}

      true ->
        :ok
    end
  end

  defp livebook_unavailable_message do
    """
    Livebook is not available.

    livebook_test depends on the `livebook` Hex package (pulled in transitively)
    to export notebooks via `Livebook.live_markdown_to_elixir/1`. Your project
    must compile that dependency before running notebook tests.

    Livebook upstream documents their Hex package primarily as a CLI. Using it
    as a library dependency (as livebook_test does) can fail on some Elixir/OTP
    combinations or in projects with conflicting deps.
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
    livebook_incompatible_message(:version, installed_livebook_version())
  end

  @doc false
  @spec incompatible_version_message(String.t()) :: String.t()
  def incompatible_version_message(installed) do
    livebook_incompatible_message(:version, installed)
  end

  defp livebook_incompatible_message(:version, installed) do
    """
      Incompatible Livebook version: #{installed}.

      livebook_test requires Livebook ~> #{@required_livebook_version}.
    """
  end

  defp installed_livebook_version do
    case Application.spec(:livebook, :vsn) do
      nil -> "unknown"
      vsn -> to_string(vsn)
    end
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
