defmodule LynxplanningpokerWeb.Plugs.RateLimitTest do
  use LynxplanningpokerWeb.ConnCase, async: false

  alias LynxplanningpokerWeb.Plugs.RateLimit

  # Helper to build a conn with a deterministic IP. Using a unique IP per test
  # guarantees independent buckets in the shared Hammer ETS table even when
  # other tests are running.
  defp build_conn_with_ip(ip) do
    %{Phoenix.ConnTest.build_conn() | remote_ip: ip}
    |> Plug.Test.init_test_session(%{})
  end

  defp uniq_ip do
    <<a, b, c, d>> = :crypto.strong_rand_bytes(4)
    {a, b, c, d}
  end

  describe "RateLimit plug" do
    test "allows requests under the limit" do
      ip = uniq_ip()
      opts = RateLimit.init(bucket: "test:#{System.unique_integer([:positive])}", limit: 3)

      for _ <- 1..3 do
        conn = RateLimit.call(build_conn_with_ip(ip), opts)
        refute conn.halted
        assert conn.status in [nil, 200]
      end
    end

    test "returns HTTP 429 with retry-after header and translated body when limit exceeded" do
      ip = uniq_ip()
      opts = RateLimit.init(bucket: "test:#{System.unique_integer([:positive])}", limit: 2)

      _ = RateLimit.call(build_conn_with_ip(ip), opts)
      _ = RateLimit.call(build_conn_with_ip(ip), opts)

      conn = RateLimit.call(build_conn_with_ip(ip), opts)

      assert conn.halted
      assert conn.status == 429

      assert [retry_after] = Plug.Conn.get_resp_header(conn, "retry-after")
      assert {n, ""} = Integer.parse(retry_after)
      assert n >= 1

      body = conn.resp_body
      assert body =~ "Too many requests"
      assert body =~ "Back to home"
    end

    test "uses different buckets per IP" do
      bucket = "test:#{System.unique_integer([:positive])}"
      opts = RateLimit.init(bucket: bucket, limit: 1)

      ip1 = uniq_ip()
      ip2 = uniq_ip()

      _ = RateLimit.call(build_conn_with_ip(ip1), opts)
      blocked = RateLimit.call(build_conn_with_ip(ip1), opts)
      assert blocked.status == 429

      allowed = RateLimit.call(build_conn_with_ip(ip2), opts)
      refute allowed.halted
    end

    test "honors x-forwarded-for header" do
      bucket = "test:#{System.unique_integer([:positive])}"
      opts = RateLimit.init(bucket: bucket, limit: 1)

      # Two different remote_ips but same X-Forwarded-For should share a bucket
      forwarded = "203.0.113.#{:rand.uniform(254)}"

      conn1 =
        build_conn_with_ip(uniq_ip())
        |> Plug.Conn.put_req_header("x-forwarded-for", forwarded)

      conn2 =
        build_conn_with_ip(uniq_ip())
        |> Plug.Conn.put_req_header("x-forwarded-for", forwarded)

      _ = RateLimit.call(conn1, opts)
      blocked = RateLimit.call(conn2, opts)
      assert blocked.status == 429
    end
  end
end
