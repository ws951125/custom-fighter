import { chromium } from 'playwright';

const baseUrl = process.env.CUSTOM_FIGHTER_WEB_URL ?? 'http://127.0.0.1:8000';
const browserChannel = process.env.BROWSER_CHANNEL?.trim();
const launchOptions = { headless: true };
if (browserChannel) launchOptions.channel = browserChannel;

console.log(`BUFF_SMOKE_BROWSER=${browserChannel || 'playwright-chromium'}`);
console.log(`BUFF_SMOKE_URL=${baseUrl}`);

const browser = await chromium.launch(launchOptions);
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const pageErrors = [];
const consoleErrors = [];

page.on('pageerror', (error) => {
  const detail = error?.stack || error?.message || String(error);
  pageErrors.push(detail);
  console.error(`[buff pageerror] ${detail}`);
});
page.on('console', (message) => {
  console.log(`[buff browser ${message.type()}] ${message.text()}`);
  if (message.type() === 'error') consoleErrors.push(message.text());
});
page.on('requestfailed', (request) => {
  console.error(`[buff requestfailed] ${request.url()} :: ${request.failure()?.errorText ?? 'unknown'}`);
});

async function readNumber(key) {
  return Number(await page.evaluate((datasetKey) => document.documentElement.dataset[datasetKey], key));
}

async function readText(key) {
  return String(await page.evaluate((datasetKey) => document.documentElement.dataset[datasetKey] ?? '', key));
}

async function holdKey(key, holdMs = 90, settleMs = 35) {
  await page.keyboard.down(key);
  await page.waitForTimeout(holdMs);
  await page.keyboard.up(key);
  await page.waitForTimeout(settleMs);
}

async function sampleHorizontalSpeed(label, expectedMultiplier, baseMoveSpeed) {
  const startX = await readNumber('playerX');
  const startFrames = await readNumber('playerMovementAdjustmentFrames');

  await page.keyboard.down('d');
  try {
    await page.waitForFunction(
      ({ before, requiredFrames }) =>
        Number(document.documentElement.dataset.playerMovementAdjustmentFrames ?? '0') >=
        before + requiredFrames,
      { before: startFrames, requiredFrames: 3 },
      { timeout: 2_500 },
    );
  } finally {
    await page.keyboard.up('d');
  }
  await page.waitForTimeout(60);

  const endX = await readNumber('playerX');
  const observedSpeed = await readNumber('playerLastHorizontalSpeed');
  const runtimeMultiplier = await readNumber('playerRuntimeBuffMovementMultiplier');
  const expectedSpeed = baseMoveSpeed * expectedMultiplier;
  const displacement = endX - startX;

  if (!(displacement > 5)) {
    throw new Error(`${label}: player did not move enough to sample speed: ${displacement}`);
  }
  if (Math.abs(runtimeMultiplier - expectedMultiplier) > 0.02) {
    throw new Error(
      `${label}: runtime movement multiplier mismatch: expected=${expectedMultiplier} actual=${runtimeMultiplier}`,
    );
  }
  if (Math.abs(observedSpeed - expectedSpeed) > Math.max(5, expectedSpeed * 0.08)) {
    throw new Error(
      `${label}: runtime horizontal speed mismatch: expected=${expectedSpeed} actual=${observedSpeed}`,
    );
  }

  return { displacement, observedSpeed, runtimeMultiplier };
}

async function waitForDummyToSettle(timeout = 4_000) {
  await page.waitForFunction(
    () => Math.abs(Number(document.documentElement.dataset.dummyKnockbackVelocity ?? '0')) < 5,
    null,
    { timeout },
  );
  await page.waitForTimeout(90);
}

