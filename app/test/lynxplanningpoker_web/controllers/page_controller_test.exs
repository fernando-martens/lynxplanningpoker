defmodule LynxplanningpokerWeb.PageControllerTest do
  use LynxplanningpokerWeb.ConnCase

  alias Lynxplanningpoker.Analytics

  test "GET / records an anonymous unique daily visitor", %{conn: conn} do
    assert Analytics.total_visitors() == 0
    get(conn, ~p"/")
    assert Analytics.total_visitors() == 1
  end

  test "the same visitor visiting many times today still counts as one",
       %{conn: conn} do
    get(conn, ~p"/")
    get(conn, ~p"/")
    get(conn, ~p"/")

    assert Analytics.total_visitors() == 1
  end

  test "GET / renders the hero, the explainer, benefits and data-protection sections",
       %{conn: conn} do
    response = conn |> get(~p"/") |> html_response(200)

    assert response =~ "Lynx planning poker"
    assert response =~ "Free, fast, and no sign-up needed."
    assert response =~ "What is planning poker?"
    assert response =~ "Why teams choose Lynx Planning Poker"
    assert response =~ "Your data stays yours"
    assert response =~ "Create a room"

    # Privacy-first trust strip in the hero, above the fold.
    # The data-protection badge is locale-aware: GDPR for the default (en)
    # locale, LGPD only for pt_BR.
    assert response =~ "Zero trackers"
    assert response =~ "Rooms auto-delete"
    assert response =~ "GDPR"
    refute response =~ "LGPD"

    # "Buy me a coffee" link in the header points to the BMC page.
    assert response =~ ~s(href="https://buymeacoffee.com/lynxplanningpoker")
  end

  test "GET /how-it-works renders the three steps, FAQ and CTA", %{conn: conn} do
    conn = get(conn, ~p"/how-it-works")
    response = html_response(conn, 200)
    assert response =~ "How it works"
    assert response =~ "Create a room"
    assert response =~ "Invite your team"
    assert response =~ "Vote and reveal"
    assert response =~ "Frequently asked questions"
    assert response =~ "Is it really free?"
    assert response =~ "Ready to start?"
    assert response =~ ~s(href="/rooms/new")
    assert response =~ ~s(href="/privacy")
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

  test "GET /privacy renders the GDPR/LGPD page with the expected sections", %{conn: conn} do
    conn = get(conn, ~p"/privacy")
    response = html_response(conn, 200)
    assert response =~ "Privacy and data handling"
    assert response =~ "What data we collect"
    assert response =~ "Your rights"
    assert response =~ "GDPR"
    assert response =~ "LGPD"
    # First-party, cookie-free page-view counting is disclosed.
    assert response =~ "Usage analytics"
  end

  test "GET /security renders the infrastructure-security page", %{conn: conn} do
    conn = get(conn, ~p"/security")
    response = html_response(conn, 200)
    assert response =~ "Security"
    assert response =~ "Encrypted connections"
    assert response =~ "Content Security Policy"
    assert response =~ "Hardened sessions"
    assert response =~ "Unguessable room links"
    assert response =~ "Abuse protection"
    assert response =~ "Responsible disclosure"
  end

  test "the home page links to /privacy", %{conn: conn} do
    conn = get(conn, ~p"/")
    response = html_response(conn, 200)
    assert response =~ ~s(href="/privacy")
    assert response =~ "How we handle your data"
  end

  test "the shared footer links to privacy, security and contact", %{conn: conn} do
    for path <- [~p"/", ~p"/how-it-works", ~p"/pricing", ~p"/privacy", ~p"/security"] do
      response = conn |> get(path) |> html_response(200)
      assert response =~ ~s(href="/privacy")
      assert response =~ ~s(href="/security")
      assert response =~ ~s(href="mailto:contact@lynxplanningpoker.com")
    end
  end

  test "the home page declares the favicons and web manifest", %{conn: conn} do
    conn = get(conn, ~p"/")
    response = html_response(conn, 200)
    assert response =~ ~s(<link rel="icon" href="/favicon.ico")
    assert response =~ ~s(href="/favicon-32x32.png")
    assert response =~ ~s(href="/favicon-16x16.png")
    assert response =~ ~s(<link rel="apple-touch-icon")
    assert response =~ ~s(<link rel="manifest" href="/site.webmanifest")
  end

  describe "SEO metadata" do
    test "GET / emits a title, description, canonical and social tags", %{conn: conn} do
      response = conn |> get(~p"/") |> html_response(200)

      assert response =~ "Planning Poker"
      assert response =~ ~s(<meta name="description" content=")
      assert response =~ ~s(<link rel="canonical" href="http://localhost:4000/")
      assert response =~ ~s(<meta property="og:title")
      assert response =~ ~s(<meta property="og:description")
      assert response =~ ~s(<meta property="og:image" content=")
      assert response =~ "/images/og-image.png"
      assert response =~ ~s(<meta name="twitter:card" content="summary_large_image")
    end

    test "GET / is indexable and emits hreflang alternates for every locale",
         %{conn: conn} do
      response = conn |> get(~p"/") |> html_response(200)

      assert response =~ ~s(<meta name="robots" content="index)
      assert response =~ ~s(hreflang="pt-BR")
      assert response =~ ~s(hreflang="en")
      assert response =~ ~s(hreflang="fr")
      assert response =~ ~s(hreflang="es")
      assert response =~ ~s(hreflang="x-default")
    end

    test "GET / embeds WebApplication JSON-LD", %{conn: conn} do
      response = conn |> get(~p"/") |> html_response(200)

      assert response =~ ~s(<script type="application/ld+json")
      assert response =~ ~s("@type":"WebApplication")
    end

    test "GET /how-it-works embeds FAQPage JSON-LD", %{conn: conn} do
      response = conn |> get(~p"/how-it-works") |> html_response(200)

      assert response =~ ~s("@type":"FAQPage")
      assert response =~ ~s("@type":"Question")
    end
  end

  describe "locale-prefixed URLs" do
    test "GET /fr serves the home page in French with a matching canonical",
         %{conn: conn} do
      response = conn |> get(~p"/fr") |> html_response(200)

      assert response =~ ~s(<html lang="fr">)
      assert response =~ ~s(<link rel="canonical" href="http://localhost:4000/fr">)
    end

    test "GET /fr/how-it-works serves a localized page and self-referencing hreflang",
         %{conn: conn} do
      response = conn |> get(~p"/fr/how-it-works") |> html_response(200)

      assert response =~ ~s(<html lang="fr">)
      assert response =~ ~s(hreflang="fr" href="http://localhost:4000/fr/how-it-works")
    end

    test "GET /pt-br/pricing serves Brazilian Portuguese under the hyphenated segment",
         %{conn: conn} do
      response = conn |> get(~p"/pt-br/pricing") |> html_response(200)

      assert response =~ ~s(<html lang="pt-BR">)
      assert response =~ ~s(<link rel="canonical" href="http://localhost:4000/pt-br/pricing">)
    end

    test "GET /pt-br shows the data-protection badge as LGPD, not GDPR",
         %{conn: conn} do
      response = conn |> get(~p"/pt-br") |> html_response(200)

      assert response =~ ~s(<html lang="pt-BR">)
      assert response =~ "LGPD"
      refute response =~ "GDPR"
    end

    test "GET /fr links the Create-a-room CTA to the French room-creation page",
         %{conn: conn} do
      response = conn |> get(~p"/fr") |> html_response(200)

      assert response =~ ~s(href="/fr/rooms/new")
    end

    test "prefix-free public pages render the default locale, ignoring a stale session",
         %{conn: conn} do
      # A visitor whose session still says French navigates to the prefix-free
      # /pricing URL — it must render the default locale, not French. This is
      # what makes switching back to the default locale take effect.
      response =
        conn
        |> Plug.Test.init_test_session(%{locale: "fr"})
        |> get(~p"/pricing")
        |> html_response(200)

      assert response =~ ~s(<html lang="en">)
      refute response =~ ~s(<html lang="fr">)
    end
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

      # Fonts are self-hosted — no third-party Google Fonts origins.
      assert csp =~ "font-src 'self'"
      refute csp =~ "https://fonts.googleapis.com"
      refute csp =~ "https://fonts.gstatic.com"

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
