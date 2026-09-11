import { chromium } from 'playwright';

const baseUrl = process.env.CUSTOM_FIGHTER_WEB_URL ?? 'http://127.0.0.1:8000';
const browserChannel = process.env.BROWSER_CHANNEL?.trim();
const launchOptions = { headless: true };
if (browserChannel) {
  launchOptions.channel = browserChannel;
}

console.log(`SMOKE_BROWSER=${browserChannel || 'playwright-chromium'}`);
console.log(`SMOKE_URL=${baseUrl}`);

const browser = await chromium.launch(launchOptions);
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const pageErrors = [];
const consoleErrors = [];

page.on('pageerror', (error) => {
  const detail = error?.stack || error?.message || String(error);
  pageErrors.push(detail);
  console.error(`[pageerror] ${detail}`);
});
page.on('console', (message) => {
  const line = `[browser ${message.type()}] ${message.text()}`;
  console.log(line);
  if (message.type() === 'error') {
    consoleErrors.push(message.text());
  }
});
page.on('requestfailed', (request) => {
  console.error(`[requestfailed] ${request.url()} :: ${request.failure()?.errorText ?? 'unknown'}`);
});

try {
  const response = await page.goto(baseUrl, {
    waitUntil: 'domcontentloaded',
    timeout: 60_000,
  });

  if (!response?.ok()) {
    throw new Error(`Web build returned HTTP ${response?.status() ?? 'unknown'}`);
  }

  try {
    await page.waitForFunction(
      () => document.documentElement.dataset.godotReady === 'true',
      null,
      { timeout: 60_000 },
    );
  } catch (error) {
    const diagnostic = await page.evaluate(() => ({
      godotReady: document.documentElement.dataset.godotReady ?? null,
      dummyHp: document.documentElement.dataset.dummyHp ?? null,
      statusText: document.querySelector('#status-notice')?.textContent?.trim() ?? null,
      statusHtml: document.querySelector('#status')?.innerHTML?.slice(0, 2000) ?? null,
      crossOriginIsolated: globalThis.crossOriginIsolated ?? null,
      isSecureContext: globalThis.isSecureContext ?? null,
      userAgent: navigator.userAgent,
    }));
    console.error(`[startup diagnostic] ${JSON.stringify(diagnostic)}`);
    throw error;
  }

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

  if (pageErrors.length > 0 || consoleErrors.length > 0) {
    throw new Error(
      `Browser errors detected. pageErrors=${pageErrors.join(' | ')} consoleErrors=${consoleErrors.join(' | ')}`,
    );
  }

  console.log(`WEB_COMBAT_SMOKE_PASSED dummyHp=${hpAfterHit}`);
} finally {
  await browser.close();
}
