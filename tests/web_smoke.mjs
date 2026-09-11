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

async function readNumber(datasetKey) {
  return Number(await page.evaluate((key) => document.documentElement.dataset[key], datasetKey));
}

async function readText(datasetKey) {
  return String(await page.evaluate((key) => document.documentElement.dataset[key] ?? '', datasetKey));
}

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
      playerState: document.documentElement.dataset.playerState ?? null,
      statusText: document.querySelector('#status-notice')?.textContent?.trim() ?? null,
      statusHtml: document.querySelector('#status')?.innerHTML?.slice(0, 2000) ?? null,
      crossOriginIsolated: globalThis.crossOriginIsolated ?? null,
      isSecureContext: globalThis.isSecureContext ?? null,
      userAgent: navigator.userAgent,
    }));
    console.error(`[startup diagnostic] ${JSON.stringify(diagnostic)}`);
    throw error;
  }

  const initialHp = await readNumber('dummyHp');
  const initialX = await readNumber('playerX');
  if (initialHp !== 100 || !Number.isFinite(initialX)) {
    throw new Error(`Unexpected initial state: hp=${initialHp} playerX=${initialX}`);
  }

  // Guard should become observable and return to READY when released.
  await page.keyboard.down('l');
  await page.waitForFunction(
    () => document.documentElement.dataset.playerGuarding === 'true',
    null,
    { timeout: 2_000 },
  );
  await page.keyboard.up('l');
  await page.waitForFunction(
    () => document.documentElement.dataset.playerGuarding === 'false',
    null,
    { timeout: 2_000 },
  );

  // Jump should produce a positive vertical arc and land again.
  await page.keyboard.press('Space');
  await page.waitForFunction(
    () => document.documentElement.dataset.playerJumping === 'true',
    null,
    { timeout: 2_000 },
  );
  await page.waitForFunction(
    () => Number(document.documentElement.dataset.playerJumpOffset) > 5,
    null,
    { timeout: 2_000 },
  );
  await page.waitForFunction(
    () => document.documentElement.dataset.playerJumping === 'false',
    null,
    { timeout: 2_000 },
  );

  // Run briefly to verify the modifier is wired through the real input layer.
  await page.keyboard.down('Shift');
  await page.keyboard.down('d');
  await page.waitForFunction(
    () => document.documentElement.dataset.playerRunning === 'true',
    null,
    { timeout: 2_000 },
  );
  await page.waitForTimeout(180);
  await page.keyboard.up('d');
  await page.keyboard.up('Shift');
  await page.waitForFunction(
    () => document.documentElement.dataset.playerRunning === 'false',
    null,
    { timeout: 2_000 },
  );
  const afterRunX = await readNumber('playerX');
  if (!(afterRunX > initialX + 40)) {
    throw new Error(`Run did not move far enough: initial=${initialX} afterRun=${afterRunX}`);
  }

  // Dash should cover a noticeable burst distance and respect the real animation state.
  await page.keyboard.press('k');
  await page.waitForFunction(
    () => document.documentElement.dataset.playerDashing === 'true',
    null,
    { timeout: 2_000 },
  );
  await page.waitForFunction(
    () => document.documentElement.dataset.playerDashing === 'false',
    null,
    { timeout: 2_000 },
  );
  const afterDashX = await readNumber('playerX');
  if (!(afterDashX > afterRunX + 120)) {
    throw new Error(`Dash distance too small: before=${afterRunX} after=${afterDashX}`);
  }

  // Walk into a safe attack range without relying on frame-exact timing.
  let currentX = afterDashX;
  for (let step = 0; step < 30 && currentX < 750; step += 1) {
    await page.keyboard.down('d');
    await page.waitForTimeout(70);
    await page.keyboard.up('d');
    await page.waitForTimeout(30);
    currentX = await readNumber('playerX');
  }

  if (currentX < 730 || currentX > 860) {
    throw new Error(`Failed to approach dummy safely: playerX=${currentX}`);
  }

  await page.keyboard.press('j');
  await page.waitForFunction(
    () => Number(document.documentElement.dataset.dummyHp) < 100,
    null,
    { timeout: 5_000 },
  );

  const hpAfterHit = await readNumber('dummyHp');
  const finalState = await readText('playerState');
  if (hpAfterHit !== 80) {
    throw new Error(`Expected one 20-damage hit; dummy HP is ${hpAfterHit}`);
  }

  if (pageErrors.length > 0 || consoleErrors.length > 0) {
    throw new Error(
      `Browser errors detected. pageErrors=${pageErrors.join(' | ')} consoleErrors=${consoleErrors.join(' | ')}`,
    );
  }

  console.log(
    `WEB_MOVEMENT_COMBAT_SMOKE_PASSED initialX=${initialX} afterRun=${afterRunX} afterDash=${afterDashX} dummyHp=${hpAfterHit} finalState=${finalState}`,
  );
} finally {
  await browser.close();
}
