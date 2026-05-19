defmodule LynxplanningpokerWeb.Plugs.RateLimit do
  @moduledoc """
  Aplica rate limit por IP usando `Lynxplanningpoker.RateLimit` (Hammer).

  Opções:
    * `:bucket`    - identificador do bucket (string ou átomo, obrigatório)
    * `:config`    - chave em `:lynxplanningpoker, :rate_limit` para carregar
                     `[limit: _, scale_ms: _]` em runtime. Quando presente,
                     tem precedência sobre `:limit`/`:scale_ms`.
    * `:scale_ms`  - janela em milissegundos (default: 60_000)
    * `:limit`     - número máximo de requisições na janela (default: 120)

  Em caso de excesso, retorna HTTP 429 com uma página de erro traduzida e
  o header `Retry-After`.
  """

  import Plug.Conn

  require Logger

  alias Lynxplanningpoker.RateLimit

  def init(opts) do
    %{
      bucket: to_string(Keyword.fetch!(opts, :bucket)),
      config_key: Keyword.get(opts, :config),
      scale_ms: Keyword.get(opts, :scale_ms, 60_000),
      limit: Keyword.get(opts, :limit, 120)
    }
  end

  def call(conn, %{bucket: bucket} = opts) do
    {limit, scale} = resolve_limits(opts)
    ip = client_ip(conn)
    key = "#{bucket}:#{ip}"

    case RateLimit.hit(key, scale, limit) do
      {:allow, _count} ->
        conn

      {:deny, retry_after_ms} ->
        retry_after_s = div(retry_after_ms, 1000) + 1

        Logger.warning(
          "rate limit exceeded bucket=#{bucket} ip=#{ip} retry_after=#{retry_after_s}s"
        )

        conn
        |> put_resp_header("retry-after", Integer.to_string(retry_after_s))
        |> put_status(:too_many_requests)
        |> Phoenix.Controller.put_view(html: LynxplanningpokerWeb.ErrorHTML)
        |> Phoenix.Controller.put_format("html")
        |> Phoenix.Controller.render(:"429", retry_after_s: retry_after_s)
        |> halt()
    end
  end

  defp resolve_limits(%{config_key: nil, limit: limit, scale_ms: scale}), do: {limit, scale}

  defp resolve_limits(%{config_key: key, limit: default_limit, scale_ms: default_scale}) do
    cfg = Application.get_env(:lynxplanningpoker, :rate_limit, [])
    bucket_cfg = Keyword.get(cfg, key, [])

    {Keyword.get(bucket_cfg, :limit, default_limit),
     Keyword.get(bucket_cfg, :scale_ms, default_scale)}
  end

  defp client_ip(conn) do
    case get_req_header(conn, "x-forwarded-for") do
      [forwarded | _] ->
        forwarded |> String.split(",") |> List.first() |> String.trim()

      _ ->
        conn.remote_ip |> :inet.ntoa() |> to_string()
    end
  end
end
