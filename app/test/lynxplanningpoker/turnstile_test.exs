defmodule Lynxplanningpoker.TurnstileTest do
  use ExUnit.Case, async: false

  alias Lynxplanningpoker.Turnstile

  setup do
    original = Application.get_env(:lynxplanningpoker, :turnstile)
    on_exit(fn -> Application.put_env(:lynxplanningpoker, :turnstile, original) end)
    :ok
  end

  describe "verify/2 when disabled" do
    test "returns :ok regardless of token" do
      Application.put_env(:lynxplanningpoker, :turnstile,
        enabled: false,
        site_key: nil,
        secret_key: nil
      )

      assert :ok = Turnstile.verify(nil)
      assert :ok = Turnstile.verify("")
      assert :ok = Turnstile.verify("any-token")
    end
  end

  describe "verify/2 when enabled" do
    test "returns {:error, :missing_token} when token is nil or blank" do
      Application.put_env(:lynxplanningpoker, :turnstile,
        enabled: true,
        site_key: "site",
        secret_key: "secret"
      )

      assert {:error, :missing_token} = Turnstile.verify(nil)
      assert {:error, :missing_token} = Turnstile.verify("")
    end

    test "returns {:error, :missing_secret} when secret is not configured" do
      Application.put_env(:lynxplanningpoker, :turnstile,
        enabled: true,
        site_key: "site",
        secret_key: nil
      )

      assert {:error, :missing_secret} = Turnstile.verify("some-token")
    end
  end

  describe "site_key/0 and enabled?/0" do
    test "reflect current config" do
      Application.put_env(:lynxplanningpoker, :turnstile,
        enabled: true,
        site_key: "abc123",
        secret_key: "shh"
      )

      assert Turnstile.site_key() == "abc123"
      assert Turnstile.enabled?() == true

      Application.put_env(:lynxplanningpoker, :turnstile, enabled: false, site_key: nil)

      assert Turnstile.site_key() == nil
      assert Turnstile.enabled?() == false
    end
  end
end
