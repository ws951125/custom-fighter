import { chromium } from 'playwright';

const baseUrl = process.env.CUSTOM_FIGHTER_WEB_URL ?? 'http://127.0.0.1:8000';
const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const pageErrors = [];

page.on('pageerror', (error) => pageErrors.push(error.message));
page.on('console', (message) => {
  if (message.type() === 'error') {
    console.error(`[browser console] ${message.text()}`);
  }
});

try {
  const response = await page.goto(baseUrl, {
    waitUntil: 'domcontentloaded',
    timeout: 60_000,
  });

  if (!response?.ok()) {
    throw new Error(`Web build returned HTTP ${response?.status() ?? 'unknown'}`);
  }

  await page.waitForFunction(
    () => document.documentElement.dataset.godotReady === 'true',
    null,
    { timeout: 60_000 },
  );

  await page.keyboard.press('j');
  await page.waitForTimeout(250);

  if (pageErrors.length > 0) {
    throw new Error(`Browser page errors: ${pageErrors.join(' | ')}`);
  }

  console.log('WEB_SMOKE_PASSED');
} finally {
  await browser.close();
}
