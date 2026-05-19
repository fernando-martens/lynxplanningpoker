defmodule LynxplanningpokerWeb.Plugs.ContentSecurityPolicy do
  @moduledoc """
  Emits a per-request `content-security-policy` header with a cryptographic
  nonce that the inline theme-bootstrap script in `root.html.heex` references
  via `nonce={@csp_nonce}`. Generating a fresh nonce per request lets us
  drop `'unsafe-inline'` from `script-src` while still allowing the small
  first-party inline script.

  The nonce is also placed on `conn.assigns.csp_nonce` so templates can read
  it via `@csp_nonce`.

  `style-src` keeps `'unsafe-inline'` because the LiveView uses many
  `style="..."` attributes for runtime positioning (see `show.ex`), and the
  HTML spec only allows `'unsafe-inline'` / `'unsafe-hashes'` for those —
  refactoring every inline style would be much wider scope than this fix.
  """
  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    nonce = generate_nonce()

    conn
    |> Plug.Conn.assign(:csp_nonce, nonce)
    |> Plug.Conn.put_resp_header("content-security-policy", policy(nonce))
  end

  defp generate_nonce do
    16 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
  end

  defp policy(nonce) do
    [
      "default-src 'self'",
      "script-src 'self' 'nonce-#{nonce}' https://challenges.cloudflare.com",
      "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
      "img-src 'self' data:",
      "font-src 'self' data: https://fonts.gstatic.com",
      "frame-src https://challenges.cloudflare.com",
      "connect-src 'self' ws: wss:",
      "base-uri 'self'",
      "form-action 'self'",
      "frame-ancestors 'none'"
    ]
    |> Enum.join("; ")
  end
end
