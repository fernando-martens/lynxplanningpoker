defmodule LynxplanningpokerWeb.PageControllerTest do
  use LynxplanningpokerWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Lynx planning poker"
  end

  test "GET /how-it-works renders the three steps", %{conn: conn} do
    conn = get(conn, ~p"/how-it-works")
    response = html_response(conn, 200)
    assert response =~ "How it works"
    assert response =~ "Create a room"
    assert response =~ "Invite your team"
    assert response =~ "Vote and reveal"
  end

  test "GET /pricing renders both plans and emphasises the free one", %{conn: conn} do
    conn = get(conn, ~p"/pricing")
    response = html_response(conn, 200)
    assert response =~ "Plans and pricing"
    assert response =~ "Free forever"
    assert response =~ "Available today"
    assert response =~ "Premium"
    assert response =~ "On the roadmap"
    assert response =~ "Not available yet"
  end

  describe "security headers" do
    test "GET / emits a content-security-policy header with the expected directives",
         %{conn: conn} do
      conn = get(conn, ~p"/")
      [csp] = Plug.Conn.get_resp_header(conn, "content-security-policy")

      assert csp =~ "default-src 'self'"
      assert csp =~ "https://challenges.cloudflare.com"
      assert csp =~ "frame-ancestors 'none'"
      assert csp =~ "connect-src 'self' ws: wss:"
      assert csp =~ "https://fonts.googleapis.com"
      assert csp =~ "https://fonts.gstatic.com"

      # Nonce is present and `'unsafe-inline'` is gone from script-src.
      assert csp =~ ~r/script-src [^;]*'nonce-[A-Za-z0-9_-]+'/
      refute csp =~ ~r/script-src [^;]*'unsafe-inline'/
    end

    test "the inline theme-bootstrap script carries the same nonce that's in the CSP",
         %{conn: conn} do
      conn = get(conn, ~p"/")
      [csp] = Plug.Conn.get_resp_header(conn, "content-security-policy")
      [_, nonce] = Regex.run(~r/'nonce-([A-Za-z0-9_-]+)'/, csp)

      assert html_response(conn, 200) =~ ~s(<script nonce="#{nonce}">)
    end

    test "each request gets a fresh nonce", %{conn: conn} do
      [csp1] =
        conn
        |> get(~p"/")
        |> Plug.Conn.get_resp_header("content-security-policy")

      [csp2] =
        Phoenix.ConnTest.build_conn()
        |> get(~p"/")
        |> Plug.Conn.get_resp_header("content-security-policy")

      [_, nonce1] = Regex.run(~r/'nonce-([A-Za-z0-9_-]+)'/, csp1)
      [_, nonce2] = Regex.run(~r/'nonce-([A-Za-z0-9_-]+)'/, csp2)
      assert nonce1 != nonce2
    end
  end
end
