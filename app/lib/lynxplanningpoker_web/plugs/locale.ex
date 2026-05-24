defmodule LynxplanningpokerWeb.Plugs.Locale do
  @moduledoc """
  Resolves the request locale and applies it via `Gettext.put_locale/2` for the
  duration of the request.

  The locale is decided **from the URL**:

    * a locale prefix (`/pt-br/...`, `/fr/...`, `/es/...`) selects that locale;
    * every prefix-free public page (`/`, `/pricing`, `/rooms/new`,
      `/rooms/invite/:id`, `POST /rooms`, ...) is, by definition, the default
      locale — each has a crawlable `/fr/...` copy for the other languages.

  This keeps each URL deterministically single-language — which is what search
  engines need, and what makes switching *back* to the default locale actually
  work (a prefix-free URL can't be overridden by a stale session).

  The live room (`/rooms/:id`) is the only exception: its link is shared, so it
  has no per-locale URL and renders in the locale stored in the session — set
  by `RoomController` when the visitor created or joined the room.
  `/rooms/leave` follows that same session locale so a leaving player lands on
  the home page in their language.

  ## The session is never written here

  The session `:locale` is written only by `RoomController` (on room create /
  join) and by `LocaleController` (the language switcher). This plug never
  touches it, so merely viewing a `/fr/...` page can't silently flip a
  visitor's sticky room language.

  The resolved locale is always assigned, so it flows through to LiveView via
  `live_session`.
  """

  import Plug.Conn

  alias LynxplanningpokerWeb.Gettext, as: AppGettext
  alias LynxplanningpokerWeb.Locales

  # URL path segments that select a locale (e.g. "pt-br", "fr", "es"). Inlined
  # as a module attribute so it can be used in a guard.
  @url_segments Locales.url_segments()

  def init(opts), do: opts

  def call(conn, _opts) do
    locale = resolve(conn)

    Gettext.put_locale(AppGettext, locale)
    assign(conn, :locale, locale)
  end

  defp resolve(conn) do
    case conn.path_info do
      # A URL locale prefix is authoritative.
      [seg | _] when seg in @url_segments ->
        Locales.locale_from_segment(seg)

      # Prefix-free room-entry pages are default-locale public pages, just like
      # `/` — they have crawlable `/fr/...` copies for the other locales.
      ["rooms", "new"] ->
        AppGettext.default_locale()

      ["rooms", "invite" | _] ->
        AppGettext.default_locale()

      # POST /rooms (room creation) — prefix-free, default locale.
      ["rooms"] ->
        AppGettext.default_locale()

      # The live room and `/rooms/leave` follow the session preference.
      ["rooms" | _] ->
        session_locale(conn)

      # Every other prefix-free public page is the default locale.
      _ ->
        AppGettext.default_locale()
    end
  end

  defp session_locale(conn) do
    case get_session(conn, :locale) do
      l when is_binary(l) ->
        if AppGettext.known?(l), do: l, else: AppGettext.default_locale()

      _ ->
        AppGettext.default_locale()
    end
  end
end
