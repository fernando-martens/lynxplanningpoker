import { test, expect } from "@playwright/test";
import {
  ensureEnglishLocale,
  createRoomAsHost,
  joinRoomAsGuest,
} from "../helpers/room";

test.describe("Fluxo de convite (guest entra na sala)", () => {
  test("um convidado consegue entrar usando o link de convite", async ({
    browser,
  }) => {
    const hostContext = await browser.newContext();
    const hostPage = await hostContext.newPage();
    const roomUrl = await createRoomAsHost(hostPage, "Anfitriã");

    const { context: guestContext } = await joinRoomAsGuest(
      browser,
      roomUrl,
      "Convidada",
    );

    // o host deve enxergar o nome do convidado em tempo real
    // escopa para .room-scene porque o #stats-modal (oculto) também lista os participantes
    await expect(
      hostPage.locator(".room-scene").getByText("Convidada"),
    ).toBeVisible({ timeout: 10_000 });

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

  test("o convite entra na sala com um clique (nome temporário gerado)", async ({
    browser,
  }) => {
    const hostContext = await browser.newContext();
    const hostPage = await hostContext.newPage();
    const roomUrl = await createRoomAsHost(hostPage, "Anfitriã 2");
    const roomId = roomUrl.match(/\/rooms\/([0-9a-f-]{36})$/)![1];

    const guestContext = await browser.newContext();
    const guestPage = await guestContext.newPage();
    await ensureEnglishLocale(guestPage);
    await guestPage.goto(`/rooms/invite/${roomId}`);
    // Sem campo de nome: basta clicar em Join para entrar.
    await guestPage.getByRole("button", { name: /Join the room/i }).click();

    await expect(guestPage).toHaveURL(new RegExp(`/rooms/${roomId}$`));

    await hostContext.close();
    await guestContext.close();
  });
});
