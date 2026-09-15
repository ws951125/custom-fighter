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

async function movementNudge(key, beforeX, holdMs) {
  await page.keyboard.down(key);
  await page.waitForTimeout(holdMs);
  await page.keyboard.up(key);

  // Hosted Edge can publish playerX more slowly than keyboard events are sent. Wait for
  // runtime-observed movement before issuing another command so stale samples cannot queue
  // several nudges and overshoot a positioning corridor by a large amount.
  try {
    await page.waitForFunction(
      (previousX) => Math.abs(Number(document.documentElement.dataset.playerX) - previousX) > 0.5,
      beforeX,
      { timeout: 900 },
    );
  } catch {
    // Frame-polled input can legitimately be missed. The caller re-reads state and retries.
  }
  await page.waitForTimeout(55);
}

async function approachDummy(minGap = 40, maxGap = 105) {
  await waitForDummyToSettle();
  let currentX = await readNumber('playerX');
  let currentDummyX = await readNumber('dummyX');
  let gap = currentDummyX - currentX;
  const stagingGap = maxGap + 55;

  // Re-stage and retry if a busy runner still overshoots the requested corridor. Every
  // successful attempt approaches only with D, preserving deterministic right-facing for
  // both the Skill 2 launch corridor and the later melee combo.
  for (let attempt = 0; attempt < 4; attempt += 1) {
    for (let step = 0; step < 100 && gap < stagingGap; step += 1) {
      await movementNudge('a', currentX, 28);
      currentX = await readNumber('playerX');
      currentDummyX = await readNumber('dummyX');
      gap = currentDummyX - currentX;
    }

    if (gap < stagingGap) {
      throw new Error(
        `Failed to stage left of dummy: playerX=${currentX} dummyX=${currentDummyX} gap=${gap}`,
      );
    }

    for (let step = 0; step < 100 && gap > maxGap; step += 1) {
      const distanceFromRange = gap - maxGap;
      const holdMs = distanceFromRange > 220 ? 38 : distanceFromRange > 120 ? 28 : 20;
      await movementNudge('d', currentX, holdMs);
      currentX = await readNumber('playerX');
      currentDummyX = await readNumber('dummyX');
      gap = currentDummyX - currentX;
    }

    await page.waitForTimeout(90);
    currentX = await readNumber('playerX');
    currentDummyX = await readNumber('dummyX');
    gap = currentDummyX - currentX;

    if (gap >= minGap && gap <= maxGap) {
      return { currentX, currentDummyX, gap };
    }

    console.log(
      `APPROACH_RETRY attempt=${attempt + 1} minGap=${minGap} maxGap=${maxGap} playerX=${currentX} dummyX=${currentDummyX} gap=${gap}`,
    );
  }

  throw new Error(
    `Failed to stabilize attack range: playerX=${currentX} dummyX=${currentDummyX} gap=${gap}`,
  );
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

  // Skill 1: hold real browser input across a Godot frame so the runner cannot miss it.
  await nudge('u', 90);
  await page.waitForFunction(
    () => Number(document.documentElement.dataset.playerMp) === 75,
    null,
    { timeout: 3_000 },
  );
  const fireballCooldown = await readNumber('skillCooldown');
  if (!(fireballCooldown > 0)) throw new Error(`Expected fireball cooldown; got ${fireballCooldown}`);

  // A held recast attempt also prevents a dropped key from looking like a valid cooldown rejection.
  await nudge('u', 90);
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

  // Keep Space down until the Godot diagnostics acknowledge the jump, then release it.
  await page.keyboard.down('Space');
  try {
    await page.waitForFunction(
      () => document.documentElement.dataset.playerJumping === 'true',
      null,
      { timeout: 2_000 },
    );
  } finally {
    await page.keyboard.up('Space');
  }
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

  // Keep K down until the runtime acknowledges the dash so frame cadence cannot drop the input.
  await page.keyboard.down('k');
  try {
    await page.waitForFunction(
      () => document.documentElement.dataset.playerDashing === 'true',
      null,
      { timeout: 2_000 },
    );
  } finally {
    await page.keyboard.up('k');
  }
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
  // Hold the key across a Godot frame so a busy runner cannot drop a synthetic down/up pair.
  await nudge('i', 90);
  await page.waitForFunction(
    () => Number(document.documentElement.dataset.playerMp) === 55,
    null,
    { timeout: 3_000 },
  );
  const dashCooldown = await readNumber('dashSkillCooldown');
  if (!(dashCooldown > 0)) throw new Error(`Expected dash skill cooldown; got ${dashCooldown}`);

  // Sample the cooldown rejection with a real held input too; otherwise a missed press could
  // falsely look like a successful rejection simply because the game never sampled the key.
  await nudge('i', 90);
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

  // Exercise the actual combo input buffer instead of waiting for a runner-observed READY
  // frame between attacks. Each J press is distinct, held long enough to cross a Godot frame,
  // and spaced so presses two and three land during recovery and must be buffered. The final
  // HP and knockdown assertions prove that the browser executed steps 1 -> 2 -> 3 exactly.
  await nudge('j', 90);
  await nudge('j', 90);
  await nudge('j', 90);
  await page.waitForFunction(
    () =>
      Number(document.documentElement.dataset.lastHitStep) === 3 &&
      Number(document.documentElement.dataset.dummyHp) === 20 &&
      document.documentElement.dataset.lastAttackHit === 'true' &&
      document.documentElement.dataset.dummyRecoveryState === 'DOWN',
    null,
    { timeout: 4_000 },
  );

  if (await readText('dummyCanBeHit') !== 'false') throw new Error('Downed dummy must not be hittable');

  await page.waitForFunction(
    () => document.documentElement.dataset.dummyRecoveryState === 'RECOVERING',
    null,
    { timeout: 2_000 },
  );
  // Observe the recovery phase and its protection flag atomically. On a busy hosted Edge
  // runner, the runtime can legitimately advance INVULNERABLE -> READY between two JS reads.
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.dummyRecoveryState === 'INVULNERABLE' &&
      document.documentElement.dataset.dummyInvulnerable === 'true',
    null,
    { timeout: 2_000 },
  );
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