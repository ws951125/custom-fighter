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

async function approachDummy(maxGap = 105) {
  let currentX = await readNumber('playerX');
  let currentDummyX = await readNumber('dummyX');
  for (let step = 0; step < 45 && currentDummyX - currentX > maxGap; step += 1) {
    await page.keyboard.down('d');
    await page.waitForTimeout(55);
    await page.keyboard.up('d');
    await page.waitForTimeout(25);
    currentX = await readNumber('playerX');
    currentDummyX = await readNumber('dummyX');
  }
  if (currentDummyX - currentX > 125 || currentDummyX - currentX < 20) {
    throw new Error(`Failed to approach attack range: playerX=${currentX} dummyX=${currentDummyX}`);
  }
  return { currentX, currentDummyX };
}

try {
  const startupStartedAt = Date.now();
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

  const startupMs = Date.now() - startupStartedAt;
  const resourceTiming = await page.evaluate(() =>
    performance
      .getEntriesByType('resource')
      .filter((entry) => entry.name.endsWith('.wasm') || entry.name.endsWith('.pck'))
      .map((entry) => ({
        name: entry.name.split('/').pop(),
        duration: Math.round(entry.duration),
        transferSize: entry.transferSize ?? 0,
        decodedBodySize: entry.decodedBodySize ?? 0,
      })),
  );
  console.log(`WEB_STARTUP_TIMING ms=${startupMs} resources=${JSON.stringify(resourceTiming)}`);

  const serviceWorkerReady = await page.evaluate(async () => {
    if (!('serviceWorker' in navigator)) return false;
    try {
      const registration = await Promise.race([
        navigator.serviceWorker.ready,
        new Promise((resolve) => setTimeout(() => resolve(null), 5000)),
      ]);
      return Boolean(registration?.active);
    } catch {
      return false;
    }
  });
  if (!serviceWorkerReady) {
    throw new Error('PWA service worker did not become ready');
  }
  console.log('PWA_SERVICE_WORKER_READY');

  const initialHp = await readNumber('dummyHp');
  const initialX = await readNumber('playerX');
  const initialDummyX = await readNumber('dummyX');
  if (initialHp !== 100 || !Number.isFinite(initialX) || !Number.isFinite(initialDummyX)) {
    throw new Error(`Unexpected initial state: hp=${initialHp} playerX=${initialX} dummyX=${initialDummyX}`);
  }

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

  await approachDummy();

  const comboExpectations = [
    { step: 1, hp: 88, waitAfterMs: 180 },
    { step: 2, hp: 74, waitAfterMs: 200 },
    { step: 3, hp: 54, waitAfterMs: 100 },
  ];

  for (const expected of comboExpectations) {
    await page.keyboard.press('j');
    await page.waitForFunction(
      ({ step, hp }) =>
        Number(document.documentElement.dataset.lastHitStep) === step &&
        Number(document.documentElement.dataset.dummyHp) === hp &&
        document.documentElement.dataset.lastAttackHit === 'true',
      expected,
      { timeout: 3_000 },
    );
    const observedComboStep = await readNumber('comboStep');
    if (observedComboStep !== expected.step) {
      throw new Error(`Expected combo step ${expected.step}; observed ${observedComboStep}`);
    }
    await page.waitForTimeout(expected.waitAfterMs);
  }

  await page.waitForFunction(
    () => document.documentElement.dataset.dummyRecoveryState === 'DOWN',
    null,
    { timeout: 2_000 },
  );
  if (await readText('dummyCanBeHit') !== 'false') {
    throw new Error('Downed dummy must not be hittable');
  }

  await page.waitForFunction(
    () => document.documentElement.dataset.dummyRecoveryState === 'RECOVERING',
    null,
    { timeout: 2_000 },
  );
  await page.waitForFunction(
    () => document.documentElement.dataset.dummyRecoveryState === 'INVULNERABLE',
    null,
    { timeout: 2_000 },
  );
  if (await readText('dummyInvulnerable') !== 'true') {
    throw new Error('Standing recovery protection must be invulnerable');
  }

  await page.waitForFunction(
    () => document.documentElement.dataset.dummyRecoveryState === 'READY',
    null,
    { timeout: 3_000 },
  );
  if (await readText('dummyCanBeHit') !== 'true') {
    throw new Error('Recovered dummy must become hittable');
  }

  const hpAfterCombo = await readNumber('dummyHp');
  const dummyXAfterCombo = await readNumber('dummyX');
  if (hpAfterCombo !== 54) {
    throw new Error(`Expected three-hit combo to leave 54 HP; dummy HP is ${hpAfterCombo}`);
  }
  if (!(dummyXAfterCombo > initialDummyX + 20)) {
    throw new Error(`Expected visible knockback: initialDummyX=${initialDummyX} afterCombo=${dummyXAfterCombo}`);
  }

  await approachDummy();
  await page.keyboard.press('j');
  await page.waitForFunction(
    () => Number(document.documentElement.dataset.dummyHp) === 42,
    null,
    { timeout: 3_000 },
  );

  const hpAfterRecoveryHit = await readNumber('dummyHp');
  const finalState = await readText('playerState');
  if (hpAfterRecoveryHit !== 42) {
    throw new Error(`Expected first post-recovery hit to leave 42 HP; got ${hpAfterRecoveryHit}`);
  }

  if (pageErrors.length > 0 || consoleErrors.length > 0) {
    throw new Error(
      `Browser errors detected. pageErrors=${pageErrors.join(' | ')} consoleErrors=${consoleErrors.join(' | ')}`,
    );
  }

  console.log(
    `WEB_KNOCKDOWN_SMOKE_PASSED startupMs=${startupMs} initialX=${initialX} afterDash=${afterDashX} hpAfterCombo=${hpAfterCombo} hpAfterRecoveryHit=${hpAfterRecoveryHit} dummyX=${dummyXAfterCombo} finalState=${finalState}`,
  );
} finally {
  await browser.close();
}
