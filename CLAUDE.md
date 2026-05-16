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
- Usar `mix precommit` ao finalizar alterações
- Usar `:req` para requisições HTTP (não `:httpoison` ou `:tesla`)
- Sempre usar LiveView streams para coleções de dados
- Não usar `daisyUI` — escrever componentes Tailwind manualmente
