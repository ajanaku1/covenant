// Records the authoring flow on the live app: type the agreement, click "Read it", show the scaffold.
import { chromium } from "playwright";

const CLAUSE =
  "Pay the freelancer 200 USDC when the site at https://acme.build is live and mentions Somnia. Check daily for 7 days. Refund me if it isn't met by the deadline.";

const browser = await chromium.launch();
const ctx = await browser.newContext({
  viewport: { width: 1920, height: 1080 },
  recordVideo: { dir: "rec", size: { width: 1920, height: 1080 } },
});
const page = await ctx.newPage();
await page.goto("https://covenant-beta.vercel.app", { waitUntil: "networkidle" });
await page.waitForTimeout(1500);

const box = page.locator("textarea").first();
await box.click();
await box.fill("");
await page.waitForTimeout(400);
// Human-ish typing
for (const ch of CLAUSE) {
  await box.type(ch, { delay: 0 });
  await page.waitForTimeout(18 + Math.floor((ch.charCodeAt(0) % 5) * 6));
}
await page.waitForTimeout(900);

const btn = page.getByRole("button", { name: /read it/i });
await btn.hover();
await page.waitForTimeout(500);
await btn.click();
await page.waitForTimeout(2500);

// Scroll to whatever appeared (scaffold confirm / watch preview)
await page.mouse.wheel(0, 450);
await page.waitForTimeout(2200);
await page.mouse.wheel(0, 450);
await page.waitForTimeout(2600);

await ctx.close();
await browser.close();
console.log("done");
