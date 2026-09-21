import { chromium } from 'playwright';

const baseUrl = process.env.CUSTOM_FIGHTER_WEB_URL ?? 'http://127.0.0.1:8000';
const channel = process.env.BROWSER_CHANNEL?.trim();
const launchOptions = { headless: true };
if (channel) launchOptions.channel = channel;

function withMode(mode) {
  const url = new URL(baseUrl);
  if (mode) url.searchParams.set('mode', mode);
  else url.searchParams.delete('mode');
  return url.toString();
}

const browser = await chromium.launch(launchOptions);
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });

async function num(key) {
  return Number(await page.evaluate((k) => document.documentElement.dataset[k] ?? '0', key));
}

try {
  const singlePlayerUrl = withMode('single_player');
  const response = await page.goto(singlePlayerUrl, { waitUntil: 'domcontentloaded', timeout: 60_000 });
  if (!response?.ok()) {
    throw new Error(`Single-player URL returned HTTP ${response?.status() ?? 'unknown'}`);
  }

  await page.waitForFunction(
    () =>
      document.documentElement.dataset.appMode === 'single_player' &&
      document.documentElement.dataset.godotReady === 'true' &&
      document.documentElement.dataset.opponentAiActive === 'true' &&
      document.documentElement.dataset.opponentAiProfile === 'training_balanced' &&
      document.documentElement.dataset.matchOver === 'false',
    null,
    { timeout: 60_000 },
  );

  const initialPlayerX = await num('playerX');
  const initialDummyX = await num('dummyX');

  await page.waitForFunction(
    (startX) =>
      document.documentElement.dataset.opponentAiIntent === 'move' &&
      Number(document.documentElement.dataset.dummyX) < startX - 60,
    initialDummyX,
    { timeout: 8_000 },
  );

  await page.waitForFunction(
    () =>
      Number(document.documentElement.dataset.opponentAiAttackCount) >= 1 &&
      Number(document.documentElement.dataset.opponentAiHitCount) >= 1 &&
      Number(document.documentElement.dataset.playerHp) < 100 &&
      Number(document.documentElement.dataset.opponentAiLastDamage) > 0,
    null,
    { timeout: 10_000 },
  );

  await page.waitForFunction(
    () =>
      document.documentElement.dataset.matchOver === 'true' &&
      document.documentElement.dataset.matchResult === 'defeat' &&
      Number(document.documentElement.dataset.playerHp) === 0 &&
      Number(document.documentElement.dataset.opponentAiHitCount) >= 1,
    null,
    { timeout: 18_000 },
  );

  await page.evaluate(() => window.customFighterRestartMatch());
  await page.waitForFunction(
    ({ playerX, dummyX }) =>
      document.documentElement.dataset.appMode === 'single_player' &&
      document.documentElement.dataset.opponentAiActive === 'true' &&
      document.documentElement.dataset.matchOver === 'false' &&
      document.documentElement.dataset.matchResult === '' &&
      Number(document.documentElement.dataset.playerHp) === 100 &&
      Number(document.documentElement.dataset.dummyHp) === 100 &&
      Number(document.documentElement.dataset.opponentAiAttackCount) === 0 &&
      Math.abs(Number(document.documentElement.dataset.playerX) - playerX) < 0.1 &&
      Math.abs(Number(document.documentElement.dataset.dummyX) - dummyX) < 0.1,
    { playerX: initialPlayerX, dummyX: initialDummyX },
    { timeout: 60_000 },
  );

  const passiveUrl = withMode('');
  const passiveResponse = await page.goto(passiveUrl, { waitUntil: 'domcontentloaded', timeout: 60_000 });
  if (!passiveResponse?.ok()) {
    throw new Error(`Passive Training URL returned HTTP ${passiveResponse?.status() ?? 'unknown'}`);
  }

  await page.waitForFunction(
    () =>
      document.documentElement.dataset.appMode === 'training' &&
      document.documentElement.dataset.godotReady === 'true' &&
      document.documentElement.dataset.opponentAiActive === 'false' &&
      document.documentElement.dataset.matchOver === 'false',
    null,
    { timeout: 60_000 },
  );

  const passiveDummyX = await num('dummyX');
  await page.waitForTimeout(1_200);
  const passiveDummyXAfter = await num('dummyX');
  if (Math.abs(passiveDummyXAfter - passiveDummyX) > 0.1) {
    throw new Error(`Passive Training dummy moved unexpectedly: before=${passiveDummyX} after=${passiveDummyXAfter}`);
  }
  if ((await num('playerHp')) !== 100 || (await num('opponentAiAttackCount')) !== 0) {
    throw new Error('Passive Training unexpectedly applied opponent AI combat');
  }

  console.log(
    'WEB_OPPONENT_AI_SMOKE_PASSED activeMode=true approach=true attack=true playerDefeat=true restartPreserved=true passiveTraining=true',
  );
} finally {
  await browser.close();
}