async function approachDummy(minGap = 35, maxGap = 100) {
  await waitForDummyToSettle();
  let playerX = await readNumber('playerX');
  let dummyX = await readNumber('dummyX');
  let gap = dummyX - playerX;
  const targetGap = (minGap + maxGap) / 2;
  const stagingGap = maxGap + 55;

  for (let step = 0; step < 100 && gap < stagingGap; step += 1) {
    await holdKey('a', 35, 20);
    playerX = await readNumber('playerX');
    dummyX = await readNumber('dummyX');
    gap = dummyX - playerX;
  }
  if (gap < stagingGap) {
    throw new Error(`Failed to stage left of dummy: playerX=${playerX} dummyX=${dummyX} gap=${gap}`);
  }

  for (let step = 0; step < 160; step += 1) {
    if (gap >= minGap && gap <= maxGap) break;
    const key = gap > targetGap ? 'd' : 'a';
    const error = Math.abs(gap - targetGap);
    const holdMs = error > 90 ? 28 : error > 45 ? 18 : 10;
    await holdKey(key, holdMs, 18);
    playerX = await readNumber('playerX');
    dummyX = await readNumber('dummyX');
    gap = dummyX - playerX;
  }

  await waitForDummyToSettle();
  playerX = await readNumber('playerX');
  dummyX = await readNumber('dummyX');
  gap = dummyX - playerX;

  for (let step = 0; step < 40 && (gap < minGap || gap > maxGap); step += 1) {
    const key = gap > targetGap ? 'd' : 'a';
    await holdKey(key, 8, 20);
    playerX = await readNumber('playerX');
    dummyX = await readNumber('dummyX');
    gap = dummyX - playerX;
  }

  if (gap < minGap || gap > maxGap) {
    throw new Error(`Failed to stabilize attack range: playerX=${playerX} dummyX=${dummyX} gap=${gap}`);
  }
  return { playerX, dummyX, gap };
}

async function assertBaselineMultipliers(label) {
  const move = await readNumber('buffMoveMultiplier');
  const attack = await readNumber('buffAttackMultiplier');
  if (Math.abs(move - 1.0) > 0.001 || Math.abs(attack - 1.0) > 0.001) {
    throw new Error(`${label}: Buff multipliers did not restore: move=${move} attack=${attack}`);
  }
}

