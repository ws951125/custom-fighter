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
async function tap(key, ms = 80) {
  await page.keyboard.down(key);
  await page.waitForTimeout(ms);
  await page.keyboard.up(key);
  await page.waitForTimeout(45);
}
async function approach() {
  for (let i = 0; i < 120; i += 1) {
    const gap = (await num('dummyX')) - (await num('playerX'));
    if (gap >= 45 && gap <= 100) return;
    await tap(gap > 75 ? 'd' : 'a', 25);
  }
  throw new Error(`Could not enter melee range: gap=${(await num('dummyX')) - (await num('playerX'))}`);
}
async function hit(expectedHp) {
  await tap('j', 90);
  await page.waitForFunction(
    (hp) => Number(document.documentElement.dataset.dummyHp) === hp,
    expectedHp,
    { timeout: 5_000 },
  );
  await page.waitForFunction(
    () => document.documentElement.dataset.playerState === 'READY',
    null,
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
  await hit(88);
  await hit(74);
  await hit(54);
  await waitRecovered();
  await approach();
  await hit(42);
  await hit(28);
  await hit(8);
  await waitRecovered();
  await approach();
  await tap('j', 90);

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
      document.documentElement.dataset.creatorReady === 'true',
    null,
    { timeout: 60_000 },
  );

  console.log(`WEB_MATCH_RESTART_SMOKE_PASSED victory=true restart=true returnCreator=true result=${await text('matchResult')}`);
} finally {
  await browser.close();
}
