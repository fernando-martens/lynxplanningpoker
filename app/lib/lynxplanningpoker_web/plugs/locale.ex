defmodule LynxplanningpokerWeb.Plugs.Locale do
  @moduledoc """
  Reads the current locale from the session (or falls back to the default)
  and applies it via `Gettext.put_locale/2` for the duration of the request.
  Also persists the resolved locale back to the session and assigns so it can
  be passed through to LiveView via `live_session`.
  """

  import Plug.Conn

  alias LynxplanningpokerWeb.Gettext, as: AppGettext

  def init(opts), do: opts

  def call(conn, _opts) do
    locale =
      case get_session(conn, :locale) do
        l when is_binary(l) -> if AppGettext.known?(l), do: l, else: AppGettext.default_locale()
        _ -> AppGettext.default_locale()
      end

    Gettext.put_locale(AppGettext, locale)

    conn
    |> put_session(:locale, locale)
    |> assign(:locale, locale)
  end
end
