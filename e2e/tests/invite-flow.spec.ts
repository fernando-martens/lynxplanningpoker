import { test, expect } from "@playwright/test";
import {
  ensureEnglishLocale,
  createRoomAsHost,
  dismissInviteModalIfOpen,
} from "../helpers/room";

test.describe("Fluxo de convite (guest entra na sala)", () => {
  test("um convidado consegue entrar usando o link de convite", async ({
    browser,
  }) => {
    const hostContext = await browser.newContext();
    const hostPage = await hostContext.newPage();
    const roomUrl = await createRoomAsHost(hostPage, "Anfitriã");
    const roomId = roomUrl.match(/\/rooms\/([0-9a-f-]{36})$/)![1];
    await dismissInviteModalIfOpen(hostPage);

    const guestContext = await browser.newContext();
    const guestPage = await guestContext.newPage();
    await ensureEnglishLocale(guestPage);
    await guestPage.goto(`/rooms/invite/${roomId}`);

    await expect(
      guestPage.getByRole("heading", { name: /You're invited!/i }),
    ).toBeVisible();
    await guestPage.getByLabel(/Your name/i).fill("Convidada");
    await guestPage.getByRole("button", { name: /Join the room/i }).click();

    await expect(guestPage).toHaveURL(new RegExp(`/rooms/${roomId}$`));

    // o host deve enxergar o nome do convidado em tempo real
    await expect(hostPage.getByText("Convidada")).toBeVisible({ timeout: 10_000 });

    await hostContext.close();
    await guestContext.close();
  });

  test("acessar /rooms/invite/:id com id inexistente redireciona para a home com flash", async ({
    page,
  }) => {
    await ensureEnglishLocale(page);
    await page.goto("/rooms/invite/00000000-0000-0000-0000-000000000000");

    await expect(page).toHaveURL(/\/$/);
    await expect(
      page.getByText(/This room does not exist or has already ended/i),
    ).toBeVisible();
  });

  test("não submete o convite sem informar o nome", async ({ browser }) => {
    const hostContext = await browser.newContext();
    const hostPage = await hostContext.newPage();
    const roomUrl = await createRoomAsHost(hostPage, "Anfitriã 2");
    const roomId = roomUrl.match(/\/rooms\/([0-9a-f-]{36})$/)![1];

    const guestContext = await browser.newContext();
    const guestPage = await guestContext.newPage();
    await ensureEnglishLocale(guestPage);
    await guestPage.goto(`/rooms/invite/${roomId}`);
    await guestPage.getByRole("button", { name: /Join the room/i }).click();

    await expect(guestPage).toHaveURL(new RegExp(`/rooms/invite/${roomId}$`));

    await hostContext.close();
    await guestContext.close();
  });
});
