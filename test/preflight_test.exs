defmodule LivebookTest.PreflightTest do
  use ExUnit.Case, async: true

  alias LivebookTest.Preflight
  alias LivebookTest.TestSupport

  describe "check/0" do
    test "returns :ok in supported environment" do
      assert Preflight.check() == :ok
    end

    test "check! does not raise in supported environment" do
      assert Preflight.check!() == :ok
    end

    test "check! raises when Livebook is unavailable" do
      assert_raise Preflight.Error, ~r/Livebook is not available/, fn ->
        TestSupport.with_env(:livebook_test, :livebook_preflight_override, :unavailable, fn ->
          Preflight.check!()
        end)
      end
    end

    test "returns error when elixir check fails" do
      assert {:error, message} = Preflight.check_elixir("1.17.0")
      assert message =~ "Unsupported Elixir version"
    end

    test "returns error when otp check fails" do
      assert {:error, message} = Preflight.check_otp(25)
      assert message =~ "Unsupported OTP version"
    end
  end

  describe "check_elixir/1" do
    test "accepts current Elixir version" do
      assert Preflight.check_elixir() == :ok
    end

    test "accepts minimum supported version" do
      assert Preflight.check_elixir("1.18.0") == :ok
    end
  end

  describe "check_otp/1" do
    test "accepts current OTP version" do
      assert Preflight.check_otp() == :ok
    end

    test "accepts supported otp release values" do
      assert Preflight.check_otp(27) == :ok
    end
  end

  describe "parse_otp_release/1" do
    test "parses binary otp releases" do
      assert Preflight.parse_otp_release("27") == 27
    end

    test "parses integer otp releases" do
      assert Preflight.parse_otp_release(28) == 28
    end

    test "parses atom and charlist otp releases" do
      assert Preflight.parse_otp_release(~c"28") == 28
    end
  end

  describe "incompatible_version_message/1" do
    test "formats unknown installed version" do
      message = Preflight.incompatible_version_message("unknown")

      assert message =~ "Incompatible Livebook version: unknown"
      assert message =~ "~> 0.19.0"
    end
  end

  describe "supports_livebook_version?/1" do
    test "accepts supported livebook versions" do
      assert Preflight.supports_livebook_version?("0.19.8")
    end

    test "rejects unsupported versions" do
      refute Preflight.supports_livebook_version?("0.18.0")
    end

    test "rejects nil version" do
      refute Preflight.supports_livebook_version?(nil)
    end

    test "rejects invalid version strings" do
      refute Preflight.supports_livebook_version?("not-a-version")
    end
  end

  describe "check_livebook/0" do
    test "accepts installed Livebook" do
      assert Preflight.check_livebook() == :ok
    end

    test "returns error when Livebook is unavailable" do
      assert {:error, message} =
               TestSupport.with_env(
                 :livebook_test,
                 :livebook_preflight_override,
                 :unavailable,
                 fn ->
                   Preflight.check_livebook()
                 end
               )

      assert message =~ "Livebook is not available"
    end

    test "returns error when export function is missing" do
      assert {:error, message} =
               TestSupport.with_env(
                 :livebook_test,
                 :livebook_preflight_override,
                 :missing_export,
                 fn -> Preflight.check_livebook() end
               )

      assert message =~ "live_markdown_to_elixir"
    end

    test "returns error for incompatible livebook version override" do
      assert {:error, message} =
               TestSupport.with_env(:livebook_test, :livebook_version_override, "0.18.0", fn ->
                 Preflight.check_livebook()
               end)

      assert message =~ "Incompatible Livebook version"
    end
  end

  describe "format_error/1" do
    test "includes troubleshooting hints" do
      message = Preflight.format_error("Something went wrong")

      assert message =~ "Something went wrong"
      assert message =~ "Troubleshooting:"
      assert message =~ "mix deps.get"
    end
  end

  describe "Error exception" do
    test "wraps message with troubleshooting hints" do
      exception = Preflight.Error.exception("Preflight failed")

      assert exception.message =~ "Preflight failed"
      assert exception.message =~ "Troubleshooting:"
    end
  end
end
