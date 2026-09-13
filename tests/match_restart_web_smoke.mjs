import { chromium } from 'playwright';

const baseUrl = process.env.CUSTOM_FIGHTER_WEB_URL ?? 'http://127.0.0.1:8000';
const browserChannel = process.env.BROWSER_CHANNEL?.trim();
const launchOptions = { headless: true };
if (browserChannel) launchOptions.channel = browserChannel;

console.log(`MATCH_RESTART_BROWSER=${browserChannel || 'playwright-chromium'}`);
console.log(`MATCH_RESTART_URL=${baseUrl}`);

async function dataset(page, key) {
  return String(await page.evaluate((name) => document.documentElement.dataset[name] ?? '', key));
}

async function numberDataset(page, key) {
  return Number(await dataset(page, key));
}

async function nudge(page, key, holdMs = 45) {
  await page.keyboard.down(key);
  await page.waitForTimeout(holdMs);
  await page.keyboard.up(key);
  await page.waitForTimeout(25);
}

async function waitForDummyToSettle(page, timeout = 4_000) {
  await page.waitForFunction(
    () => Math.abs(Number(document.documentElement.dataset.dummyKnockbackVelocity ?? '0')) < 5,
    null,
    { timeout },
  );
  await page.waitForTimeout(90);
}

async function approachDummy(page, minGap = 40, maxGap = 105) {
  await waitForDummyToSettle(page);
  let playerX = await numberDataset(page, 'playerX');
  let dummyX = await numberDataset(page, 'dummyX');
  let gap = dummyX - playerX;
  const stagingGap = maxGap + 55;

  for (let step = 0; step < 90 && gap < stagingGap; step += 1) {
    await nudge(page, 'a');
    playerX = await numberDataset(page, 'playerX');
    dummyX = await numberDataset(page, 'dummyX');
    gap = dummyX - playerX;
  }

  if (gap < stagingGap) {
    throw new Error(`Failed to stage left of dummy: playerX=${playerX} dummyX=${dummyX} gap=${gap}`);
  }

  for (let step = 0; step < 90 && gap > maxGap; step += 1) {
    await nudge(page, 'd');
    playerX = await numberDataset(page, 'playerX');
    dummyX = await numberDataset(page, 'dummyX');
    gap = dummyX - playerX;
  }

  await waitForDummyToSettle(page);
  playerX = await numberDataset(page, 'playerX');
  dummyX = await numberDataset(page, 'dummyX');
  gap = dummyX - playerX;
  if (gap < minGap || gap > maxGap) {
    throw new Error(`Failed to stabilize attack range: playerX=${playerX} dummyX=${dummyX} gap=${gap}`);
  }
}

async function castSkill1(page) {
  const beforeHits = await numberDataset(page, 'skillHitCount');
  await nudge(page, 'u', 100);
  await page.waitForFunction(
    (previousHits) => Number(document.documentElement.dataset.skillHitCount ?? '0') > previousHits,
    beforeHits,
    { timeout: 6_000 },
  );
}

const browser = await chromium.launch(launchOptions);
try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const response = await page.goto(baseUrl, { waitUntil: 'domcontentloaded', timeout: 60_000 });
  if (!response?.ok()) throw new Error(`Training URL returned HTTP ${response?.status() ?? 'unknown'}`);

  await page.waitForFunction(
    () =>
      document.documentElement.dataset.godotReady === 'true' &&
      document.documentElement.dataset.appMode === 'training' &&
      document.documentElement.dataset.matchRestartReady === 'true' &&
      document.documentElement.dataset.matchOver === 'false' &&
      typeof window.customFighterRestartMatch === 'function',
    null,
    { timeout: 60_000 },
  );

  const initialPlayerX = await numberDataset(page, 'playerX');
  const initialDummyX = await numberDataset(page, 'dummyX');
  if ((await numberDataset(page, 'dummyHp')) !== 100 || (await numberDataset(page, 'playerMp')) !== 100) {
    throw new Error('Training did not start from full HP/MP');
  }

  // Four real fireball casts spend all 100 MP and leave the dummy at 28 HP.
  // Finish with the existing real J -> J -> J melee combo so the test does not
  // manufacture resources or bypass combat rules just to reach match end.
  for (let cast = 0; cast < 4; cast += 1) {
    await castSkill1(page);
    if (cast < 3) {
      await page.waitForFunction(
        () => document.documentElement.dataset.skillCanCast === 'true',
        null,
        { timeout: 5_000 },
      );
    }
  }

  if ((await numberDataset(page, 'dummyHp')) !== 28 || (await numberDataset(page, 'playerMp')) !== 0) {
    throw new Error(
      `Unexpected pre-finisher resources: hp=${await dataset(page, 'dummyHp')} mp=${await dataset(page, 'playerMp')}`,
    );
  }

  await approachDummy(page);
  await nudge(page, 'j', 90);
  await nudge(page, 'j', 90);
  await nudge(page, 'j', 90);

  await page.waitForFunction(
    () =>
      document.documentElement.dataset.matchOver === 'true' &&
      document.documentElement.dataset.matchResult === 'victory' &&
      Number(document.documentElement.dataset.dummyHp) === 0,
    null,
    { timeout: 6_000 },
  );

  if ((await numberDataset(page, 'skillHitCount')) !== 4) {
    throw new Error(`Victory did not preserve four fireball hits: ${await dataset(page, 'skillHitCount')}`);
  }

  await page.evaluate(() => window.customFighterRestartMatch());
  await page.waitForFunction(
    ({ playerX, dummyX }) =>
      document.documentElement.dataset.appMode === 'training' &&
      document.documentElement.dataset.matchRestartReady === 'true' &&
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

  console.log(
    `WEB_MATCH_RESTART_SMOKE_PASSED victory=true restart=true hp=100 mp=100 playerX=${initialPlayerX} dummyX=${initialDummyX}`,
  );
} finally {
  await browser.close();
}
