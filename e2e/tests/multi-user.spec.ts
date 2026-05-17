import { test, expect } from "@playwright/test";
import {
  ensureEnglishLocale,
  createRoomAsHost,
  joinRoomAsGuest,
  dismissInviteModalIfOpen,
  waitForLiveView,
} from "../helpers/room";

test.describe("Sincronização em tempo real entre múltiplos usuários", () => {
  test("o host vê o convidado entrando na sala", async ({ browser }) => {
    const hostContext = await browser.newContext();
    const hostPage = await hostContext.newPage();
    const roomUrl = await createRoomAsHost(hostPage, "Anfitrião");
    await dismissInviteModalIfOpen(hostPage);

    await expect(hostPage.getByText("Visitante")).toHaveCount(0);

    const { context: guestContext } = await joinRoomAsGuest(
      browser,
      roomUrl,
      "Visitante",
    );

    await expect(hostPage.getByText("Visitante")).toBeVisible({ timeout: 10_000 });

    await guestContext.close();
    await hostContext.close();
  });

  test("os votos do guest aparecem como avatar votado no host (sem revelar números)", async ({
    browser,
  }) => {
    const hostContext = await browser.newContext();
    const hostPage = await hostContext.newPage();
    const roomUrl = await createRoomAsHost(hostPage, "Host PubSub");
    await dismissInviteModalIfOpen(hostPage);

    const { page: guestPage, context: guestContext } = await joinRoomAsGuest(
      browser,
      roomUrl,
      "Guest PubSub",
    );
    await guestPage
      .getByRole('button', { name: '13' })
      .click();

    const guestAvatar = hostPage
      .locator(".room-user")
      .filter({ hasText: "Guest PubSub" })
      .locator(".room-user-avatar");

    await expect(guestAvatar).toHaveClass(/room-user-avatar--voted/, {
      timeout: 10_000,
    });
    await expect(hostPage.locator(".room-user-vote-num")).toHaveCount(0);

    await guestContext.close();
    await hostContext.close();
  });

  test("quando o host encerra a sala, o convidado é redirecionado para a home", async ({
    browser,
  }) => {
    const hostContext = await browser.newContext();
    const hostPage = await hostContext.newPage();
    const roomUrl = await createRoomAsHost(hostPage, "Host Encerra");
    await dismissInviteModalIfOpen(hostPage);

    const guestContext = await browser.newContext();
    const guestPage = await guestContext.newPage();
    const inviteUrl = roomUrl.replace(
      /\/rooms\/([0-9a-f-]{36})$/,
      "/rooms/invite/$1",
    );
    await ensureEnglishLocale(guestPage);
    await guestPage.goto(inviteUrl);
    await guestPage.getByLabel(/Your name/i).fill("Guest Despejado");
    await guestPage.getByRole("button", { name: /Join the room/i }).click();
    await expect(guestPage).toHaveURL(/\/rooms\/[0-9a-f-]{36}$/);
    await waitForLiveView(guestPage);

    // espera o host enxergar o guest antes de encerrar (garante sincronização)
    await expect(hostPage.getByText("Guest Despejado")).toBeVisible({
      timeout: 10_000,
    });

    await hostPage.getByRole("button", { name: /End planning/i }).click();

    await expect(guestPage).toHaveURL(/\/$/, { timeout: 10_000 });
    await expect(
      guestPage.getByText(/The room was ended by the host/i),
    ).toBeVisible();

    await guestContext.close();
    await hostContext.close();
  });
});
