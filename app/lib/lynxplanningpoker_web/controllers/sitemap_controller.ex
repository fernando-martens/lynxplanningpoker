defmodule LynxplanningpokerWeb.SitemapController do
  @moduledoc """
  Serves `/sitemap.xml`.

  Lists every indexable public page in all four languages. Each `<url>` carries
  the complete set of `hreflang` alternates so search engines treat the
  translations as one clustered page instead of duplicate content.

  Room pages are deliberately excluded — they are ephemeral, unguessable and
  marked `noindex`.
  """
  use LynxplanningpokerWeb, :controller

  alias LynxplanningpokerWeb.Locales
  alias LynxplanningpokerWeb.SEO

  # Default-locale paths of every indexable page.
  @pages ~w(/ /how-it-works /pricing /privacy /security)

  def index(conn, _params) do
    conn
    |> put_resp_content_type("application/xml")
    |> send_resp(200, build())
  end

  defp build do
    urls = Enum.map_join(@pages, "", &page_urls/1)

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">
    #{urls}</urlset>
    """
  end

  # One <url> entry per locale of a page; every entry repeats the same set of
  # hreflang alternates, as the sitemap protocol requires.
  defp page_urls(path) do
    alternates = alternate_links(path)

    Enum.map_join(Locales.all(), "", fn locale ->
      loc = SEO.absolute_url(Locales.localized_path(locale, path))

      """
      <url>
      <loc>#{loc}</loc>
      #{alternates}</url>
      """
    end)
  end

  defp alternate_links(path) do
    per_locale =
      Enum.map_join(Locales.all(), "", fn locale ->
        href = SEO.absolute_url(Locales.localized_path(locale, path))
        ~s(<xhtml:link rel="alternate" hreflang="#{Locales.bcp47(locale)}" href="#{href}"/>\n)
      end)

    per_locale <>
      ~s(<xhtml:link rel="alternate" hreflang="x-default" href="#{SEO.absolute_url(path)}"/>\n)
  end
end
