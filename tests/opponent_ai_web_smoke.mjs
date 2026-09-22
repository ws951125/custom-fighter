import { chromium } from 'playwright';

const baseUrl = process.env.CUSTOM_FIGHTER_WEB_URL ?? 'http://127.0.0.1:8000';
const channel = process.env.BROWSER_CHANNEL?.trim();
const launchOptions = { headless: true };
if (channel) launchOptions.channel = channel;

function withMode(mode, opponentProfile = '') {
  const url = new URL(baseUrl);
  if (mode) url.searchParams.set('mode', mode);
  else url.searchParams.delete('mode');
  if (opponentProfile) url.searchParams.set('opponent_profile', opponentProfile);
  else url.searchParams.delete('opponent_profile');
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
      document.documentElement.dataset.appOpponentProfile === 'training_balanced' &&
      document.documentElement.dataset.opponentAiProfileSelectorVisible === 'true' &&
      document.documentElement.dataset.opponentAiProfileSelectorCount === '3' &&
      Math.abs(Number(document.documentElement.dataset.opponentAiReactionInterval) - 0.25) < 0.001 &&
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

  try {
    await page.waitForFunction(
      () =>
        Number(document.documentElement.dataset.opponentAiAttackCount) >= 1 &&
        Number(document.documentElement.dataset.opponentAiHitCount) >= 1 &&
        Number(document.documentElement.dataset.playerHp) < 100 &&
        Number(document.documentElement.dataset.opponentAiLastDamage) > 0,
      null,
      { timeout: 10_000 },
    );
  } catch (error) {
    const snapshot = await page.evaluate(() => ({
      playerX: document.documentElement.dataset.playerX,
      playerDepth: document.documentElement.dataset.playerDepth,
      playerHp: document.documentElement.dataset.playerHp,
      dummyX: document.documentElement.dataset.dummyX,
      opponentAiActive: document.documentElement.dataset.opponentAiActive,
      opponentAiIntent: document.documentElement.dataset.opponentAiIntent,
      opponentAiDecisionTick: document.documentElement.dataset.opponentAiDecisionTick,
      opponentAiAttackCount: document.documentElement.dataset.opponentAiAttackCount,
      opponentAiHitCount: document.documentElement.dataset.opponentAiHitCount,
      opponentAiLastDamage: document.documentElement.dataset.opponentAiLastDamage,
      playerIncomingHitCount: document.documentElement.dataset.playerIncomingHitCount,
      lastPlayerIncomingDamage: document.documentElement.dataset.lastPlayerIncomingDamage,
      lastPlayerDamageDealt: document.documentElement.dataset.lastPlayerDamageDealt,
      lastPlayerHitCountered: document.documentElement.dataset.lastPlayerHitCountered,
    }));
    throw new Error(`Opponent AI did not land a hit: ${JSON.stringify(snapshot)}; cause=${String(error)}`);
  }

  const balancedDamage = await num('opponentAiLastDamage');
  if (balancedDamage <= 0) throw new Error('Balanced difficulty did not expose authoritative opponent damage');

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

  await page.evaluate(() => window.customFighterSelectOpponentProfile('training_pressure'));
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.appMode === 'single_player' &&
      document.documentElement.dataset.appOpponentProfile === 'training_pressure' &&
      document.documentElement.dataset.opponentAiProfile === 'training_pressure' &&
      document.documentElement.dataset.opponentAiActive === 'true' &&
      Math.abs(Number(document.documentElement.dataset.opponentAiReactionInterval) - 0.15) < 0.001 &&
      Math.abs(Number(document.documentElement.dataset.opponentAiBasicAttackRange) - 120) < 0.1 &&
      document.documentElement.dataset.opponentAiProfileSelectorVisible === 'true' &&
      document.documentElement.dataset.opponentAiProfileSelectorCount === '3' &&
      Number(document.documentElement.dataset.playerHp) === 100,
    null,
    { timeout: 60_000 },
  );

  await page.waitForFunction(
    () =>
      Number(document.documentElement.dataset.opponentAiHitCount) >= 1 &&
      Number(document.documentElement.dataset.opponentAiLastDamage) > 0,
    null,
    { timeout: 12_000 },
  );
  const pressureDamage = await num('opponentAiLastDamage');
  if (pressureDamage !== balancedDamage) {
    throw new Error(`Difficulty profile changed combat-authority damage: balanced=${balancedDamage} pressure=${pressureDamage}`);
  }

  await page.evaluate(() => window.customFighterSelectOpponentProfile('../unsafe-profile'));
  await page.waitForTimeout(300);
  const rejectedProfile = await page.evaluate(() => document.documentElement.dataset.opponentAiProfile);
  if (rejectedProfile !== 'training_pressure') {
    throw new Error(`Unsafe profile selection did not fail closed: profile=${rejectedProfile}`);
  }

  await page.evaluate(() => window.customFighterSelectOpponentProfile('training_cautious'));
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.appOpponentProfile === 'training_cautious' &&
      document.documentElement.dataset.opponentAiProfile === 'training_cautious' &&
      document.documentElement.dataset.opponentAiActive === 'true' &&
      Math.abs(Number(document.documentElement.dataset.opponentAiReactionInterval) - 0.45) < 0.001 &&
      Math.abs(Number(document.documentElement.dataset.opponentAiBasicAttackRange) - 150) < 0.1,
    null,
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
      document.documentElement.dataset.opponentAiProfileSelectorVisible === 'false' &&
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
    `WEB_OPPONENT_AI_SMOKE_PASSED activeMode=true approach=true attack=true playerDefeat=true restartPreserved=true difficultySelection=true profileCount=3 damageAuthorityStable=true balancedDamage=${balancedDamage} pressureDamage=${pressureDamage} passiveTraining=true`,
  );
} finally {
  await browser.close();
}
