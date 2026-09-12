import { chromium } from 'playwright';

const baseUrl = process.env.CUSTOM_FIGHTER_WEB_URL ?? 'http://127.0.0.1:8000';
const browserChannel = process.env.BROWSER_CHANNEL?.trim();
const launchOptions = { headless: true };
if (browserChannel) launchOptions.channel = browserChannel;

console.log(`CHARACTER_SMOKE_BROWSER=${browserChannel || 'playwright-chromium'}`);
console.log(`CHARACTER_SMOKE_URL=${baseUrl}`);

const browser = await chromium.launch(launchOptions);
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const pageErrors = [];
const consoleErrors = [];

page.on('pageerror', (error) => pageErrors.push(error?.stack || error?.message || String(error)));
page.on('console', (message) => {
  if (message.type() === 'error') consoleErrors.push(message.text());
});

async function readText(key) {
  return String(await page.evaluate((name) => document.documentElement.dataset[name] ?? '', key));
}

async function readNumber(key) {
  return Number(await page.evaluate((name) => document.documentElement.dataset[name] ?? 'NaN', key));
}

try {
  const response = await page.goto(baseUrl, { waitUntil: 'domcontentloaded', timeout: 60_000 });
  if (!response?.ok()) throw new Error(`Web build returned HTTP ${response?.status() ?? 'unknown'}`);

  await page.waitForFunction(
    () =>
      document.documentElement.dataset.godotReady === 'true' &&
      document.documentElement.dataset.playerCharacterLoaded === 'true',
    null,
    { timeout: 60_000 },
  );

  const expectedSlots = [
    'fireball_001',
    'dash_slash_001',
    'arc_burst_001',
    'blade_rain_001',
    'battle_focus_001',
    'heavy_strike_001',
  ];

  if ((await readText('playerCharacterId')) !== 'ember_vanguard_001') {
    throw new Error(`Unexpected character id: ${await readText('playerCharacterId')}`);
  }
  if ((await readText('playerCharacterName')) !== 'Ember Vanguard') {
    throw new Error(`Unexpected character name: ${await readText('playerCharacterName')}`);
  }
  if ((await readText('playerCharacterArchetype')) !== 'balanced') {
    throw new Error(`Unexpected archetype: ${await readText('playerCharacterArchetype')}`);
  }
  if ((await readText('playerCharacterVisualProfile')) !== 'training_blue') {
    throw new Error(`Unexpected visual profile: ${await readText('playerCharacterVisualProfile')}`);
  }

  if ((await readNumber('playerHp')) !== 100 || (await readNumber('playerMaxHp')) !== 100) {
    throw new Error(`Character HP not applied: hp=${await readNumber('playerHp')} max=${await readNumber('playerMaxHp')}`);
  }
  if ((await readNumber('playerMp')) !== 100 || (await readNumber('playerMaxMp')) !== 100) {
    throw new Error(`Character MP not applied: mp=${await readNumber('playerMp')} max=${await readNumber('playerMaxMp')}`);
  }
  if ((await readNumber('playerCharacterMaxHp')) !== 100 || (await readNumber('playerCharacterMaxMp')) !== 100) {
    throw new Error('Character resource diagnostics do not match runtime resources');
  }

  const moveSpeed = await readNumber('playerCharacterMoveSpeed');
  const depthSpeed = await readNumber('playerCharacterDepthSpeed');
  const runMultiplier = await readNumber('playerCharacterRunMultiplier');
  const guardMultiplier = await readNumber('playerCharacterGuardMoveMultiplier');
  if (moveSpeed !== 360 || depthSpeed !== 0.72 || runMultiplier !== 1.6 || guardMultiplier !== 0.35) {
    throw new Error(
      `Unexpected movement tuning diagnostics: move=${moveSpeed} depth=${depthSpeed} run=${runMultiplier} guard=${guardMultiplier}`,
    );
  }

  if ((await readText('playerMovementSource')) !== 'character') {
    throw new Error(`Runtime movement is not character-driven: source=${await readText('playerMovementSource')}`);
  }
  const runtimeMoveSpeed = await readNumber('playerRuntimeMoveSpeed');
  const runtimeDepthSpeed = await readNumber('playerRuntimeDepthSpeed');
  const runtimeRunMultiplier = await readNumber('playerRuntimeRunMultiplier');
  const runtimeGuardMultiplier = await readNumber('playerRuntimeGuardMoveMultiplier');
  if (
    runtimeMoveSpeed !== moveSpeed ||
    runtimeDepthSpeed !== depthSpeed ||
    runtimeRunMultiplier !== runMultiplier ||
    runtimeGuardMultiplier !== guardMultiplier
  ) {
    throw new Error(
      `Runtime movement tuning diverged from CharacterDefinition: runtime=${runtimeMoveSpeed}/${runtimeDepthSpeed}/${runtimeRunMultiplier}/${runtimeGuardMultiplier}`,
    );
  }

  for (let index = 0; index < expectedSlots.length; index += 1) {
    const actual = await readText(`playerCharacterSkill${index + 1}`);
    if (actual !== expectedSlots[index]) {
      throw new Error(`Unexpected skill slot ${index + 1}: ${actual}`);
    }
  }

  const initialX = await readNumber('playerX');
  const initialDepth = await readNumber('playerDepth');
  const initialAdjustmentFrames = await readNumber('playerMovementAdjustmentFrames');

  await page.keyboard.down('d');
  await page.waitForTimeout(180);
  await page.keyboard.up('d');
  await page.waitForFunction(
    (before) => Number(document.documentElement.dataset.playerMovementAdjustmentFrames ?? '0') > before,
    initialAdjustmentFrames,
    { timeout: 2_000 },
  );
  const afterMoveX = await readNumber('playerX');
  if (!(afterMoveX > initialX + 30)) {
    throw new Error(`Character-driven horizontal movement too small: ${afterMoveX - initialX}`);
  }

  const framesAfterHorizontal = await readNumber('playerMovementAdjustmentFrames');
  await page.keyboard.down('s');
  await page.waitForTimeout(140);
  await page.keyboard.up('s');
  await page.waitForFunction(
    (before) => Number(document.documentElement.dataset.playerMovementAdjustmentFrames ?? '0') > before,
    framesAfterHorizontal,
    { timeout: 2_000 },
  );
  const afterMoveDepth = await readNumber('playerDepth');
  if (!(afterMoveDepth > initialDepth + 0.04)) {
    throw new Error(`Character-driven depth movement too small: ${afterMoveDepth - initialDepth}`);
  }

  if (pageErrors.length > 0 || consoleErrors.length > 0) {
    throw new Error(
      `Browser errors detected. pageErrors=${pageErrors.join(' | ')} consoleErrors=${consoleErrors.join(' | ')}`,
    );
  }

  console.log(
    `WEB_CHARACTER_MOVEMENT_SMOKE_PASSED id=${await readText('playerCharacterId')} moveSpeed=${moveSpeed} depthSpeed=${depthSpeed} horizontalDelta=${(afterMoveX - initialX).toFixed(2)} depthDelta=${(afterMoveDepth - initialDepth).toFixed(3)} adjustmentFrames=${await readNumber('playerMovementAdjustmentFrames')}`,
  );
} finally {
  await browser.close();
}
