# Lynx Planning Poker

Uma aplicação de Planning Poker em tempo real construída com **Elixir + Phoenix LiveView**.

## Stack

- **Elixir ~> 1.15** + **Phoenix 1.8**
- **Phoenix LiveView 1.1** para UI reativa em tempo real
- **PostgreSQL** via Ecto (UUID como primary key)
- **Tailwind CSS v4** + **esbuild**
- **Bandit** como servidor HTTP

## Como rodar

### Pré-requisitos

- Elixir >= 1.15 instalado
- PostgreSQL rodando em `localhost:5432` com usuário `postgres` / senha `postgres`

### Setup inicial (primeira vez)

```sh
mix setup
```

Esse comando executa: `deps.get` → `ecto.create` → `ecto.migrate` → `run seeds.exs` → build dos assets.

### Iniciar o servidor de desenvolvimento

```sh
mix phx.server
```

Acesse em: http://localhost:4000

### Banco de dados

```sh
mix ecto.reset   # drop + recria + migra + seeds
mix ecto.migrate # apenas roda as migrations pendentes
```

## Estrutura do projeto

```
lib/
  lynxplanningpoker/
    rooms/room.ex          # Schema: Room (id UUID, is_active bool)
    rooms.ex               # Contexto de Rooms (CRUD + PubSub)
    users/user.ex          # Schema: User (id UUID, name, vote int, belongs_to room)
    users.ex               # Contexto de Users (CRUD + PubSub)
  lynxplanningpoker_web/
    controllers/
      room_controller.ex   # new/create/show/acceptInvite
      room_html/           # Templates: new.html.heex, invite.html.heex
    live/
      room_live/show.ex    # LiveView da sala de jogo em tempo real
    router.ex              # Rotas da aplicação
    components/
      core_components.ex   # Componentes reutilizáveis (input, button, etc.)
      layouts.ex           # Layouts: root, app, room_header
priv/repo/migrations/      # Migrations do banco
assets/js/app.js           # Entrypoint JS (esbuild)
```

## Rotas principais

| Método | Path | Descrição |
|--------|------|-----------|
| GET | `/` | Home page |
| GET | `/rooms/new` | Criar nova sala |
| POST | `/rooms` | Salva sala + cria user host |
| GET | `/rooms/invite/:id` | Página de convite para entrar na sala |
| POST | `/rooms/invite/:id` | Aceita convite (cria user) |
| GET/LIVE | `/rooms/:id` | Sala de jogo em tempo real (LiveView) |

## Fluxo da aplicação

1. Host cria uma sala em `/rooms/new` informando seu nome → cria `Room` + `User` host
2. Host compartilha o link `/rooms/invite/:id` para outros jogadores
3. Jogadores acessam o link, informam seu nome → criados como `User` na sala
4. Todos são redirecionados para `/rooms/:id` onde a LiveView exibe os participantes em tempo real via PubSub

## Comandos úteis

```sh
mix precommit          # compile + format + test (rodar antes de commitar)
mix test               # roda os testes
mix test --failed      # roda apenas os testes que falharam
mix phx.routes         # lista todas as rotas
```

## Guidelines do projeto

- Seguir as guidelines em `AGENTS.md` (já carregado automaticamente)
- Rodar `mix format` ao finalizar qualquer edição de código Elixir
- Usar `mix precommit` ao finalizar alterações
- Usar `:req` para requisições HTTP (não `:httpoison` ou `:tesla`)
- Sempre usar LiveView streams para coleções de dados
- Não usar `daisyUI` — escrever componentes Tailwind manualmente
- **Sempre ajustar os testes quando a funcionalidade for alterada.** Toda mudança em contexto, controller, LiveView ou schema deve vir acompanhada da atualização dos testes correspondentes em `test/`. Rodar `mix test` antes de finalizar — não deixar testes quebrados ou desatualizados.
- **Sempre atualizar também os testes E2E em `../e2e/tests/`** quando a mudança afetar UI, rotas, fluxos de usuário, labels ou comportamento visível ao usuário (qualquer alteração em templates `.heex`, controllers, LiveViews, layouts ou seletor de idioma/tema). Se uma label/`msgid` for renomeada, atualizar também os seletores baseados em texto dos specs do Playwright. Se uma nova funcionalidade visível for adicionada, criar/estender o spec correspondente em `e2e/tests/`.
- **Internacionalização (i18n):** o app suporta três idiomas — **pt_BR** (padrão), **en** e **fr**. Toda nova label visível ao usuário (templates `.heex`, componentes, flashes em controllers/LiveViews, `title`/`aria-label`/`placeholder`) **deve** ser envolvida em `gettext("...")` (ou `dgettext("errors", "...")` para mensagens do Ecto). Para cada `msgid` novo, adicionar a tradução nos três arquivos: `priv/gettext/pt_BR/LC_MESSAGES/default.po`, `priv/gettext/en/LC_MESSAGES/default.po` e `priv/gettext/fr/LC_MESSAGES/default.po` (e também em `default.pot`). Não deixar `msgstr ""` vazio em nenhum dos três idiomas. Convenção: o `msgid` é escrito em inglês (fonte canônica do gettext) — mesmo quando o texto original na UI estava em português, traduzir o `msgid` para inglês e usar o texto pt_BR como `msgstr` do arquivo `pt_BR`.

## Testes

A suíte cobre as áreas críticas da aplicação:

```
test/
  lynxplanningpoker/
    rooms_test.exs                              # Contexto Rooms (CRUD + changeset)
    users_test.exs                              # Contexto Users (CRUD + PubSub + list_users_by_room)
  lynxplanningpoker_web/
    controllers/
      page_controller_test.exs                  # Home page
      room_controller_test.exs                  # new/create/show(invite)/acceptInvite + sessão
    live/
      room_live/show_test.exs                   # Mount com/sem sessão, vote, reveal, reset, PubSub
```

Diretrizes:
- Sempre que tocar em `lib/lynxplanningpoker/rooms.ex` ou `users.ex`, atualizar `test/lynxplanningpoker/*_test.exs`
- Sempre que tocar em controllers/LiveViews/templates, atualizar os testes em `test/lynxplanningpoker_web/`
- Em testes de LiveView, lembre que `render_click/1` retorna o HTML após `handle_event` mas **antes** do `handle_info` do PubSub. Para asserções sobre estado atualizado via broadcast, chamar `render(view)` depois

## Cores e temas CSS

- Todas as variáveis CSS de cor ficam em `assets/css/app.css`, dentro dos blocos `@plugin "../vendor/daisyui-theme"` de cada tema (`light` e `dark`)
- Nunca definir variáveis de cor fora desses blocos — o daisyUI theme plugin já cuida do modo sistema (`prefers-color-scheme`) e do toggle manual de tema automaticamente
- `assets/css/room.css` contém apenas estilos estruturais e animações, sem variáveis de cor
- **Sempre usar `oklch()` para cores** — nunca hex (`#RRGGBB`), `rgb()` ou `hsl()`. Se uma cor for fornecida em hex (ex: em um SVG ou design), converter para `oklch()` antes de adicionar no `app.css`. Convenção: `oklch(L% C H)` onde `L` é luminosidade (0–100%), `C` é croma (0 ≈ cinza, ~0.4 máx) e `H` é matiz em graus (0–360). Os tons roxos do app ficam em torno do hue 270–290
