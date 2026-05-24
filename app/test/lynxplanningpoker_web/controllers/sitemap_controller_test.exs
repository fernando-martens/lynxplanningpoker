defmodule LynxplanningpokerWeb.SitemapControllerTest do
  use LynxplanningpokerWeb.ConnCase

  test "GET /sitemap.xml returns an XML sitemap", %{conn: conn} do
    conn = get(conn, ~p"/sitemap.xml")

    assert response_content_type(conn, :xml) =~ "application/xml"
    body = response(conn, 200)

    assert body =~ ~s(<?xml version="1.0")
    assert body =~ "<urlset"
    assert body =~ ~s(xmlns:xhtml="http://www.w3.org/1999/xhtml")
  end

  test "the sitemap lists every public page, including localized URLs", %{conn: conn} do
    body = conn |> get(~p"/sitemap.xml") |> response(200)

    # Default-locale (prefix-free) pages.
    assert body =~ "<loc>http://localhost:4000/</loc>"
    assert body =~ "<loc>http://localhost:4000/how-it-works</loc>"
    assert body =~ "<loc>http://localhost:4000/pricing</loc>"
    assert body =~ "<loc>http://localhost:4000/privacy</loc>"

    # Locale-prefixed copies (fr is prefixed in every environment).
    assert body =~ "<loc>http://localhost:4000/fr</loc>"
    assert body =~ "<loc>http://localhost:4000/fr/how-it-works</loc>"
  end

  test "each sitemap entry carries hreflang alternates", %{conn: conn} do
    body = conn |> get(~p"/sitemap.xml") |> response(200)

    assert body =~ ~s(<xhtml:link rel="alternate" hreflang="fr")
    assert body =~ ~s(<xhtml:link rel="alternate" hreflang="x-default")
  end

  test "the sitemap never exposes ephemeral room pages", %{conn: conn} do
    body = conn |> get(~p"/sitemap.xml") |> response(200)

    refute body =~ "/rooms/"
  end
end