try {
  const response = await page.goto(baseUrl, { waitUntil: 'domcontentloaded', timeout: 60_000 });
  if (!response?.ok()) {
    throw new Error(`Buff test Web build returned HTTP ${response?.status() ?? 'unknown'}`);
  }

  await page.waitForFunction(
    () =>
      document.documentElement.dataset.godotReady === 'true' &&
      document.documentElement.dataset.buffSkillLoaded === 'true' &&
      document.documentElement.dataset.playerCharacterLoaded === 'true',
    null,
    { timeout: 60_000 },
  );

  if ((await readText('buffSkillId')) !== 'battle_focus_001') {
    throw new Error(`Unexpected buff skill id: ${await readText('buffSkillId')}`);
  }
  if ((await readNumber('playerMp')) !== 100 || (await readNumber('dummyHp')) !== 100) {
    throw new Error(`Unexpected clean state: mp=${await readNumber('playerMp')} hp=${await readNumber('dummyHp')}`);
  }
  if ((await readText('buffActive')) !== 'false') {
    throw new Error('Buff unexpectedly starts active');
  }

  const baseMoveSpeed = await readNumber('playerRuntimeMoveSpeed');
  if (!(baseMoveSpeed > 0)) {
    throw new Error(`Character runtime move speed is unavailable: ${baseMoveSpeed}`);
  }

  // Sample movement in Godot frame-space rather than assuming Playwright's wall-clock hold
  // duration equals gameplay time. This stays deterministic even when an Edge runner stalls.
  const baselineSample = await sampleHorizontalSpeed('Baseline movement', 1.0, baseMoveSpeed);

  // Activation #1 is dedicated to movement verification. Keeping movement and damage
  // verification in separate activations avoids coupling a 3.2s gameplay duration to CI speed.
  await holdKey('b');
  await page.waitForFunction(
    () =>
      Number(document.documentElement.dataset.playerMp) === 75 &&
      document.documentElement.dataset.buffActive === 'true' &&
      Number(document.documentElement.dataset.buffActivationCount) === 1,
    null,
    { timeout: 3_000 },
  );

  const cooldownAfterCast = await readNumber('buffSkillCooldown');
  const moveMultiplier = await readNumber('buffMoveMultiplier');
  const attackMultiplier = await readNumber('buffAttackMultiplier');
  if (!(cooldownAfterCast > 0)) throw new Error(`Buff cooldown did not start: ${cooldownAfterCast}`);
  if (Math.abs(moveMultiplier - 1.45) > 0.02 || Math.abs(attackMultiplier - 1.5) > 0.02) {
    throw new Error(`Unexpected active multipliers: move=${moveMultiplier} attack=${attackMultiplier}`);
  }

  // Wait until the cast animation releases the shared skill lock while the timed buff remains.
  // The runtime should now compose CharacterDefinition movement × 1.45 exactly once.
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.skillCoordinatorBusy === 'false' &&
      document.documentElement.dataset.buffActive === 'true',
    null,
    { timeout: 2_500 },
  );
  const buffSample = await sampleHorizontalSpeed('Battle Focus movement', moveMultiplier, baseMoveSpeed);

  // Recast during the active/cooldown window must be sampled and rejected without spending MP.
  await holdKey('b');
  await page.waitForTimeout(120);
  if ((await readNumber('playerMp')) !== 75 || (await readNumber('buffActivationCount')) !== 1) {
    throw new Error(
      `Buff duplicate cast was not rejected: mp=${await readNumber('playerMp')} activations=${await readNumber('buffActivationCount')}`,
    );
  }

  await page.waitForFunction(
    () => document.documentElement.dataset.buffActive === 'false',
    null,
    { timeout: 5_000 },
  );
  await page.waitForTimeout(120);
  await assertBaselineMultipliers('After movement activation');

  // Position while the first cast is cooling down, then wait for state-driven castability.
  // Activation #2 is dedicated to proving the exact 1.5x basic-attack damage.
  await approachDummy();
  await page.waitForFunction(
    () => document.documentElement.dataset.buffSkillCanCast === 'true',
    null,
    { timeout: 6_000 },
  );

  await holdKey('b');
  await page.waitForFunction(
    () =>
      Number(document.documentElement.dataset.playerMp) === 50 &&
      document.documentElement.dataset.buffActive === 'true' &&
      Number(document.documentElement.dataset.buffActivationCount) === 2,
    null,
    { timeout: 3_000 },
  );

  // The shared coordinator intentionally blocks basic attacks while the buff cast animation
  // still owns the skill lock. Once the cast releases, the timed buff remains active and J
  // must be allowed, proving that the effect itself does not monopolize the coordinator.
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.skillCoordinatorBusy === 'false' &&
      document.documentElement.dataset.buffActive === 'true',
    null,
    { timeout: 2_500 },
  );

  await holdKey('j');
  await page.waitForFunction(
    () =>
      Number(document.documentElement.dataset.dummyHp) === 82 &&
      document.documentElement.dataset.lastAttackHit === 'true',
    null,
    { timeout: 2_500 },
  );
  const hpAfterBuffedHit = await readNumber('dummyHp');

  // The second expiration must also restore exact baseline multipliers.
  await page.waitForFunction(
    () => document.documentElement.dataset.buffActive === 'false',
    null,
    { timeout: 5_000 },
  );
  await page.waitForTimeout(140);
  await assertBaselineMultipliers('After damage activation');

  // Let combo timing reset, re-enter range after knockback, then prove normal 12 damage returns.
  await page.waitForTimeout(750);
  await approachDummy();
  await holdKey('j');
  await page.waitForFunction(
    () => Number(document.documentElement.dataset.dummyHp) === 70,
    null,
    { timeout: 2_500 },
  );

  if (pageErrors.length > 0 || consoleErrors.length > 0) {
    throw new Error(
      `Buff browser errors detected. pageErrors=${pageErrors.join(' | ')} consoleErrors=${consoleErrors.join(' | ')}`,
    );
  }

  console.log(
    `WEB_BUFF_SKILL_SMOKE_PASSED mpAfterTwoCasts=50 activations=2 baselineSpeed=${baselineSample.observedSpeed.toFixed(2)} buffSpeed=${buffSample.observedSpeed.toFixed(2)} baselineMove=${baselineSample.displacement.toFixed(2)} buffMove=${buffSample.displacement.toFixed(2)} moveMultiplier=${moveMultiplier} attackMultiplier=${attackMultiplier} hpAfterBuffedHit=${hpAfterBuffedHit} finalHp=${await readNumber('dummyHp')} cooldownAfterCast=${cooldownAfterCast}`,
  );
} finally {
  await browser.close();
}
