# Guia de Deploy — Lynx Planning Poker

Tudo que precisa estar pronto para subir a aplicação em produção.

---

## 1. Variáveis de ambiente

Definidas em [`app/config/runtime.exs`](app/config/runtime.exs). As marcadas como **obrigatórias** fazem o boot da app falhar com mensagem clara se estiverem ausentes.

| Variável | Obrigatória | Default | Descrição |
|---|---|---|---|
| `PHX_SERVER` | **sim** (releases) | — | Defina como `true` para o release iniciar o endpoint HTTP. |
| `SECRET_KEY_BASE` | **sim** | — | Chave de assinatura de cookies/sessão. Gere com `mix phx.gen.secret` (64+ chars). **Não commitar.** |
| `DATABASE_URL` | **sim** | — | Ex.: `ecto://user:pass@host:5432/lynxplanningpoker_prod`. |
| `CLOUDFLARE_TURNSTILE_SITE_KEY` | **sim** | — | Chave pública (vai pro browser). Pegue no [dashboard do Turnstile](https://dash.cloudflare.com/?to=/:account/turnstile). |
| `CLOUDFLARE_TURNSTILE_SECRET_KEY` | **sim** | — | Chave secreta (server-side). |
| `PHX_HOST` | recomendada | `example.com` | Hostname público (sem esquema/porta). Usado em URLs absolutas. |
| `PORT` | não | `4000` | Porta HTTP do Bandit. Atrás de proxy/CDN normalmente fica 4000 mesmo. |
| `POOL_SIZE` | não | `10` | Tamanho do pool do Postgres. Comece com 10; ajuste vendo `mix.ecto` e métricas. |
| `ECTO_IPV6` | não | `false` | Defina `true` se o Postgres só responde via IPv6. |
| `TRUSTED_PROXIES` | **sim se houver CDN/LB na frente** | `""` | CSV de CIDRs cujos `X-Forwarded-For` são confiáveis. Ex.: `173.245.48.0/20,103.21.244.0/22,...`. Sem isso, a app ignora o header e enxerga apenas o IP TCP (o do CDN), o que **quebra rate limit e Turnstile por IP**. |
| `DNS_CLUSTER_QUERY` | não | — | Consulta DNS para clustering de nós Elixir (Fly.io, etc.). Ignore se rodando 1 nó. |

### Faixas do Cloudflare (para `TRUSTED_PROXIES`)

Lista oficial atualizada: <https://www.cloudflare.com/ips/>. No momento da escrita:

```
TRUSTED_PROXIES=173.245.48.0/20,103.21.244.0/22,103.22.200.0/22,103.31.4.0/22,141.101.64.0/18,108.162.192.0/18,190.93.240.0/20,188.114.96.0/20,197.234.240.0/22,198.41.128.0/17,162.158.0.0/15,104.16.0.0/13,104.24.0.0/14,172.64.0.0/13,131.0.72.0/22,2400:cb00::/32,2606:4700::/32,2803:f800::/32,2405:b500::/32,2405:8100::/32,2a06:98c0::/29,2c0f:f248::/32
```

Atualize a lista sempre que a Cloudflare publicar mudanças.

---

## 2. Banco de dados

- Postgres 14+ (use a mesma major version do dev — hoje `postgres:16` no [`docker-compose.yml`](app/docker-compose.yml)).
- Crie um usuário **dedicado** com permissão só na database da app (não use `postgres` superuser).
- Habilite SSL no servidor. Para forçar SSL no cliente, descomente `ssl: true` em `Lynxplanningpoker.Repo` no [`runtime.exs`](app/config/runtime.exs#L55-L61).
- Backups automatizados (pg_dump diário, retention ≥ 7 dias). Mesmo que rooms sejam efêmeras, perder schema é caro.

### Migrations no deploy

Releases não embarcam `mix`. Para rodar migrations, crie `lib/lynxplanningpoker/release.ex`:

```elixir
defmodule Lynxplanningpoker.Release do
  @app :lynxplanningpoker

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos, do: Application.fetch_env!(@app, :ecto_repos)

  defp load_app do
    Application.load(@app)
  end
end
```

E rode antes de iniciar o release novo:

```sh
bin/lynxplanningpoker eval "Lynxplanningpoker.Release.migrate"
```

---

## 3. Build do release

```sh
cd app

# Uma única vez no projeto (gera Dockerfile, rel/, etc.)
mix phx.gen.release

# A cada deploy
MIX_ENV=prod mix deps.get --only prod
MIX_ENV=prod mix compile
MIX_ENV=prod mix assets.deploy   # tailwind --minify, esbuild --minify, phx.digest
MIX_ENV=prod mix release
```

O binário fica em `_build/prod/rel/lynxplanningpoker/bin/lynxplanningpoker`.

Subir com:

```sh
PHX_SERVER=true \
SECRET_KEY_BASE=... \
DATABASE_URL=... \
PHX_HOST=poker.seudominio.com \
CLOUDFLARE_TURNSTILE_SITE_KEY=... \
CLOUDFLARE_TURNSTILE_SECRET_KEY=... \
TRUSTED_PROXIES=... \
bin/lynxplanningpoker start
```

---

## 4. HTTPS / TLS

A app **não** termina TLS sozinha por padrão. Duas opções:

### Opção A — TLS no proxy (recomendado)

Termine TLS na Cloudflare / nginx / Caddy / load balancer e mande HTTP plano pra Bandit (porta 4000). É a abordagem mais simples e é o que `PHX_HOST` + `TRUSTED_PROXIES` assumem.

`force_ssl: [hsts: true, rewrite_on: [:x_forwarded_proto], exclude: [...]]` já está habilitado em [`prod.exs`](app/config/prod.exs) — qualquer requisição HTTP que escape do proxy é redirecionada pra HTTPS, e o cabeçalho HSTS é emitido. O `rewrite_on` faz Plug.SSL respeitar o `X-Forwarded-Proto` do proxy (sem isso, a app vê todo request como HTTP e cai em loop de redirect). **`:force_ssl` precisa ficar em `prod.exs` (compile-time), não em `runtime.exs`** — defini-lo nos dois lugares com valores diferentes faz o boot abortar com erro de `validate_compile_env`.

### Opção B — TLS direto no Bandit

Adicione em `runtime.exs`:

```elixir
config :lynxplanningpoker, LynxplanningpokerWeb.Endpoint,
  https: [
    port: 443,
    cipher_suite: :strong,
    keyfile: System.get_env("SSL_KEY_PATH"),
    certfile: System.get_env("SSL_CERT_PATH")
  ]
```

---

## 5. Headers de segurança

`put_secure_browser_headers` no [`router.ex`](app/lib/lynxplanningpoker_web/router.ex) adiciona `x-frame-options`, `x-content-type-options`, etc., e o plug [`ContentSecurityPolicy`](app/lib/lynxplanningpoker_web/plugs/content_security_policy.ex) emite um `content-security-policy` com **nonce por requisição**. A política autoriza:

- `'self'` para tudo
- `'nonce-<per-request>'` em `script-src` — usado pelo script inline de bootstrap de tema em `root.html.heex` via `nonce={@csp_nonce}`
- `https://challenges.cloudflare.com` em `script-src`/`frame-src` (widget Turnstile)
- `https://fonts.googleapis.com` em `style-src` e `https://fonts.gstatic.com` em `font-src` (Google Fonts)
- `'unsafe-inline'` em **style-src** (necessário para os `style="..."` runtime de posicionamento no LiveView; remover exigiria refatorar todo o posicionamento)
- `data:` em img/font (SVGs inline, fontes embutidas)
- `ws: wss:` em `connect-src` (socket do LiveView e LiveReloader em dev)
- `frame-ancestors 'none'` (anti-clickjacking)

`script-src` **não** tem mais `'unsafe-inline'`. Se precisar adicionar um novo script inline, anote-o com `nonce={@csp_nonce}`. Para incluir um domínio externo (CDN, analytics), atualize a função `policy/1` no plug.

---

## 6. WebSocket / LiveView

Em prod, [`runtime.exs`](app/config/runtime.exs) já configura `check_origin: ["https://#{host}", "//#{host}"]` no endpoint, derivado de `PHX_HOST`. Isso rejeita qualquer upgrade WebSocket/LiveView cujo header `Origin` não bata com o domínio público — protege contra ataques tipo CSWSH (cross-site WebSocket hijacking).

Em dev, o default do Phoenix (`check_origin: true` validando contra o `:url` host = `localhost`) já é o suficiente; não precisa configurar nada.

---

## 7. Cloudflare (se for o proxy)

- Modo SSL: **Full (strict)** — não use Flexible (HTTP entre Cloudflare e origin é inseguro).
- Always Use HTTPS: ON.
- WAF: deixe ligado, mas desabilite "Bot Fight Mode" para o path `/live` (WebSocket) se ele bloquear.
- Cache rules: **não** cachear `/`, `/rooms/*`, `/live`. Cachear apenas `/assets/*`.
- Turnstile: configure o widget para o domínio de prod (`poker.seudominio.com`).
- **Firewall regra obrigatória**: bloquear acesso direto ao IP do origin. Sem isso, `TRUSTED_PROXIES` perde valor porque um atacante pode bater no origin direto enviando `X-Forwarded-For` spoofado.

---

## 8. Observabilidade

- **LiveDashboard**: hoje só está habilitado em dev (`config :lynxplanningpoker, :dev_routes` em [`config/dev.exs`](app/config/dev.exs)). Para usar em prod, monte por trás de Basic Auth no router (ver comentário em [`router.ex:63-75`](app/lib/lynxplanningpoker_web/router.ex#L63-L75)).
- **Logs**: defina `LOG_LEVEL=info` (padrão) e centralize stdout num agregador (Loki / Datadog / Papertrail).
- **Métricas**: telemetry já está plugado em [`telemetry.ex`](app/lib/lynxplanningpoker_web/telemetry.ex). Conecte a um Prometheus/Grafana se quiser dashboards.
- **Erros**: integrar Sentry/Honeybadger (`mix.exs` → adicionar `:sentry`, configurar `Sentry.LoggerHandler` em `application.ex`).

---

## 9. Email

O Mailer ([`mailer.ex`](app/lib/lynxplanningpoker/mailer.ex)) usa adaptador `Local` em todos os ambientes hoje. **Se algum dia for usar email em prod**, configure em `runtime.exs`:

```elixir
config :lynxplanningpoker, Lynxplanningpoker.Mailer,
  adapter: Swoosh.Adapters.Mailgun,
  api_key: System.get_env("MAILGUN_API_KEY"),
  domain: System.get_env("MAILGUN_DOMAIN")

config :swoosh, :api_client, Swoosh.ApiClient.Req
```

---

## 10. Checklist final antes do go-live

- [ ] `SECRET_KEY_BASE` gerado e injetado (não está no repo).
- [ ] `DATABASE_URL` aponta para Postgres de prod, usuário não-superuser, SSL ligado.
- [ ] `PHX_HOST` setado com o domínio real.
- [ ] `CLOUDFLARE_TURNSTILE_SITE_KEY` / `..._SECRET_KEY` são as chaves de prod (não as `1x0000...` de dev).
- [ ] `TRUSTED_PROXIES` contém todas as faixas do CDN/LB usado.
- [ ] Origin firewallado para aceitar tráfego só do CDN.
- [x] `force_ssl: [hsts: true, rewrite_on: [:x_forwarded_proto]]` ativo em `prod.exs` (compile-time).
- [x] `check_origin` do socket LiveView restringe ao domínio de prod (derivado de `PHX_HOST`).
- [x] CSP configurado no `put_secure_browser_headers` (router.ex `@csp`).
- [ ] Migrations rodadas: `bin/lynxplanningpoker eval "Lynxplanningpoker.Release.migrate"`.
- [ ] LiveDashboard ou está desabilitado ou está atrás de Basic Auth.
- [ ] Backup automatizado do Postgres ativo.
- [ ] Healthcheck do orquestrador apontando para `GET /` (retorna 200).
- [ ] Logs e métricas chegando ao agregador.
- [ ] Smoke test: criar sala, abrir 2 abas, votar, revelar, encerrar — tudo via domínio público.
