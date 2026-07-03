import { test, expect } from "@playwright/test";
import {
  ensureEnglishLocale,
  createRoomAsHost,
  joinRoomAsGuest,
  waitForLiveView,
  dismissInviteModalIfOpen,
} from "../helpers/room";

test.describe("Onboarding de nome (nome temporário + prompt na sala)", () => {
  test.beforeEach(async ({ page }) => {
    await ensureEnglishLocale(page);
  });

  test("o host define o próprio nome pelo prompt e o card atualiza", async ({
    page,
  }) => {
    // `createRoomAsHost` já usa o prompt para definir o nome e fecha o modal.
    await createRoomAsHost(page, "Alice");

    // O card do próprio host exibe o nome escolhido.
    await expect(
      page.locator(".room-scene").getByText("Alice"),
    ).toBeVisible();

    // Reabrir o perfil pelo header e mudar de novo funciona; dar Enter salva
    // e fecha o modal automaticamente.
    await page.getByRole("button", { name: /Your profile/i }).click();
    const modal = page.locator("#profile-modal");
    await expect(modal).toBeVisible();
    const input = modal.getByLabel(/Your name/i);
    await input.fill("Alice II");
    await input.press("Enter");

    await expect(modal).toBeHidden();
    await expect(
      page.locator(".room-scene").getByText("Alice II"),
    ).toBeVisible({ timeout: 10_000 });
  });

  test("o novo nome do host aparece para o convidado em tempo real", async ({
    browser,
  }) => {
    const hostContext = await browser.newContext();
    const hostPage = await hostContext.newPage();
    const roomUrl = await createRoomAsHost(hostPage, "Host Sync");

    const { page: guestPage, context: guestContext } = await joinRoomAsGuest(
      browser,
      roomUrl,
      "Convidado Sync",
    );

    // O guest enxerga o nome inicial do host.
    await expect(
      guestPage.locator(".room-scene").getByText("Host Sync"),
    ).toBeVisible({ timeout: 10_000 });

    // Host renomeia via header.
    await hostPage.getByRole("button", { name: /Your profile/i }).click();
    const modal = hostPage.locator("#profile-modal");
    await expect(modal).toBeVisible();
    await modal.getByLabel(/Your name/i).fill("Host Novo");
    await modal.getByRole("button", { name: /^Save$/i }).click();

    // O broadcast via PubSub propaga o novo nome ao guest sem refresh.
    await expect(
      guestPage.locator(".room-scene").getByText("Host Novo"),
    ).toBeVisible({ timeout: 10_000 });

    await hostContext.close();
    await guestContext.close();
  });

  test("o host pula o prompt e mantém o nome temporário", async ({ page }) => {
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

    const modal = page.locator("#profile-modal");
    await expect(modal).toBeVisible();

    // O input já vem focado e com todo o texto selecionado, para trocar o nome
    // temporário com uma única digitação.
    await expect
      .poll(() =>
        page.evaluate(() => {
          const el = document.getElementById(
            "rename-name-input",
          ) as HTMLInputElement | null;
          if (!el) return null;
          return {
            focused: document.activeElement === el,
            selectedAll:
              el.selectionStart === 0 &&
              el.selectionEnd === el.value.length &&
              el.value.length > 0,
          };
        }),
      )
      .toEqual({ focused: true, selectedAll: true });

    // Captura o nome temporário exibido no card antes de pular.
    const tempName = (
      await page.locator(".room-scene .room-user-name").first().innerText()
    ).trim();
    expect(tempName.length).toBeGreaterThan(0);

    await modal.getByRole("button", { name: /Skip/i }).click();
    await expect(modal).toBeHidden();

    // O nome temporário persiste no card do host.
    await expect(
      page.locator(".room-scene").getByText(tempName),
    ).toBeVisible();

    // Ao pular, o host sozinho vê a modal de convite — fechamos antes de seguir.
    await dismissInviteModalIfOpen(page);

    // Reabrir o perfil e renomear ainda funciona após o skip.
    await page.getByRole("button", { name: /Your profile/i }).click();
    await expect(modal).toBeVisible();
    await modal.getByLabel(/Your name/i).fill("Depois do Skip");
    await modal.getByRole("button", { name: /^Save$/i }).click();
    await expect(
      page.locator(".room-scene").getByText("Depois do Skip"),
    ).toBeVisible({ timeout: 10_000 });
  });
});
