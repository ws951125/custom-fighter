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

async function castSkill1(page) {
  const beforeHits = await numberDataset(page, 'skillHitCount');
  await page.keyboard.down('u');
  await page.waitForTimeout(100);
  await page.keyboard.up('u');
  await page.waitForFunction(
    (previousHits) =>
      document.documentElement.dataset.matchOver === 'true' ||
      Number(document.documentElement.dataset.skillHitCount ?? '0') > previousHits,
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

  for (let cast = 0; cast < 6 && (await dataset(page, 'matchOver')) !== 'true'; cast += 1) {
    await castSkill1(page);
    if ((await dataset(page, 'matchOver')) === 'true') break;
    await page.waitForFunction(
      () => document.documentElement.dataset.skillCanCast === 'true',
      null,
      { timeout: 5_000 },
    );
  }

  await page.waitForFunction(
    () =>
      document.documentElement.dataset.matchOver === 'true' &&
      document.documentElement.dataset.matchResult === 'victory' &&
      Number(document.documentElement.dataset.dummyHp) === 0,
    null,
    { timeout: 6_000 },
  );

  if ((await numberDataset(page, 'skillHitCount')) < 5) {
    throw new Error(`Victory did not record expected skill hits: ${await dataset(page, 'skillHitCount')}`);
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
