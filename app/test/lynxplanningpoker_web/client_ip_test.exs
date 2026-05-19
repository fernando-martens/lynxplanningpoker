defmodule LynxplanningpokerWeb.ClientIPTest do
  use ExUnit.Case, async: false

  alias LynxplanningpokerWeb.ClientIP

  defp conn_with(remote_ip, headers \\ []) do
    conn = %{Phoenix.ConnTest.build_conn() | remote_ip: remote_ip}

    Enum.reduce(headers, conn, fn {k, v}, c -> Plug.Conn.put_req_header(c, k, v) end)
  end

  defp with_proxies(proxies, fun) do
    original = Application.get_env(:lynxplanningpoker, :trusted_proxies, [])
    Application.put_env(:lynxplanningpoker, :trusted_proxies, proxies)

    try do
      fun.()
    after
      Application.put_env(:lynxplanningpoker, :trusted_proxies, original)
    end
  end

  describe "from_conn/1 without trusted proxies" do
    test "returns the TCP peer and ignores X-Forwarded-For" do
      with_proxies([], fn ->
        conn = conn_with({203, 0, 113, 5}, [{"x-forwarded-for", "1.2.3.4"}])
        assert ClientIP.from_conn(conn) == "203.0.113.5"
      end)
    end

    test "returns the TCP peer when no header is present" do
      with_proxies([], fn ->
        conn = conn_with({203, 0, 113, 5})
        assert ClientIP.from_conn(conn) == "203.0.113.5"
      end)
    end
  end

  describe "from_conn/1 with trusted proxies" do
    test "honors X-Forwarded-For when peer is a trusted proxy" do
      with_proxies(["10.0.0.0/8"], fn ->
        conn = conn_with({10, 1, 2, 3}, [{"x-forwarded-for", "203.0.113.5"}])
        assert ClientIP.from_conn(conn) == "203.0.113.5"
      end)
    end

    test "ignores X-Forwarded-For when peer is NOT a trusted proxy" do
      with_proxies(["10.0.0.0/8"], fn ->
        conn = conn_with({8, 8, 8, 8}, [{"x-forwarded-for", "203.0.113.5"}])
        assert ClientIP.from_conn(conn) == "8.8.8.8"
      end)
    end

    test "walks chained proxies right-to-left, returning first untrusted hop" do
      with_proxies(["10.0.0.0/8", "172.16.0.0/12"], fn ->
        # Client -> 172.16.0.5 (proxy) -> 10.0.0.1 (proxy/peer)
        conn =
          conn_with({10, 0, 0, 1}, [{"x-forwarded-for", "203.0.113.5, 172.16.0.5"}])

        assert ClientIP.from_conn(conn) == "203.0.113.5"
      end)
    end

    test "falls back to TCP peer when XFF contains only trusted IPs" do
      with_proxies(["10.0.0.0/8"], fn ->
        conn = conn_with({10, 0, 0, 1}, [{"x-forwarded-for", "10.0.0.2, 10.0.0.3"}])
        assert ClientIP.from_conn(conn) == "10.0.0.1"
      end)
    end

    test "ignores malformed entries in the header" do
      with_proxies(["10.0.0.0/8"], fn ->
        conn =
          conn_with({10, 0, 0, 1}, [{"x-forwarded-for", "not-an-ip, 203.0.113.5"}])

        assert ClientIP.from_conn(conn) == "203.0.113.5"
      end)
    end

    test "supports a single host (no /prefix) in the trusted list" do
      with_proxies(["10.0.0.1"], fn ->
        conn = conn_with({10, 0, 0, 1}, [{"x-forwarded-for", "203.0.113.5"}])
        assert ClientIP.from_conn(conn) == "203.0.113.5"

        conn = conn_with({10, 0, 0, 2}, [{"x-forwarded-for", "203.0.113.5"}])
        assert ClientIP.from_conn(conn) == "10.0.0.2"
      end)
    end

    test "skips invalid CIDR entries" do
      with_proxies(["not-a-cidr", "10.0.0.0/8"], fn ->
        conn = conn_with({10, 0, 0, 1}, [{"x-forwarded-for", "203.0.113.5"}])
        assert ClientIP.from_conn(conn) == "203.0.113.5"
      end)
    end
  end
end
