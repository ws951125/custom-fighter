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
  const initialDummyX = await readNumber('dummyX');
  if (initialHp !== 100 || !Number.isFinite(initialX) || !Number.isFinite(initialDummyX)) {
    throw new Error(`Unexpected initial state: hp=${initialHp} playerX=${initialX} dummyX=${initialDummyX}`);
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

  // Walk close enough that all three explicit hitboxes overlap the dummy hurtbox.
  let currentX = afterDashX;
  let currentDummyX = await readNumber('dummyX');
  for (let step = 0; step < 40 && currentDummyX - currentX > 105; step += 1) {
    await page.keyboard.down('d');
    await page.waitForTimeout(55);
    await page.keyboard.up('d');
    await page.waitForTimeout(25);
    currentX = await readNumber('playerX');
    currentDummyX = await readNumber('dummyX');
  }

  if (currentDummyX - currentX > 125 || currentDummyX - currentX < 20) {
    throw new Error(`Failed to approach combo range: playerX=${currentX} dummyX=${currentDummyX}`);
  }

  const comboExpectations = [
    { step: 1, hp: 88, waitAfterMs: 180 },
    { step: 2, hp: 74, waitAfterMs: 200 },
    { step: 3, hp: 54, waitAfterMs: 260 },
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

  const hpAfterCombo = await readNumber('dummyHp');
  const dummyXAfterCombo = await readNumber('dummyX');
  const finalState = await readText('playerState');

  if (hpAfterCombo !== 54) {
    throw new Error(`Expected three-hit combo to leave 54 HP; dummy HP is ${hpAfterCombo}`);
  }
  if (!(dummyXAfterCombo > initialDummyX + 20)) {
    throw new Error(`Expected visible knockback: initialDummyX=${initialDummyX} afterCombo=${dummyXAfterCombo}`);
  }

  if (pageErrors.length > 0 || consoleErrors.length > 0) {
    throw new Error(
      `Browser errors detected. pageErrors=${pageErrors.join(' | ')} consoleErrors=${consoleErrors.join(' | ')}`,
    );
  }

  console.log(
    `WEB_COMBO_SMOKE_PASSED initialX=${initialX} afterDash=${afterDashX} dummyHp=${hpAfterCombo} dummyX=${dummyXAfterCombo} finalState=${finalState}`,
  );
} finally {
  await browser.close();
}
