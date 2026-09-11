import { chromium } from 'playwright';

const baseUrl = process.env.CUSTOM_FIGHTER_WEB_URL ?? 'http://127.0.0.1:8000';
const browserChannel = process.env.BROWSER_CHANNEL?.trim();
const launchOptions = { headless: true };
if (browserChannel) launchOptions.channel = browserChannel;

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
  console.log(`[browser ${message.type()}] ${message.text()}`);
  if (message.type() === 'error') consoleErrors.push(message.text());
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

async function nudge(key, holdMs = 45) {
  await page.keyboard.down(key);
  await page.waitForTimeout(holdMs);
  await page.keyboard.up(key);
  await page.waitForTimeout(25);
}

async function approachDummy(minGap = 50, maxGap = 105) {
  let currentX = await readNumber('playerX');
  let currentDummyX = await readNumber('dummyX');

  for (let step = 0; step < 60; step += 1) {
    const gap = currentDummyX - currentX;
    if (gap >= minGap && gap <= maxGap) break;
    await nudge(gap > maxGap ? 'd' : 'a');
    currentX = await readNumber('playerX');
    currentDummyX = await readNumber('dummyX');
  }

  const finalGap = currentDummyX - currentX;
  if (finalGap < minGap || finalGap > maxGap) {
    throw new Error(
      `Failed to stabilize attack range: playerX=${currentX} dummyX=${currentDummyX} gap=${finalGap}`,
    );
  }
  return { currentX, currentDummyX, gap: finalGap };
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
      skillLoaded: document.documentElement.dataset.skillLoaded ?? null,
      skillPhase: document.documentElement.dataset.skillPhase ?? null,
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
  if (!serviceWorkerReady) throw new Error('PWA service worker did not become ready');
  console.log('PWA_SERVICE_WORKER_READY');

  const initialHp = await readNumber('dummyHp');
  const initialX = await readNumber('playerX');
  const initialDummyX = await readNumber('dummyX');
  const initialMp = await readNumber('playerMp');
  if (
    initialHp !== 100 ||
    initialMp !== 100 ||
    !Number.isFinite(initialX) ||
    !Number.isFinite(initialDummyX) ||
    (await readText('skillLoaded')) !== 'true' ||
    (await readText('skillId')) !== 'fireball_001'
  ) {
    throw new Error(
      `Unexpected initial state: hp=${initialHp} mp=${initialMp} playerX=${initialX} dummyX=${initialDummyX} skillLoaded=${await readText('skillLoaded')} skillId=${await readText('skillId')}`,
    );
  }

  // M2 browser evidence deliberately relies on persistent outcomes rather than trying to
  // catch the 220 ms STARTUP phase. Exact startup/active/recovery timing is covered by
  // domain tests; the browser test proves the real input, resource spend, travel, hit and cooldown.
  await page.keyboard.press('u');
  await page.waitForFunction(
    () => Number(document.documentElement.dataset.playerMp) === 75,
    null,
    { timeout: 3_000 },
  );

  const cooldownAfterCast = await readNumber('skillCooldown');
  if (!(cooldownAfterCast > 0)) {
    throw new Error(`Expected fireball cooldown immediately after cast; got ${cooldownAfterCast}`);
  }

  // A second input while the first cast/cooldown is active must not spend another 25 MP.
  await page.keyboard.press('u');
  await page.waitForTimeout(150);
  if ((await readNumber('playerMp')) !== 75) {
    throw new Error(`Cooldown/active cast did not reject recast: mp=${await readNumber('playerMp')}`);
  }

  await page.waitForFunction(
    () =>
      Number(document.documentElement.dataset.skillHitCount) === 1 &&
      Number(document.documentElement.dataset.dummyHp) === 82 &&
      document.documentElement.dataset.lastSkillHit === 'true',
    null,
    { timeout: 5_000 },
  );

  const projectileImpactX = await readNumber('projectileX');
  if (!(projectileImpactX > initialX + 200)) {
    throw new Error(
      `Projectile did not demonstrate meaningful travel: initialPlayerX=${initialX} finalProjectileX=${projectileImpactX}`,
    );
  }

  await page.waitForFunction(
    () => document.documentElement.dataset.skillCanCast === 'true',
    null,
    { timeout: 4_000 },
  );

  // Regression: M1 guard/jump/run/dash remain wired through the real browser input layer.
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
    { step: 1, hp: 70, waitAfterMs: 180 },
    { step: 2, hp: 56, waitAfterMs: 200 },
    { step: 3, hp: 36, waitAfterMs: 100 },
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
  if (await readText('dummyCanBeHit') !== 'false') throw new Error('Downed dummy must not be hittable');

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
  if (await readText('dummyCanBeHit') !== 'true') throw new Error('Recovered dummy must become hittable');

  const hpAfterCombo = await readNumber('dummyHp');
  const dummyXAfterCombo = await readNumber('dummyX');
  if (hpAfterCombo !== 36) {
    throw new Error(`Expected fireball + three-hit combo to leave 36 HP; dummy HP is ${hpAfterCombo}`);
  }
  if (!(dummyXAfterCombo > initialDummyX + 20)) {
    throw new Error(`Expected visible knockback: initialDummyX=${initialDummyX} afterCombo=${dummyXAfterCombo}`);
  }

  await approachDummy();
  await page.keyboard.press('j');
  await page.waitForFunction(
    () => Number(document.documentElement.dataset.dummyHp) === 24,
    null,
    { timeout: 3_000 },
  );

  const hpAfterRecoveryHit = await readNumber('dummyHp');
  const finalState = await readText('playerState');
  if (hpAfterRecoveryHit !== 24) {
    throw new Error(`Expected first post-recovery hit to leave 24 HP; got ${hpAfterRecoveryHit}`);
  }

  if (pageErrors.length > 0 || consoleErrors.length > 0) {
    throw new Error(
      `Browser errors detected. pageErrors=${pageErrors.join(' | ')} consoleErrors=${consoleErrors.join(' | ')}`,
    );
  }

  console.log(
    `WEB_SKILL_AND_KNOCKDOWN_SMOKE_PASSED startupMs=${startupMs} fireballDamage=18 mpAfterCast=75 cooldownAfterCast=${cooldownAfterCast} projectileImpactX=${projectileImpactX} afterDash=${afterDashX} hpAfterCombo=${hpAfterCombo} hpAfterRecoveryHit=${hpAfterRecoveryHit} dummyX=${dummyXAfterCombo} finalState=${finalState}`,
  );
} finally {
  await browser.close();
}
