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

async function waitForDummyToSettle(timeout = 4_000) {
  await page.waitForFunction(
    () => Math.abs(Number(document.documentElement.dataset.dummyKnockbackVelocity ?? '0')) < 5,
    null,
    { timeout },
  );
  await page.waitForTimeout(90);
}

async function approachDummy(minGap = 40, maxGap = 105) {
  await waitForDummyToSettle();
  let currentX = await readNumber('playerX');
  let currentDummyX = await readNumber('dummyX');
  let gap = currentDummyX - currentX;
  const stagingGap = maxGap + 55;

  // Always stage on the dummy's left side first. This matters after Dash Slash because
  // it can carry the player through the target; melee attacks use the player's facing.
  for (let step = 0; step < 90 && gap < stagingGap; step += 1) {
    await nudge('a');
    currentX = await readNumber('playerX');
    currentDummyX = await readNumber('dummyX');
    gap = currentDummyX - currentX;
  }

  if (gap < stagingGap) {
    throw new Error(
      `Failed to stage left of dummy: playerX=${currentX} dummyX=${currentDummyX} gap=${gap}`,
    );
  }

  // Approach only with D so the final movement input guarantees the player faces right
  // toward the dummy before the J combo begins. Edge runner frame cadence can overshoot
  // the nominal threshold by a few pixels, so the lower bound stays inside proven melee range.
  for (let step = 0; step < 90 && gap > maxGap; step += 1) {
    await nudge('d');
    currentX = await readNumber('playerX');
    currentDummyX = await readNumber('dummyX');
    gap = currentDummyX - currentX;
  }

  await waitForDummyToSettle();
  currentX = await readNumber('playerX');
  currentDummyX = await readNumber('dummyX');
  gap = currentDummyX - currentX;

  if (gap < minGap || gap > maxGap) {
    throw new Error(
      `Failed to stabilize attack range: playerX=${currentX} dummyX=${currentDummyX} gap=${gap}`,
    );
  }
  return { currentX, currentDummyX, gap };
}

