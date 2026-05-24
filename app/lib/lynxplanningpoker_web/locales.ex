defmodule LynxplanningpokerWeb.Locales do
  @moduledoc """
  Single source of truth for how the four supported locales map onto URLs.

  The default locale (`en`, configured via the Gettext `default_locale`) lives
  at the URL root — `/`, `/pricing`. Every other locale is served under a URL
  path prefix: `/pt-br/pricing`, `/fr/pricing`, `/es/pricing`. A distinct,
  crawlable URL per language is what lets search engines index all four
  versions and is the backbone of the `hreflang` annotations in the head.

  ## Locale codes vs URL segments

  Gettext identifies Brazilian Portuguese as `pt_BR` (underscore) — the name of
  its `priv/gettext` directory. That underscore is unusual in a URL, so the
  *URL segment* for that locale is `pt-br` (`url_segment/1`). For `fr`/`es` the
  segment equals the locale code. `bcp47/1` gives the `hreflang` form.

  This module is imported into every template via `LynxplanningpokerWeb`, so the
  helpers below (`localized_path/2`, `bcp47/1`, ...) are available unqualified
  inside `.heex` files.
  """

  @known ~w(pt_BR en fr es)

  @default Application.compile_env(
             :lynxplanningpoker,
             [LynxplanningpokerWeb.Gettext, :default_locale],
             "en"
           )

  # Locales served under a URL path prefix (everything but the default).
  @url_prefixed @known -- [@default]

  # Locale code -> URL segment, where they differ.
  @segment_overrides %{"pt_BR" => "pt-br"}

  # URL path segments of the prefixed locales, e.g. ["pt-br", "fr", "es"].
  @url_segments Enum.map(@url_prefixed, &Map.get(@segment_overrides, &1, &1))

  # URL segment -> locale code, e.g. %{"pt-br" => "pt_BR", "fr" => "fr", ...}.
  @segment_to_locale Map.new(@known, &{Map.get(@segment_overrides, &1, &1), &1})

  @doc "Every supported locale code."
  def known, do: @known

  @doc "All supported locales, the URL-root (default) locale first."
  def all, do: [@default | @url_prefixed]

  @doc "Locale codes that carry a URL path prefix (everything but the default)."
  def url_prefixed, do: @url_prefixed

  @doc "URL path segments of the prefixed locales (e.g. pt-br, fr, es)."
  def url_segments, do: @url_segments

  @doc "The default locale, served at the URL root with no prefix."
  def default, do: @default

  @doc "URL path segment for a locale code (`pt_BR` -> `pt-br`, `fr` -> `fr`)."
  def url_segment(locale), do: Map.get(@segment_overrides, locale, locale)

  @doc "Locale code for a URL path segment (`pt-br` -> `pt_BR`); `nil` if unknown."
  def locale_from_segment(segment), do: Map.get(@segment_to_locale, segment)

  @doc """
  BCP-47 language tag for `<html lang>` and `hreflang` attributes.

  Gettext stores Brazilian Portuguese as `pt_BR` (underscore); the web
  standards expect a hyphen (`pt-BR`).
  """
  def bcp47("pt_BR"), do: "pt-BR"
  def bcp47(locale) when locale in @known, do: locale

  @doc "Open Graph locale code (`og:locale`), e.g. `en_US`, `pt_BR`, `fr_FR`."
  def og_locale("pt_BR"), do: "pt_BR"
  def og_locale("en"), do: "en_US"
  def og_locale("fr"), do: "fr_FR"
  def og_locale("es"), do: "es_ES"

  @doc """
  Prefixes `path` with the locale's URL segment, returning it unchanged for the
  default locale.

      localized_path(default(), "/pricing")  # => "/pricing"
      localized_path("pt_BR", "/pricing")     # => "/pt-br/pricing"
      localized_path("fr", "/")               # => "/fr"
  """
  def localized_path(@default, path), do: path

  def localized_path(locale, "/") when locale in @url_prefixed,
    do: "/" <> url_segment(locale)

  def localized_path(locale, "/" <> _ = path) when locale in @url_prefixed,
    do: "/" <> url_segment(locale) <> path

  @doc """
  Strips a leading locale segment from a request path, yielding the canonical
  default-locale path. The inverse of `localized_path/2`.

      base_path("/pt-br/pricing")  # => "/pricing"
      base_path("/fr")             # => "/"
      base_path("/pricing")        # => "/pricing"
  """
  def base_path("/" <> _ = path) do
    case String.split(path, "/", parts: 3) do
      ["", seg, rest] when seg in @url_segments -> "/" <> rest
      ["", seg] when seg in @url_segments -> "/"
      _ -> path
    end
  end
end
