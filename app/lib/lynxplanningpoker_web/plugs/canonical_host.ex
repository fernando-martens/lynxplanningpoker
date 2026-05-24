defmodule LynxplanningpokerWeb.Plugs.CanonicalHost do
  @moduledoc """
  Redirects every request whose `Host` doesn't match the canonical host to
  `https://<canonical-host>` with a permanent (301) redirect, preserving the
  request path and query string.

  The canonical host is read at request time from the
  `:lynxplanningpoker, :canonical_host` application env. It is only configured
  in `config/runtime.exs` for `:prod` (set to `PHX_HOST`), so in dev and test
  the env is unset and the plug is a no-op — no redirect ever happens.

  Purpose: keep `lynxplanningpoker.com` as the single public origin. The Fly-issued
  `lynxplanningpoker.fly.dev` subdomain (and any other host) is bounced to it.
  Besides avoiding duplicate content for SEO, this guarantees LiveView /
  WebSocket upgrades always carry an `Origin` the endpoint's `check_origin`
  accepts — on a non-canonical host the realtime rooms would be rejected.
  """
  @behaviour Plug

  import Plug.Conn

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    case Application.get_env(:lynxplanningpoker, :canonical_host) do
      nil -> conn
      canonical -> redirect_unless_canonical(conn, canonical)
    end
  end

  defp redirect_unless_canonical(conn, canonical) do
    # Host comparison is case-insensitive (RFC 3986 §3.2.2).
    if String.downcase(conn.host) == String.downcase(canonical) do
      conn
    else
      conn
      |> put_resp_header("location", "https://#{canonical}" <> request_target(conn))
      |> put_resp_content_type("text/plain")
      |> send_resp(301, "Moved Permanently")
      |> halt()
    end
  end

  defp request_target(%Plug.Conn{request_path: path, query_string: ""}), do: path

  defp request_target(%Plug.Conn{request_path: path, query_string: query}),
    do: path <> "?" <> query
end
