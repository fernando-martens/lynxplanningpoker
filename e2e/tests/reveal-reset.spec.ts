import { test, expect, Page, Locator } from "@playwright/test";
import {
  createRoomAsHost,
  joinRoomAsGuest,
  dismissInviteModalIfOpen,
} from "../helpers/room";

const card = (page: Page, value: string): Locator =>
  page.getByRole("button", { name: value, exact: true });

test.describe("Revelar e reiniciar votação", () => {
  test("clicando em Reveal os votos numéricos aparecem e a média é mostrada", async ({
    browser,
  }) => {
    const hostContext = await browser.newContext();
    const hostPage = await hostContext.newPage();
    const roomUrl = await createRoomAsHost(hostPage, "Host Reveal");
    await dismissInviteModalIfOpen(hostPage);

    const { page: guestPage, context: guestContext } = await joinRoomAsGuest(
      browser,
      roomUrl,
      "Convidado A",
    );

    // host vota 5, guest vota 8 -> média esperada 6.5
    await card(hostPage, "5").click();
    await card(guestPage, "8").click();

    await hostPage.getByRole("button", { name: /^Reveal$/i }).click();

    await expect(hostPage.getByText(/^Average$/i)).toBeVisible();
    await expect(hostPage.locator(".room-average-value")).toHaveText("6.5");

    await expect(hostPage.locator(".room-user-vote-num").first()).toBeVisible();

    await guestContext.close();
    await hostContext.close();
  });

  test('clicando em "Restart" os votos são limpos e o botão Reveal volta', async ({
    page,
  }) => {
    await createRoomAsHost(page, "Host Reset");
    await dismissInviteModalIfOpen(page);

    const card5 = card(page, "5");
    await card5.click();
    await expect(card5).toHaveClass(/room-card--selected/);

    await page.getByRole("button", { name: /^Reveal$/i }).click();
    await expect(page.getByText(/^Average$/i)).toBeVisible();

    await page.getByRole("button", { name: /Restart/i }).click();

    await expect(page.getByRole("button", { name: /^Reveal$/i })).toBeVisible();
    await expect(card5).not.toHaveClass(/room-card--selected/);
  });

  test("alterar voto depois do reveal mostra badge de edição", async ({ browser }) => {
    const hostContext = await browser.newContext();
    const hostPage = await hostContext.newPage();
    const roomUrl = await createRoomAsHost(hostPage, "Host Edit");
    await dismissInviteModalIfOpen(hostPage);

    const { page: guestPage, context: guestContext } = await joinRoomAsGuest(
      browser,
      roomUrl,
      "Convidado B",
    );

    await card(hostPage, "3").click();
    await card(guestPage, "5").click();

    await hostPage.getByRole("button", { name: /^Reveal$/i }).click();
    await expect(hostPage.getByText(/^Average$/i)).toBeVisible();

    // guest muda voto depois do reveal
    await card(guestPage, "13").click();

    await expect(hostPage.locator(".room-user-edit-badge").first()).toBeVisible({
      timeout: 10_000,
    });

    await guestContext.close();
    await hostContext.close();
  });
});
