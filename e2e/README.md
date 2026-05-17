# Lynx Planning Poker — Testes E2E

Testes end-to-end de UI com [Playwright](https://playwright.dev/), totalmente
independentes da aplicação Elixir. Só dirigem o browser contra um servidor que
já está rodando em `http://localhost:4000`.

## Pré-requisitos

- Node.js 18+ e npm
- A aplicação Phoenix rodando em outro terminal:

```sh
cd ../app
mix phx.server
```

## Instalação (primeira vez)

```sh
cd e2e
npm install
npx playwright install
```

O segundo comando baixa os binários do Chromium/Firefox/WebKit.

## Rodar os testes

```sh
npm test              # roda tudo headless
npm run test:headed   # roda com o browser visível
npm run test:ui       # abre o modo interativo do Playwright
npm run test:debug    # roda em modo debug, pausando passo a passo
npm run report        # abre o último relatório HTML
```

Para rodar um único arquivo:

```sh
npx playwright test tests/voting.spec.ts
```

Para gravar testes interagindo manualmente no browser:

```sh
npm run codegen
```

## Cobertura atual

| Arquivo | O que cobre |
|---|---|
| `home.spec.ts` | Landing page, navegação para "Create a room" e "How it works", link de contato |
| `how-it-works.spec.ts` | Página informativa de 3 passos e volta para a home |
| `create-room.spec.ts` | Formulário de criação de sala, validação de nome, redirecionamento e modal inicial de convite |
| `invite-flow.spec.ts` | Convidado entrando via link de convite; sala inexistente; convite sem nome |
| `voting.spec.ts` | Votação nas 12 cartas (0–89 e `?`), toggle de voto e troca de carta |
| `reveal-reset.spec.ts` | Revelar votos, cálculo da média, reset, badge de "voto alterado após reveal" |
| `multi-user.spec.ts` | PubSub em tempo real: entrada, voto e encerramento entre múltiplos browsers |
| `room-actions.spec.ts` | Botão Invite, diferença host vs. guest, Leave, End planning |
| `language-switcher.spec.ts` | Troca de locale (pt_BR / en / fr) e persistência na sessão |
| `theme-toggle.spec.ts` | Alternância entre tema claro, escuro e sistema |

## Notas

- Os testes assumem o **banco com estado limpo** apenas para casos que
  validam ausência de estado prévio. Salas e usuários criados pelos testes
  ficam no banco até serem encerrados ou expirarem.
- Para evitar dependência do idioma, todos os testes começam definindo o
  locale como `en` via `GET /locale/en` (helper `ensureEnglishLocale`).
- O `playwright.config.ts` roda com `workers: 1` e `fullyParallel: false`
  porque a aplicação compartilha estado de banco; rodar tudo em paralelo
  geraria interferência entre testes.
- Para apontar para outro ambiente, exporte `BASE_URL`:
  ```sh
  BASE_URL=https://staging.exemplo.com npm test
  ```

## Quando adicionar novos testes

Toda vez que uma funcionalidade visível ao usuário for adicionada/alterada
em `app/lib/lynxplanningpoker_web/`, considere adicionar/atualizar o teste
correspondente aqui.
