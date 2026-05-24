defmodule LynxplanningpokerWeb.Plugs.CanonicalHostTest do
  # async: false — these tests mutate the :canonical_host application env.
  use LynxplanningpokerWeb.ConnCase, async: false

  alias LynxplanningpokerWeb.Plugs.CanonicalHost

  # Sets :canonical_host for the duration of a test and restores the previous
  # value (unset, in practice) afterwards.
  defp set_canonical(host) do
    original = Application.get_env(:lynxplanningpoker, :canonical_host)
    Application.put_env(:lynxplanningpoker, :canonical_host, host)

    on_exit(fn ->
      if original do
        Application.put_env(:lynxplanningpoker, :canonical_host, original)
      else
        Application.delete_env(:lynxplanningpoker, :canonical_host)
      end
    end)
  end

  defp conn_with_host(host, path \\ "/", query \\ "") do
    %{Phoenix.ConnTest.build_conn() | host: host, request_path: path, query_string: query}
  end

  describe "when :canonical_host is not configured" do
    test "passes the request through untouched" do
      conn = CanonicalHost.call(conn_with_host("lynxplanningpoker.fly.dev"), [])

      refute conn.halted
      assert conn.status == nil
    end
  end

  describe "when :canonical_host is configured" do
    setup do
      set_canonical("lynxplanningpoker.com")
      :ok
    end

    test "passes through when the host already matches the canonical host" do
      conn = CanonicalHost.call(conn_with_host("lynxplanningpoker.com"), [])

      refute conn.halted
      assert conn.status == nil
    end

    test "host match is case-insensitive" do
      conn = CanonicalHost.call(conn_with_host("LynxPlanningPoker.Com"), [])

      refute conn.halted
      assert conn.status == nil
    end

    test "301-redirects a non-canonical host to the canonical one" do
      conn = CanonicalHost.call(conn_with_host("lynxplanningpoker.fly.dev"), [])

      assert conn.halted
      assert conn.status == 301
      assert get_resp_header(conn, "location") == ["https://lynxplanningpoker.com/"]
    end

    test "preserves the request path and query string in the redirect" do
      conn =
        CanonicalHost.call(
          conn_with_host("lynxplanningpoker.fly.dev", "/rooms/new", "locale=en"),
          []
        )

      assert conn.status == 301

      assert get_resp_header(conn, "location") == [
               "https://lynxplanningpoker.com/rooms/new?locale=en"
             ]
    end
  end
end
