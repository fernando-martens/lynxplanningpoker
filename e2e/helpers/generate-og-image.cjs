// Renders the social share image (Open Graph / Twitter card).
//
// Source layout:  app/priv/og_image/og-image.html
// Output (PNG):   app/priv/static/images/og-image.png  (1200x630)
//
// Run from the e2e/ directory so Playwright resolves:
//   node helpers/generate-og-image.cjs
//
// Re-run whenever the og-image.html design or the lynx mascot changes.

const path = require("path");
const { chromium } = require("playwright");

const appRoot = path.resolve(__dirname, "..", "..", "app");
const htmlPath = path.join(appRoot, "priv", "og_image", "og-image.html");
const outPath = path.join(appRoot, "priv", "static", "images", "og-image.png");

const WIDTH = 1200;
const HEIGHT = 630;

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({
    viewport: { width: WIDTH, height: HEIGHT },
    deviceScaleFactor: 1,
  });

  await page.goto("file://" + htmlPath.replace(/\\/g, "/"));
  await page.evaluate(() => document.fonts.ready);
  await page.waitForTimeout(300);

  await page.screenshot({
    path: outPath,
    clip: { x: 0, y: 0, width: WIDTH, height: HEIGHT },
  });

  await browser.close();
  console.log("Wrote " + outPath);
})();
