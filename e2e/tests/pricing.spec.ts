import { test, expect } from "@playwright/test";
import { ensureEnglishLocale } from "../helpers/room";

test.describe("Página de pricing", () => {
  test.beforeEach(async ({ page }) => {
    await ensureEnglishLocale(page);
  });

  test("renderiza os dois planos e enfatiza o gratuito", async ({ page }) => {
    await page.goto("/pricing");

    await expect(
      page.getByRole("heading", { name: /Plans and pricing/i }),
    ).toBeVisible();

    await expect(
      page.getByRole("heading", { name: /Free forever/i }),
    ).toBeVisible();
    await expect(page.getByText(/Available today/i)).toBeVisible();
    await expect(
      page.getByRole("link", { name: /Create a room/i }),
    ).toBeVisible();

    await expect(
      page.getByRole("heading", { name: /^Premium$/i }),
    ).toBeVisible();
    await expect(page.getByText(/On the roadmap/i)).toBeVisible();
    await expect(
      page.getByRole("button", { name: /Not available yet/i }),
    ).toBeDisabled();
  });

  test("link de Pricing no header navega para /pricing", async ({ page }) => {
    await page.goto("/");
    await page.getByRole("link", { name: /Pricing/i }).first().click();
    await expect(page).toHaveURL(/\/pricing$/);
  });
});
