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

async function moveForCharacterFrames(key, minimumFrames = 3) {
  const before = await readNumber('playerMovementAdjustmentFrames');
  await page.keyboard.down(key);
  try {
    await page.waitForFunction(
      ({ start, count }) =>
        Number(document.documentElement.dataset.playerMovementAdjustmentFrames ?? '0') >= start + count,
      { start: before, count: minimumFrames },
      { timeout: 2_500 },
    );
  } finally {
    await page.keyboard.up(key);
  }
  await page.waitForTimeout(60);
}

try {
  const response = await page.goto(baseUrl, { waitUntil: 'domcontentloaded', timeout: 60_000 });
  if (!response?.ok()) throw new Error(`Web build returned HTTP ${response?.status() ?? 'unknown'}`);

  await page.waitForFunction(
    () =>
      document.documentElement.dataset.godotReady === 'true' &&
      document.documentElement.dataset.playerCharacterLoaded === 'true' &&
      document.documentElement.dataset.playerVisualProfileLoaded === 'true' &&
      Number(document.documentElement.dataset.playerVisualProfileRenderCalls ?? '0') > 0,
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
    throw new Error(`Unexpected visual profile reference: ${await readText('playerCharacterVisualProfile')}`);
  }

  const loadedProfileId = await readText('playerVisualProfileId');
  const profileRenderCalls = await readNumber('playerVisualProfileRenderCalls');
  const profileBodyColor = await readText('playerVisualProfileBodyColor');
  const profileAccentColor = await readText('playerVisualProfileAccentColor');
  const profileHeadRadius = await readNumber('playerVisualProfileHeadRadius');
  const profileTorsoWidth = await readNumber('playerVisualProfileTorsoWidth');
  const profileTorsoHeight = await readNumber('playerVisualProfileTorsoHeight');
  const profileWeaponLength = await readNumber('playerVisualProfileWeaponLength');

  if (loadedProfileId !== 'training_blue' || loadedProfileId !== (await readText('playerCharacterVisualProfile'))) {
    throw new Error(
      `Visual profile did not resolve from CharacterDefinition: ref=${await readText('playerCharacterVisualProfile')} loaded=${loadedProfileId}`,
    );
  }
  if (profileBodyColor !== '#62d8ff' || profileAccentColor !== '#b8f3ff') {
    throw new Error(`Unexpected profile palette: body=${profileBodyColor} accent=${profileAccentColor}`);
  }
  if (profileHeadRadius !== 22 || profileTorsoWidth !== 36 || profileTorsoHeight !== 70 || profileWeaponLength !== 49) {
    throw new Error(
      `Unexpected profile body measurements: head=${profileHeadRadius} torso=${profileTorsoWidth}x${profileTorsoHeight} weapon=${profileWeaponLength}`,
    );
  }
  if (!(profileRenderCalls > 0)) {
    throw new Error(`Profile-backed renderer was not invoked: calls=${profileRenderCalls}`);
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

  await moveForCharacterFrames('d');
  const afterMoveX = await readNumber('playerX');
  const observedHorizontalSpeed = await readNumber('playerLastHorizontalSpeed');
  if (!(afterMoveX > initialX + 5)) {
    throw new Error(`Character-driven horizontal movement did not advance: ${afterMoveX - initialX}`);
  }
  if (Math.abs(observedHorizontalSpeed - moveSpeed) > moveSpeed * 0.08) {
    throw new Error(
      `Character-driven horizontal speed mismatch: expected=${moveSpeed} observed=${observedHorizontalSpeed}`,
    );
  }

  await moveForCharacterFrames('s');
  const afterMoveDepth = await readNumber('playerDepth');
  const observedDepthSpeed = await readNumber('playerLastDepthSpeed');
  if (!(afterMoveDepth > initialDepth + 0.005)) {
    throw new Error(`Character-driven depth movement did not advance: ${afterMoveDepth - initialDepth}`);
  }
  if (Math.abs(observedDepthSpeed - depthSpeed) > depthSpeed * 0.08) {
    throw new Error(
      `Character-driven depth speed mismatch: expected=${depthSpeed} observed=${observedDepthSpeed}`,
    );
  }

  if (pageErrors.length > 0 || consoleErrors.length > 0) {
    throw new Error(
      `Browser errors detected. pageErrors=${pageErrors.join(' | ')} consoleErrors=${consoleErrors.join(' | ')}`,
    );
  }

  console.log(
    `WEB_CHARACTER_PROFILE_SMOKE_PASSED id=${await readText('playerCharacterId')} profile=${loadedProfileId} renderCalls=${await readNumber('playerVisualProfileRenderCalls')} headRadius=${profileHeadRadius} torso=${profileTorsoWidth}x${profileTorsoHeight} weaponLength=${profileWeaponLength}`,
  );
  console.log(
    `WEB_CHARACTER_MOVEMENT_SMOKE_PASSED id=${await readText('playerCharacterId')} moveSpeed=${moveSpeed} observedHorizontalSpeed=${observedHorizontalSpeed.toFixed(2)} depthSpeed=${depthSpeed} observedDepthSpeed=${observedDepthSpeed.toFixed(3)} adjustmentFrames=${await readNumber('playerMovementAdjustmentFrames')}`,
  );
} finally {
  await browser.close();
}