async function waitForComboRecovery(expectedStep, timeout = 1_500) {
  await page.waitForFunction(
    (step) =>
      document.documentElement.dataset.playerState === 'READY' &&
      Number(document.documentElement.dataset.comboStep) === step,
    expectedStep,
    { timeout },
  );
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
      dashSkillLoaded: document.documentElement.dataset.dashSkillLoaded ?? null,
      dashSkillPhase: document.documentElement.dataset.dashSkillPhase ?? null,
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
    (await readText('skillId')) !== 'fireball_001' ||
    (await readText('dashSkillLoaded')) !== 'true' ||
    (await readText('dashSkillId')) !== 'dash_slash_001'
  ) {
    throw new Error(
      `Unexpected initial state: hp=${initialHp} mp=${initialMp} playerX=${initialX} dummyX=${initialDummyX} fireball=${await readText('skillId')} dash=${await readText('dashSkillId')}`,
    );
  }

  // Skill 1: real browser input must spend JSON MP and hit once for JSON damage.
  await page.keyboard.press('u');
  await page.waitForFunction(
    () => Number(document.documentElement.dataset.playerMp) === 75,
    null,
    { timeout: 3_000 },
  );
  const fireballCooldown = await readNumber('skillCooldown');
  if (!(fireballCooldown > 0)) throw new Error(`Expected fireball cooldown; got ${fireballCooldown}`);

  await page.keyboard.press('u');
  await page.waitForTimeout(150);
  if ((await readNumber('playerMp')) !== 75) {
    throw new Error(`Fireball recast was not rejected: mp=${await readNumber('playerMp')}`);
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
    throw new Error(`Fireball travel too short: initial=${initialX} impact=${projectileImpactX}`);
  }
  await page.waitForFunction(
    () => document.documentElement.dataset.skillCanCast === 'true',
    null,
    { timeout: 4_000 },
  );

  // M1 input regression: guard, jump, run and the non-skill K dash must still work.
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
  if (!(afterRunX > initialX + 40)) throw new Error(`Run distance too small: ${afterRunX - initialX}`);

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
  const afterStandardDashX = await readNumber('playerX');
  if (!(afterStandardDashX > afterRunX + 120)) {
    throw new Error(`Standard K dash distance too small: before=${afterRunX} after=${afterStandardDashX}`);
  }

  // Put the player in a deterministic launch corridor before Skill 2.
  await waitForDummyToSettle();
  await approachDummy(170, 220);
  const dashSkillStartX = await readNumber('playerX');

  // Skill 2: I is a combat dash, independent from K, with JSON MP/cooldown/travel/damage.
  await page.keyboard.press('i');
  await page.waitForFunction(
    () => Number(document.documentElement.dataset.playerMp) === 55,
    null,
    { timeout: 3_000 },
  );
  const dashCooldown = await readNumber('dashSkillCooldown');
  if (!(dashCooldown > 0)) throw new Error(`Expected dash skill cooldown; got ${dashCooldown}`);

  await page.keyboard.press('i');
  await page.waitForTimeout(120);
  if ((await readNumber('playerMp')) !== 55) {
    throw new Error(`Dash skill recast was not rejected: mp=${await readNumber('playerMp')}`);
  }

  await page.waitForFunction(
    () =>
      Number(document.documentElement.dataset.dashSkillHitCount) === 1 &&
      Number(document.documentElement.dataset.dummyHp) === 66 &&
      document.documentElement.dataset.lastDashSkillHit === 'true',
    null,
    { timeout: 4_000 },
  );
  await page.waitForFunction(
    () => document.documentElement.dataset.dashSkillActive === 'false',
    null,
    { timeout: 2_000 },
  );

  const afterDashSkillX = await readNumber('playerX');
  const dashSkillTravelled = await readNumber('dashSkillTravelled');
  if (!(afterDashSkillX > dashSkillStartX + 200 && dashSkillTravelled >= 250)) {
    throw new Error(
      `Dash skill travel mismatch: start=${dashSkillStartX} end=${afterDashSkillX} travelled=${dashSkillTravelled}`,
    );
  }
  await page.waitForFunction(
    () => document.documentElement.dataset.dashSkillCanCast === 'true',
    null,
    { timeout: 5_000 },
  );

  // The dash skill gives the dummy real knockback. Wait for physics to settle before
  // positioning the next melee sequence, rather than relying on runner frame timing.
  await waitForDummyToSettle();
  await approachDummy();

  const comboExpectations = [
    { step: 1, hp: 54 },
    { step: 2, hp: 40 },
    { step: 3, hp: 20 },
  ];
  for (const expected of comboExpectations) {
    // Hold J across at least one Godot frame. A synthetic press can otherwise go down/up
    // entirely between frames on a busy CI runner and never reach Input.is_action_pressed().
    await nudge('j', 90);
    await page.waitForFunction(
      ({ step, hp }) =>
        Number(document.documentElement.dataset.lastHitStep) === step &&
        Number(document.documentElement.dataset.dummyHp) === hp &&
        document.documentElement.dataset.lastAttackHit === 'true',
      expected,
      { timeout: 3_000 },
    );

    // Do not guess a runner-specific delay. The next combo input is legal as soon as the
    // current attack recovery ends while the combo step is still armed.
    if (expected.step < 3) {
      await waitForComboRecovery(expected.step);
    }
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

  const hpAfterCombo = await readNumber('dummyHp');
  const dummyXAfterCombo = await readNumber('dummyX');
  if (hpAfterCombo !== 20) {
    throw new Error(`Expected both skills + combo to leave 20 HP; got ${hpAfterCombo}`);
  }
  if (!(dummyXAfterCombo > initialDummyX + 20)) {
    throw new Error(`Expected visible accumulated knockback: initial=${initialDummyX} final=${dummyXAfterCombo}`);
  }

  await waitForDummyToSettle();
  await approachDummy();
  await nudge('j', 90);
  await page.waitForFunction(
    () => Number(document.documentElement.dataset.dummyHp) === 8,
    null,
    { timeout: 3_000 },
  );

  const hpAfterRecoveryHit = await readNumber('dummyHp');
  const finalState = await readText('playerState');
  if (pageErrors.length > 0 || consoleErrors.length > 0) {
    throw new Error(
      `Browser errors detected. pageErrors=${pageErrors.join(' | ')} consoleErrors=${consoleErrors.join(' | ')}`,
    );
  }

  console.log(
    `WEB_MULTI_SKILL_SMOKE_PASSED startupMs=${startupMs} fireballDamage=18 dashDamage=16 mpAfterSkills=55 fireballCooldown=${fireballCooldown} dashCooldown=${dashCooldown} projectileImpactX=${projectileImpactX} standardDashX=${afterStandardDashX} dashSkillX=${afterDashSkillX} dashTravelled=${dashSkillTravelled} hpAfterCombo=${hpAfterCombo} hpAfterRecoveryHit=${hpAfterRecoveryHit} dummyX=${dummyXAfterCombo} finalState=${finalState}`,
  );
} finally {
  await browser.close();
}