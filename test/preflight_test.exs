defmodule LivebookTest.PreflightTest do
  use ExUnit.Case, async: true

  alias LivebookTest.Preflight

  describe "check/0" do
    test "returns :ok in supported environment" do
      assert Preflight.check() == :ok
    end

    test "check! does not raise in supported environment" do
      assert Preflight.check!() == :ok
    end
  end

  describe "check_elixir/0" do
    test "accepts current Elixir version" do
      assert Preflight.check_elixir() == :ok
    end
  end

  describe "check_otp/0" do
    test "accepts current OTP version" do
      assert Preflight.check_otp() == :ok
    end
  end

  describe "check_livebook/0" do
    test "accepts installed Livebook" do
      assert Preflight.check_livebook() == :ok
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
