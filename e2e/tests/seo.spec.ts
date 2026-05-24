import { test, expect } from "@playwright/test";

/**
 * Cobre o SEO técnico: metatags, dados estruturados, URLs por idioma,
 * sitemap e o `noindex` das páginas efêmeras de sala.
 */
test.describe("SEO", () => {
  test("a home expõe title, description, canonical, Open Graph e JSON-LD", async ({
    page,
  }) => {
    await page.goto("/");

    await expect(page).toHaveTitle("Lynx planning poker");

    const description = page.locator('head meta[name="description"]');
    await expect(description).toHaveCount(1);
    await expect(description).toHaveAttribute("content", /.+/);

    await expect(page.locator('head link[rel="canonical"]')).toHaveCount(1);
    await expect(page.locator('head meta[property="og:title"]')).toHaveCount(1);

    // A dedicated 1200x630 share image, surfaced as a large Twitter card.
    await expect(
      page.locator('head meta[property="og:image"]'),
    ).toHaveAttribute("content", /\/images\/og-image\.png$/);
    await expect(
      page.locator('head meta[name="twitter:card"]'),
    ).toHaveAttribute("content", "summary_large_image");

    await expect(
      page.locator('head script[type="application/ld+json"]'),
    ).not.toHaveCount(0);
  });

  test("a home explica o que é planning poker e por que usar o Lynx", async ({
    page,
  }) => {
    await page.goto("/");

    await expect(page.getByRole("heading", { level: 1 })).toHaveText(
      /planning poker/i,
    );
    await expect(
      page.getByRole("heading", { name: "What is planning poker?" }),
    ).toBeVisible();
    await expect(
      page.getByRole("heading", { name: /Why teams choose/i }),
    ).toBeVisible();
    await expect(
      page.getByRole("heading", { name: "Your data stays yours" }),
    ).toBeVisible();
  });

  test("a home exibe a faixa de confiança privacy-first no hero", async ({
    page,
  }) => {
    await page.goto("/");

    const strip = page.getByRole("list", {
      name: "Privacy and security highlights",
    });
    await expect(strip).toBeVisible();
    await expect(strip.getByText("Zero trackers")).toBeVisible();
    await expect(strip.getByText("Rooms auto-delete")).toBeVisible();
    // The data-protection badge is locale-aware: GDPR on the default (en)
    // locale, LGPD only on pt_BR.
    await expect(strip.getByText("GDPR", { exact: true })).toBeVisible();
  });

  test("a página /security descreve as proteções de infraestrutura", async ({
    page,
  }) => {
    await page.goto("/security");

    await expect(page.getByRole("heading", { level: 1 })).toHaveText(
      "Security",
    );
    await expect(
      page.getByRole("heading", { name: "Content Security Policy" }),
    ).toBeVisible();
    await expect(
      page.getByRole("heading", { name: "Responsible disclosure" }),
    ).toBeVisible();
  });

  test("o rodapé compartilhado liga para privacy, security e contato", async ({
    page,
  }) => {
    await page.goto("/");

    const footer = page.locator("footer");
    await expect(footer.getByRole("link", { name: "Privacy" })).toBeVisible();
    await expect(footer.getByRole("link", { name: "Security" })).toBeVisible();
    await expect(footer.getByRole("link", { name: "Contact" })).toBeVisible();
  });

  test("a home declara hreflang para os quatro idiomas", async ({ page }) => {
    await page.goto("/");

    for (const lang of ["pt-BR", "en", "fr", "es", "x-default"]) {
      await expect(
        page.locator(`head link[rel="alternate"][hreflang="${lang}"]`),
      ).toHaveCount(1);
    }
  });

  test("URLs com prefixo de idioma servem a página traduzida", async ({
    page,
  }) => {
    await page.goto("/fr/how-it-works");

    await expect(page.locator("html")).toHaveAttribute("lang", "fr");
    await expect(page.locator('head link[rel="canonical"]')).toHaveAttribute(
      "href",
      /\/fr\/how-it-works$/,
    );
  });

  test("a página de criar sala é noindex", async ({ page }) => {
    await page.goto("/rooms/new");

    await expect(page.locator('head meta[name="robots"]')).toHaveAttribute(
      "content",
      /noindex/,
    );
  });

  test("o sitemap.xml lista as páginas públicas", async ({ page }) => {
    const response = await page.goto("/sitemap.xml");

    expect(response?.status()).toBe(200);
    expect(response?.headers()["content-type"]).toContain("xml");

    const body = await response!.text();
    expect(body).toContain("<urlset");
    expect(body).toContain("/how-it-works");
    expect(body).toContain("/security");
    expect(body).toContain('hreflang="x-default"');
  });

  test("o robots.txt aponta para o sitemap", async ({ page }) => {
    const response = await page.goto("/robots.txt");

    expect(response?.status()).toBe(200);
    const body = await response!.text();
    expect(body).toContain("Sitemap:");
    expect(body).toContain("sitemap.xml");
  });
});
