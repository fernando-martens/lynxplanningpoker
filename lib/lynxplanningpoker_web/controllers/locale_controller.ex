defmodule LynxplanningpokerWeb.LocaleController do
  use LynxplanningpokerWeb, :controller

  alias LynxplanningpokerWeb.Gettext, as: AppGettext

  def update(conn, %{"locale" => locale} = params) do
    return_to = sanitize_return_to(params["return_to"], conn)

    conn =
      if AppGettext.known?(locale) do
        put_session(conn, :locale, locale)
      else
        conn
      end

    redirect(conn, to: return_to)
  end

  defp sanitize_return_to("/" <> _ = path, _conn), do: path

  defp sanitize_return_to(_, conn) do
    case get_req_header(conn, "referer") do
      [ref | _] ->
        case URI.parse(ref) do
          %URI{path: "/" <> _ = path} -> path
          _ -> "/"
        end

      _ ->
        "/"
    end
  end
end
