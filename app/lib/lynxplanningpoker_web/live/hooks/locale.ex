defmodule LynxplanningpokerWeb.LiveHooks.Locale do
  @moduledoc """
  `on_mount` hook that restores the current locale (set by the HTTP request
  plug and forwarded through the LiveView session) so LiveView renders pick
  up the correct translations.
  """

  import Phoenix.Component, only: [assign: 3]

  alias LynxplanningpokerWeb.Gettext, as: AppGettext

  def on_mount(:default, _params, session, socket) do
    locale =
      case session["locale"] do
        l when is_binary(l) -> if AppGettext.known?(l), do: l, else: AppGettext.default_locale()
        _ -> AppGettext.default_locale()
      end

    Gettext.put_locale(AppGettext, locale)
    {:cont, assign(socket, :locale, locale)}
  end
end
