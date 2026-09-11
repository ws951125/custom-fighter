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

  const initialHp = Number(
    await page.evaluate(() => document.documentElement.dataset.dummyHp),
  );
  if (initialHp !== 100) {
    throw new Error(`Unexpected initial dummy HP: ${initialHp}`);
  }

  await page.keyboard.down('d');
  await page.waitForTimeout(1_450);
  await page.keyboard.up('d');
  await page.keyboard.press('j');

  await page.waitForFunction(
    () => Number(document.documentElement.dataset.dummyHp) < 100,
    null,
    { timeout: 5_000 },
  );

  const hpAfterHit = Number(
    await page.evaluate(() => document.documentElement.dataset.dummyHp),
  );
  if (hpAfterHit !== 80) {
    throw new Error(`Expected one 20-damage hit; dummy HP is ${hpAfterHit}`);
  }

  if (pageErrors.length > 0) {
    throw new Error(`Browser page errors: ${pageErrors.join(' | ')}`);
  }

  console.log(`WEB_COMBAT_SMOKE_PASSED dummyHp=${hpAfterHit}`);
} finally {
  await browser.close();
}
