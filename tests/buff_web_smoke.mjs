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

  for (let step = 0; step < 100 && gap > maxGap; step += 1) {
    await holdKey('d', 35, 20);
    playerX = await readNumber('playerX');
    dummyX = await readNumber('dummyX');
    gap = dummyX - playerX;
  }

  await waitForDummyToSettle();
  playerX = await readNumber('playerX');
  dummyX = await readNumber('dummyX');
  gap = dummyX - playerX;
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
      document.documentElement.dataset.buffSkillLoaded === 'true',
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

  // Establish a real-browser baseline movement sample before the buff.
  const baselineStartX = await readNumber('playerX');
  await holdKey('d', 350, 60);
  const baselineEndX = await readNumber('playerX');
  const baselineDisplacement = baselineEndX - baselineStartX;
  if (!(baselineDisplacement > 70)) {
    throw new Error(`Baseline movement sample too small: ${baselineDisplacement}`);
  }

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

  // Recast during the active/cooldown window must be sampled and rejected without spending MP.
  await holdKey('b');
  await page.waitForTimeout(120);
  if ((await readNumber('playerMp')) !== 75 || (await readNumber('buffActivationCount')) !== 1) {
    throw new Error(
      `Buff duplicate cast was not rejected: mp=${await readNumber('playerMp')} activations=${await readNumber('buffActivationCount')}`,
    );
  }

  const buffMoveStartX = await readNumber('playerX');
  await holdKey('d', 350, 60);
  const buffMoveEndX = await readNumber('playerX');
  const buffDisplacement = buffMoveEndX - buffMoveStartX;
  if (!(buffDisplacement > baselineDisplacement * 1.20)) {
    throw new Error(
      `Buff movement boost too small: baseline=${baselineDisplacement} buffed=${buffDisplacement}`,
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
    `WEB_BUFF_SKILL_SMOKE_PASSED mpAfterTwoCasts=50 activations=2 baselineMove=${baselineDisplacement.toFixed(2)} buffMove=${buffDisplacement.toFixed(2)} moveMultiplier=${moveMultiplier} attackMultiplier=${attackMultiplier} hpAfterBuffedHit=${hpAfterBuffedHit} finalHp=${await readNumber('dummyHp')} cooldownAfterCast=${cooldownAfterCast}`,
  );
} finally {
  await browser.close();
}
