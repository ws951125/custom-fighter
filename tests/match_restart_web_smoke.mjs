import { chromium } from 'playwright';

const baseUrl = process.env.CUSTOM_FIGHTER_WEB_URL ?? 'http://127.0.0.1:8000';
const channel = process.env.BROWSER_CHANNEL?.trim();
const launchOptions = { headless: true };
if (channel) launchOptions.channel = channel;

const browser = await chromium.launch(launchOptions);
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });

async function num(key) {
  return Number(await page.evaluate((k) => document.documentElement.dataset[k] ?? '0', key));
}
async function text(key) {
  return String(await page.evaluate((k) => document.documentElement.dataset[k] ?? '', key));
}
async function nudge(key, ms = 45) {
  await page.keyboard.down(key);
  await page.waitForTimeout(ms);
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
async function approach(minGap = 45, maxGap = 100) {
  await waitForDummyToSettle();
  let playerX = await num('playerX');
  let dummyX = await num('dummyX');
  let gap = dummyX - playerX;
  const stagingGap = maxGap + 55;

  // Always stage on the dummy's left side first. Numeric melee range alone does not
  // guarantee facing, and a final A correction can make the J hitbox point away.
  for (let i = 0; i < 120 && gap < stagingGap; i += 1) {
    await nudge('a');
    playerX = await num('playerX');
    dummyX = await num('dummyX');
    gap = dummyX - playerX;
  }
  if (gap < stagingGap) {
    throw new Error(`Could not stage left of dummy: playerX=${playerX} dummyX=${dummyX} gap=${gap}`);
  }

  // Approach only with D so the last movement input guarantees the player faces the
  // dummy before the combo begins. This mirrors the proven hosted-Edge melee helper.
  for (let i = 0; i < 120 && gap > maxGap; i += 1) {
    await nudge('d');
    playerX = await num('playerX');
    dummyX = await num('dummyX');
    gap = dummyX - playerX;
  }

  await waitForDummyToSettle();
  playerX = await num('playerX');
  dummyX = await num('dummyX');
  gap = dummyX - playerX;
  if (gap < minGap || gap > maxGap) {
    throw new Error(`Could not enter stable melee range: playerX=${playerX} dummyX=${dummyX} gap=${gap}`);
  }
}
async function combo(expectedHp) {
  // Exercise the real combo input buffer rather than waiting for a runner-observed READY
  // frame between attacks. Hosted Edge can skip that transient observation window even
  // when the runtime is healthy. The final hit-step/HP/knockdown state proves 1->2->3.
  await nudge('j', 90);
  await nudge('j', 90);
  await nudge('j', 90);
  await page.waitForFunction(
    (hp) =>
      Number(document.documentElement.dataset.lastHitStep) === 3 &&
      Number(document.documentElement.dataset.dummyHp) === hp &&
      document.documentElement.dataset.lastAttackHit === 'true' &&
      document.documentElement.dataset.dummyRecoveryState === 'DOWN',
    expectedHp,
    { timeout: 5_000 },
  );
}
async function waitRecovered() {
  await page.waitForFunction(
    () => document.documentElement.dataset.dummyRecoveryState === 'READY',
    null,
    { timeout: 8_000 },
  );
}

try {
  const response = await page.goto(baseUrl, { waitUntil: 'domcontentloaded', timeout: 60_000 });
  if (!response?.ok()) throw new Error(`Training URL returned HTTP ${response?.status() ?? 'unknown'}`);
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.godotReady === 'true' &&
      document.documentElement.dataset.matchRestartReady === 'true' &&
      document.documentElement.dataset.matchReturnCreatorReady === 'true' &&
      document.documentElement.dataset.matchOver === 'false' &&
      typeof window.customFighterRestartMatch === 'function' &&
      typeof window.customFighterReturnToCreator === 'function',
    null,
    { timeout: 60_000 },
  );

  const initialPlayerX = await num('playerX');
  const initialDummyX = await num('dummyX');
  if ((await num('dummyHp')) !== 100 || (await num('playerMp')) !== 100) {
    throw new Error('Training did not start from full HP/MP');
  }

  await approach();
  await combo(54);
  await waitRecovered();
  await approach();
  await combo(8);
  await waitRecovered();
  await approach();
  await nudge('j', 90);

  await page.waitForFunction(
    () =>
      document.documentElement.dataset.matchOver === 'true' &&
      document.documentElement.dataset.matchResult === 'victory' &&
      Number(document.documentElement.dataset.dummyHp) === 0,
    null,
    { timeout: 6_000 },
  );

  await page.evaluate(() => window.customFighterRestartMatch());
  await page.waitForFunction(
    ({ playerX, dummyX }) =>
      document.documentElement.dataset.matchRestartReady === 'true' &&
      document.documentElement.dataset.matchReturnCreatorReady === 'true' &&
      document.documentElement.dataset.matchOver === 'false' &&
      document.documentElement.dataset.matchResult === '' &&
      Number(document.documentElement.dataset.dummyHp) === 100 &&
      Number(document.documentElement.dataset.playerMp) === 100 &&
      Number(document.documentElement.dataset.skillHitCount) === 0 &&
      Number(document.documentElement.dataset.dashSkillHitCount) === 0 &&
      Number(document.documentElement.dataset.skillCooldown) === 0 &&
      Number(document.documentElement.dataset.dashSkillCooldown) === 0 &&
      Math.abs(Number(document.documentElement.dataset.playerX) - playerX) < 0.1 &&
      Math.abs(Number(document.documentElement.dataset.dummyX) - dummyX) < 0.1,
    { playerX: initialPlayerX, dummyX: initialDummyX },
    { timeout: 60_000 },
  );

  await page.evaluate(() => window.customFighterReturnToCreator());
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.appMode === 'creator' &&
      document.documentElement.dataset.creatorStudioReady === 'true',
    null,
    { timeout: 60_000 },
  );

  console.log(`WEB_MATCH_RESTART_SMOKE_PASSED victory=true restart=true returnCreator=true result=${await text('matchResult')}`);
} finally {
  await browser.close();
}
