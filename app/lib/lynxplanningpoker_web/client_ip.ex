defmodule LynxplanningpokerWeb.ClientIP do
  @moduledoc """
  Resolves the real client IP for a `Plug.Conn`.

  `conn.remote_ip` reflects the TCP peer, which behind a reverse proxy is the
  proxy itself. `X-Forwarded-For` carries the original client IP but is
  attacker-controlled when no proxy strips/overwrites it.

  We therefore only honor forwarding headers when the TCP peer is in the
  configured `:trusted_proxies` list. Header parsing (X-Forwarded-For, X-Real-IP,
  `Forwarded` RFC 7239, IPv6, etc.) is delegated to the `:remote_ip` library;
  the peer-is-trusted guard lives here because the library does not enforce it.

  Configure via `config :lynxplanningpoker, :trusted_proxies, ["1.2.3.0/24", ...]`.
  Defaults to `[]`, meaning forwarding headers are ignored and the TCP peer is
  used — the safe choice for environments without a known proxy in front.
  """

  alias RemoteIp.Block

  @doc """
  Returns the client IP as a string.
  """
  @spec from_conn(Plug.Conn.t()) :: String.t()
  def from_conn(conn) do
    valid = valid_proxies()
    remote = conn.remote_ip

    ip =
      cond do
        valid == [] ->
          remote

        peer_trusted?(remote, valid) ->
          RemoteIp.from(conn.req_headers, proxies: cidrs(valid)) || remote

        true ->
          remote
      end

    ip |> :inet.ntoa() |> to_string()
  end

  defp peer_trusted?(ip, valid) do
    encoded = Block.encode(ip)
    Enum.any?(valid, fn {_cidr, block} -> Block.contains?(block, encoded) end)
  end

  defp cidrs(valid), do: Enum.map(valid, fn {cidr, _block} -> cidr end)

  defp valid_proxies do
    :lynxplanningpoker
    |> Application.get_env(:trusted_proxies, [])
    |> Enum.map(&parse_entry/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_entry(cidr) when is_binary(cidr) do
    case Block.parse(cidr) do
      {:ok, block} ->
        {cidr, block}

      {:error, _} ->
        require Logger
        Logger.warning("invalid trusted_proxy CIDR: #{inspect(cidr)}")
        nil
    end
  end

  defp parse_entry(_), do: nil
end
