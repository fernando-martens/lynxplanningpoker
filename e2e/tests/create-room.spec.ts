import { test, expect } from "@playwright/test";
import { ensureEnglishLocale, createRoomAsHost } from "../helpers/room";

test.describe("Criação de sala (host)", () => {
  test.beforeEach(async ({ page }) => {
    await ensureEnglishLocale(page);
  });

  test("exibe o formulário de criação com os campos esperados", async ({ page }) => {
    await page.goto("/rooms/new");

    await expect(
      page.getByRole("heading", { name: /Who are you\?/i }),
    ).toBeVisible();
    await expect(page.getByLabel(/Your name/i)).toBeVisible();
    await expect(page.getByLabel(/Verify you are human/i)).toBeVisible();
    await expect(
      page.getByRole("button", { name: /Join your room/i }),
    ).toBeVisible();
  });

  test("não submete o formulário sem nome (required)", async ({ page }) => {
    await page.goto("/rooms/new");
    await page.getByRole("button", { name: /Join your room/i }).click();

    // continua na mesma página por causa da validação HTML5
    await expect(page).toHaveURL(/\/rooms\/new$/);
  });

  test("cria uma sala e redireciona para /rooms/:id", async ({ page }) => {
    const roomUrl = await createRoomAsHost(page, "Host Tester");
    expect(roomUrl).toMatch(/\/rooms\/[0-9a-f-]{36}$/);
  });

  test("após criar a sala, exibe automaticamente a modal de convite para o host sozinho", async ({
    page,
  }) => {
    await createRoomAsHost(page, "Host Solo");

    const modal = page.locator("#invite-modal");
    await expect(modal).toBeVisible();
    await expect(
      modal.getByRole("heading", { name: /Invitation link/i }),
    ).toBeVisible();

    const inviteInput = modal.locator("#invite-url");
    await expect(inviteInput).toHaveValue(/\/rooms\/invite\/[0-9a-f-]{36}$/);
  });
});
