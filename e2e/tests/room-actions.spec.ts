import { test, expect } from "@playwright/test";
import {
  createRoomAsHost,
  joinRoomAsGuest,
  dismissInviteModalIfOpen,
} from "../helpers/room";

test.describe("Ações da sala (Invite / Leave / End planning)", () => {
  test('botão "Invite" abre a modal com a URL de convite', async ({ page }) => {
    await createRoomAsHost(page, "Host Invite Btn");
    await dismissInviteModalIfOpen(page);

    await page.getByRole("button", { name: /^Invite$/i }).click();

    const modal = page.locator("#invite-modal");
    await expect(modal).toBeVisible();
    await expect(modal.locator("#invite-url")).toHaveValue(
      /\/rooms\/invite\/[0-9a-f-]{36}$/,
    );
  });

  test("host vê o botão End planning, guest vê o botão Leave", async ({ browser }) => {
    const hostContext = await browser.newContext();
    const hostPage = await hostContext.newPage();
    const roomUrl = await createRoomAsHost(hostPage, "Host Roles");
    await dismissInviteModalIfOpen(hostPage);

    await expect(
      hostPage.getByRole("button", { name: /End planning/i }),
    ).toBeVisible();
    await expect(hostPage.getByRole("button", { name: /^Leave$/i })).toHaveCount(0);

    const { page: guestPage, context: guestContext } = await joinRoomAsGuest(
      browser,
      roomUrl,
      "Guest Roles",
    );
    await expect(
      guestPage.getByRole("button", { name: /^Leave$/i }),
    ).toBeVisible();
    await expect(
      guestPage.getByRole("button", { name: /End planning/i }),
    ).toHaveCount(0);

    await guestContext.close();
    await hostContext.close();
  });

  test("guest clicando em Leave e confirmando volta para a home com mensagem", async ({
    browser,
  }) => {
    const hostContext = await browser.newContext();
    const hostPage = await hostContext.newPage();
    const roomUrl = await createRoomAsHost(hostPage, "Host Leave");
    await dismissInviteModalIfOpen(hostPage);

    const { page: guestPage, context: guestContext } = await joinRoomAsGuest(
      browser,
      roomUrl,
      "Guest Leave",
    );

    await guestPage.getByRole("button", { name: /^Leave$/i }).click();

    const confirmModal = guestPage.locator("#leave-confirm-modal");
    await expect(confirmModal).toBeVisible();
    await confirmModal.getByRole("button", { name: /^Yes$/i }).click();

    await expect(guestPage).toHaveURL(/\/$/);
    await expect(guestPage.getByText(/You left the room/i)).toBeVisible();

    await guestContext.close();
    await hostContext.close();
  });

  test("guest clicando em Leave e cancelando permanece na sala", async ({
    browser,
  }) => {
    const hostContext = await browser.newContext();
    const hostPage = await hostContext.newPage();
    const roomUrl = await createRoomAsHost(hostPage, "Host Cancel");
    await dismissInviteModalIfOpen(hostPage);

    const { page: guestPage, context: guestContext } = await joinRoomAsGuest(
      browser,
      roomUrl,
      "Guest Cancel",
    );

    await guestPage.getByRole("button", { name: /^Leave$/i }).click();

    const confirmModal = guestPage.locator("#leave-confirm-modal");
    await expect(confirmModal).toBeVisible();
    await confirmModal.getByRole("button", { name: /^No$/i }).click();

    await expect(confirmModal).toBeHidden();
    await expect(guestPage).toHaveURL(/\/rooms\/[0-9a-f-]{36}$/);

    await guestContext.close();
    await hostContext.close();
  });

  test("host clicando em End planning e confirmando fecha a sala e volta para a home", async ({
    page,
  }) => {
    const roomUrl = await createRoomAsHost(page, "Host End");
    await dismissInviteModalIfOpen(page);

    await page.getByRole("button", { name: /End planning/i }).click();

    const confirmModal = page.locator("#leave-confirm-modal");
    await expect(confirmModal).toBeVisible();
    await confirmModal.getByRole("button", { name: /^Yes$/i }).click();

    await expect(page).toHaveURL(/\/$/);

    // após o end, a sala não existe mais — acessá-la deve redirecionar com flash
    await page.goto(roomUrl);
    await expect(page).toHaveURL(/\/$/);
    await expect(
      page.getByText(/This room does not exist or has already ended/i),
    ).toBeVisible();
  });
});
