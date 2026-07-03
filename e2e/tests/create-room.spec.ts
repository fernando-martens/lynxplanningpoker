import { test, expect } from "@playwright/test";
import {
  ensureEnglishLocale,
  createRoomAsHost,
  waitForLiveView,
} from "../helpers/room";

test.describe("Criação de sala (host)", () => {
  test.beforeEach(async ({ page }) => {
    await ensureEnglishLocale(page);
  });

  test("exibe o formulário de criação com os campos esperados", async ({ page }) => {
    await page.goto("/rooms/new");

    await expect(
      page.getByRole("heading", { name: /Start a new session/i }),
    ).toBeVisible();
    // Não há mais campo de nome — só o Turnstile e o botão.
    await expect(page.getByLabel(/Your name/i)).toHaveCount(0);
    await expect(page.locator(".cf-turnstile")).toBeVisible();
    await expect(
      page.getByRole("button", { name: /Create room/i }),
    ).toBeVisible();
  });

  test("cria uma sala e redireciona para /rooms/:id", async ({ page }) => {
    const roomUrl = await createRoomAsHost(page, "Host Tester");
    expect(roomUrl).toMatch(/\/rooms\/[0-9a-f-]{36}$/);
  });

  test("após pular o nome, exibe automaticamente a modal de convite para o host sozinho", async ({
    page,
  }) => {
    await page.goto("/rooms/new");
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
    await page.getByRole("button", { name: /Create room/i }).click();
    await expect(page).toHaveURL(/\/rooms\/[0-9a-f-]{36}$/);
    await waitForLiveView(page);

    // O prompt de nome abre primeiro; ao pular, a modal de convite aparece.
    const profile = page.locator("#profile-modal");
    await expect(profile).toBeVisible();
    await profile.getByRole("button", { name: /Skip/i }).click();

    const modal = page.locator("#invite-modal");
    await expect(modal).toBeVisible();
    await expect(
      modal.getByRole("heading", { name: /Invitation link/i }),
    ).toBeVisible();

    const inviteInput = modal.locator("#invite-url");
    await expect(inviteInput).toHaveValue(/\/rooms\/invite\/[0-9a-f-]{36}$/);
  });

  test("mostra erro de verificação quando submete antes do Turnstile resolver", async ({
    page,
  }) => {
    // Bloqueia o api.js do Cloudflare para que o widget nunca renderize e
    // o input hidden `cf-turnstile-response` nunca exista. Assim o backend
    // recebe a submissão sem token e cai no flash de erro.
    await page.route("**/challenges.cloudflare.com/**", (route) => route.abort());

    await page.goto("/rooms/new");
    await page.getByRole("button", { name: /Create room/i }).click();

    // O controller chama render(:new) no caminho de erro, sem redirect, então
    // a URL fica em /rooms (alvo do POST) e o form é re-exibido com o flash.
    await expect(
      page.getByText(/Please complete the human verification before continuing\./i),
    ).toBeVisible();
    await expect(
      page.getByRole("heading", { name: /Start a new session/i }),
    ).toBeVisible();
  });
});
