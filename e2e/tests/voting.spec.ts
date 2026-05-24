import { test, expect, Page, Locator } from "@playwright/test";
import { createRoomAsHost, dismissInviteModalIfOpen } from "../helpers/room";

const card = (page: Page, value: string): Locator =>
  page.getByRole("button", { name: value, exact: true });

test.describe("Votação", () => {
  test("clicar em uma carta marca a carta como selecionada", async ({ page }) => {
    await createRoomAsHost(page, "Votador");
    await dismissInviteModalIfOpen(page);

    const card5 = card(page, "5");
    await expect(card5).toBeVisible();
    await card5.click();

    await expect(card5).toHaveClass(/room-card--selected/);
  });

  test("clicar de novo na mesma carta desfaz o voto (toggle)", async ({ page }) => {
    await createRoomAsHost(page, "Votador Toggle");
    await dismissInviteModalIfOpen(page);

    const card8 = card(page, "8");
    await card8.click();
    await expect(card8).toHaveClass(/room-card--selected/);

    await card8.click();
    await expect(card8).not.toHaveClass(/room-card--selected/);
  });

  test("clicar em uma carta diferente troca a seleção", async ({ page }) => {
    await createRoomAsHost(page, "Trocador");
    await dismissInviteModalIfOpen(page);

    const card3 = card(page, "3");
    const card13 = card(page, "13");

    await card3.click();
    await expect(card3).toHaveClass(/room-card--selected/);

    await card13.click();
    await expect(card13).toHaveClass(/room-card--selected/);
    await expect(card3).not.toHaveClass(/room-card--selected/);
  });

  test('a carta "?" também é selecionável', async ({ page }) => {
    await createRoomAsHost(page, "Incerto");
    await dismissInviteModalIfOpen(page);

    const cardQ = card(page, "?");
    await cardQ.click();
    await expect(cardQ).toHaveClass(/room-card--selected/);
  });

  test("as 12 cartas (0, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, ?) estão visíveis", async ({
    page,
  }) => {
    await createRoomAsHost(page, "Lista de cartas");
    await dismissInviteModalIfOpen(page);

    const cards = page.locator("button.room-card");
    await expect(cards).toHaveCount(12);

    const expected = ["0", "1", "2", "3", "5", "8", "13", "21", "34", "55", "89", "?"];
    for (const value of expected) {
      await expect(card(page, value)).toBeVisible();
    }
  });
});
