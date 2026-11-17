// Renders every page in src/ to a PNG beside this file, once for a light page and once for
// a dark one, as GitHub picks between them with <picture>. A page whose <body> has
// data-variants="single" is rendered once, as it is drawn.
//
//   pnpm install --frozen-lockfile && pnpm build
//
// Chromium comes from Playwright (`pnpm exec playwright install chromium`), or from
// $CHROMIUM when that is set.
import { readdir } from "node:fs/promises";
import { fileURLToPath, pathToFileURL } from "node:url";
import { dirname, join, basename } from "node:path";
import { chromium } from "playwright";

const here = dirname(fileURLToPath(import.meta.url));
const only = process.argv.slice(2);
const pages = (await readdir(join(here, "src")))
  .filter((f) => f.endsWith(".html"))
  .filter((f) => only.length === 0 || only.includes(basename(f, ".html")))
  .sort();

const browser = await chromium.launch(process.env.CHROMIUM ? { executablePath: process.env.CHROMIUM } : {});
for (const file of pages) {
  const name = basename(file, ".html");
  for (const scheme of ["light", "dark"]) {
    const page = await browser.newPage({ deviceScaleFactor: 2, viewport: { width: 1400, height: 900 } });
    await page.emulateMedia({ colorScheme: scheme });
    await page.goto(pathToFileURL(join(here, "src", file)).href);
    await page.waitForSelector("body[data-ready]");
    const single = (await page.getAttribute("body", "data-variants")) === "single";
    if (single && scheme === "dark") { await page.close(); break; }
    const out = join(here, single || scheme === "light" ? `${name}.png` : `${name}-dark.png`);
    await page.locator("#frame").screenshot({ path: out, omitBackground: true });
    console.log(`assets: ${basename(out)}`);
    await page.close();
  }
}
await browser.close();
