defmodule LynxplanningpokerWeb.Plugs.CountVisit do
  @moduledoc """
  Records one anonymous unique visitor per `GET` page request.

  The same visitor revisiting the same site within a day produces the same
  hash and is deduplicated by the unique index on `(date, visitor_hash)`,
  so visiting ten times today counts as one — coming back tomorrow counts
  as one more (the hash includes the date). See `Lynxplanningpoker.Analytics`.

  Best-effort: any failure is swallowed so analytics can never break a page.
  """
  @behaviour Plug

  alias Lynxplanningpoker.Analytics
  alias LynxplanningpokerWeb.ClientIP

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Plug.Conn{method: "GET"} = conn, _opts) do
    _ =
      Analytics.record_visit(
        ip: ClientIP.from_conn(conn),
        user_agent: user_agent(conn),
        country: country(conn)
      )

    conn
  rescue
    _ -> conn
  end

  def call(conn, _opts), do: conn

  defp user_agent(conn) do
    case Plug.Conn.get_req_header(conn, "user-agent") do
      [ua | _] -> ua
      _ -> ""
    end
  end

  # Cloudflare sets CF-IPCountry to an ISO 3166-1 alpha-2 code (and "XX" /
  # "T1" for unknown / Tor). Anything that is not two letters becomes "XX".
  defp country(conn) do
    case Plug.Conn.get_req_header(conn, "cf-ipcountry") do
      [code | _] when is_binary(code) ->
        upcased = String.upcase(code)
        if upcased =~ ~r/\A[A-Z]{2}\z/, do: upcased, else: "XX"

      _ ->
        "XX"
    end
  end
end
