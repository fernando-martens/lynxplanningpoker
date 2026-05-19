defmodule Lynxplanningpoker.Turnstile do
  @moduledoc """
  Cloudflare Turnstile client.

  Wraps the [siteverify endpoint](https://developers.cloudflare.com/turnstile/get-started/server-side-validation/)
  so the controller can validate the token submitted by the browser widget.

  Configuration lives under `:lynxplanningpoker, :turnstile` with keys
  `:enabled`, `:site_key`, `:secret_key`. When `:enabled` is `false`,
  `verify/2` short-circuits with `:ok` — useful for the test suite and any
  environment without Cloudflare credentials.
  """

  require Logger

  @endpoint "https://challenges.cloudflare.com/turnstile/v0/siteverify"

  @doc "Public site key, safe to ship to the browser. `nil` when disabled."
  def site_key, do: config()[:site_key]

  @doc "Whether server-side verification is active in this environment."
  def enabled?, do: Keyword.get(config(), :enabled, false)

  @doc """
  Verifies a Turnstile token against Cloudflare's siteverify endpoint.

  Returns `:ok` on success or `{:error, reason}`. When the module is disabled
  via config (`enabled: false`), always returns `:ok`.
  """
  @spec verify(String.t() | nil, String.t() | nil) :: :ok | {:error, term()}
  def verify(token, remote_ip \\ nil) do
    cond do
      not enabled?() ->
        :ok

      is_nil(token) or token == "" ->
        {:error, :missing_token}

      true ->
        do_verify(token, remote_ip)
    end
  end

  defp do_verify(token, remote_ip) do
    secret = config()[:secret_key]

    if is_nil(secret) or secret == "" do
      Logger.error("turnstile enabled but :secret_key is missing")
      {:error, :missing_secret}
    else
      body =
        %{"secret" => secret, "response" => token}
        |> maybe_put_remote_ip(remote_ip)

      case Req.post(@endpoint, form: body, receive_timeout: 5_000) do
        {:ok, %Req.Response{status: 200, body: %{"success" => true}}} ->
          :ok

        {:ok, %Req.Response{body: %{"error-codes" => codes}}} ->
          Logger.warning("turnstile rejected token codes=#{inspect(codes)}")
          {:error, {:rejected, codes}}

        {:ok, %Req.Response{status: status}} ->
          Logger.warning("turnstile unexpected response status=#{status}")
          {:error, {:unexpected_status, status}}

        {:error, reason} ->
          Logger.warning("turnstile request failed: #{inspect(reason)}")
          {:error, {:request_failed, reason}}
      end
    end
  end

  defp maybe_put_remote_ip(body, nil), do: body
  defp maybe_put_remote_ip(body, ""), do: body
  defp maybe_put_remote_ip(body, ip), do: Map.put(body, "remoteip", ip)

  defp config, do: Application.get_env(:lynxplanningpoker, :turnstile, [])
end
