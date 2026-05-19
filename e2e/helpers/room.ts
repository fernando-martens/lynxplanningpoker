import { Page, Browser, BrowserContext, expect } from "@playwright/test";

/**
 * Garante que a UI esteja em inglês — assim os seletores baseados em texto
 * batem com os msgids do gettext (que são canônicos em inglês).
 */
export async function ensureEnglishLocale(page: Page): Promise<void> {
  await page.goto("/locale/en");
  await expect(page).toHaveURL(/\/(?!locale)/);
}

/**
 * Espera o LiveView terminar de conectar via WebSocket. Sem isso, o
 * `phx-mounted` que abre o modal inicial e as classes `phx-click` ainda não
 * estão ligadas — clicar em cartas/botões antes disso é no-op.
 */
export async function waitForLiveView(page: Page, timeout = 10_000): Promise<void> {
  await page.waitForFunction(
    () => {
      const ls = (window as unknown as { liveSocket?: { isConnected?: () => boolean } })
        .liveSocket;
      return !!ls && typeof ls.isConnected === "function" && ls.isConnected();
    },
    null,
    { timeout },
  );
}

/**
 * Cria uma sala nova como host e retorna a URL da sala (/rooms/:id).
 */
export async function createRoomAsHost(
  page: Page,
  hostName: string,
): Promise<string> {
  await ensureEnglishLocale(page);
  await page.goto("/");
  await page.getByRole("link", { name: /Create a room/i }).click();

  await expect(page).toHaveURL(/\/rooms\/new$/);

  await page.getByLabel(/Your name/i).fill(hostName);
  // Em dev as test keys do Cloudflare Turnstile (1x00...AA) auto-resolvem
  // o widget; esperamos o hidden input com o token ser preenchido antes de
  // submeter pra não cair no flash de erro de verificação.
  await page.waitForFunction(
    () => {
      const el = document.querySelector(
        'input[name="cf-turnstile-response"]',
      ) as HTMLInputElement | null;
      return !!el && el.value.length > 0;
    },
    null,
    { timeout: 15_000 },
  );
  await page.getByRole("button", { name: /Join your room/i }).click();

  await expect(page).toHaveURL(/\/rooms\/[0-9a-f-]{36}$/);
  await waitForLiveView(page);
  // Sanity check: confirma que a sala terminou de renderizar
  await expect(page.locator("button.room-card").first()).toBeVisible({
    timeout: 15_000,
  });
  return page.url();
}

/**
 * Faz um segundo usuário entrar em uma sala existente, dado o link da sala.
 *
 * IMPORTANTE: cria um BrowserContext NOVO para o guest. Compartilhar o
 * contexto do host faria o cookie de sessão do host ser reusado; o controller
 * `cleanup_previous_session` interpretaria o "guest" como o próprio host e
 * APAGARIA a sala antes de criar o user — quebrando todos os testes
 * multi-usuário. O caller é responsável por chamar `context.close()` no fim.
 */
export async function joinRoomAsGuest(
  browser: Browser,
  roomUrl: string,
  guestName: string,
): Promise<{ page: Page; context: BrowserContext }> {
  const inviteUrl = roomUrl.replace(/\/rooms\/([0-9a-f-]{36})$/, "/rooms/invite/$1");

  const context = await browser.newContext();
  const page = await context.newPage();
  await ensureEnglishLocale(page);
  await page.goto(inviteUrl);

  await expect(page.getByRole("heading", { name: /You're invited!/i })).toBeVisible();
  await page.getByLabel(/Your name/i).fill(guestName);
  await page.getByRole("button", { name: /Join the room/i }).click();

  await expect(page).toHaveURL(/\/rooms\/[0-9a-f-]{36}$/);
  await waitForLiveView(page);
  // Sanity check: confirma que a sala terminou de renderizar e que o LiveView
  // não nos rebateu para /rooms/invite/:id por falta de sessão.
  await expect(page.locator("button.room-card").first()).toBeVisible({
    timeout: 15_000,
  });
  return { page, context };
}

/**
 * Fecha a modal de convite que aparece automaticamente para o host quando
 * está sozinho na sala. O modal só é aberto após o LiveView conectar (via
 * `phx-mounted` no trigger renderizado quando `connected?(socket)`), por isso
 * esperamos explicitamente até 5s antes de desistir.
 */
export async function dismissInviteModalIfOpen(page: Page): Promise<void> {
  const modal = page.locator("#invite-modal");
  try {
    await modal.waitFor({ state: "visible", timeout: 5000 });
  } catch {
    return;
  }
  await modal.getByRole("button", { name: /Close/i }).click();
  await expect(modal).toBeHidden();
}
