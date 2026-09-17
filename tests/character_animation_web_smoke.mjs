import { chromium } from 'playwright';

const baseUrl = process.env.CUSTOM_FIGHTER_WEB_URL ?? 'http://127.0.0.1:8000';
const browserChannel = process.env.BROWSER_CHANNEL?.trim();
const launchOptions = { headless: true };
if (browserChannel) launchOptions.channel = browserChannel;

console.log(`CHARACTER_ANIMATION_BROWSER=${browserChannel || 'playwright-chromium'}`);
console.log(`CHARACTER_ANIMATION_BASE_URL=${baseUrl}`);

function characterUrl(characterId) {
  const url = new URL(baseUrl);
  if (characterId) url.searchParams.set('character', characterId);
  return url.toString();
}

async function openCharacter(browser, characterId) {
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const url = characterUrl(characterId);
  const response = await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60_000 });
  if (!response?.ok()) throw new Error(`Animation character URL returned HTTP ${response?.status() ?? 'unknown'}: ${url}`);
  await page.waitForFunction(
    () => document.documentElement.dataset.godotReady === 'true',
    null,
    { timeout: 60_000 },
  );
  await page.waitForFunction(
    () => document.documentElement.dataset.playerAnimationMapLoaded === 'true',
    null,
    { timeout: 5_000 },
  );
  return page;
}

async function dataset(page, key) {
  return String(await page.evaluate((name) => document.documentElement.dataset[name] ?? '', key));
}

async function waitAnimation(page, semantic, animationId) {
  await page.waitForFunction(
    ({ expectedSemantic, expectedAnimation }) =>
      document.documentElement.dataset.playerAnimationSemantic === expectedSemantic &&
      document.documentElement.dataset.playerAnimationId === expectedAnimation,
    { expectedSemantic: semantic, expectedAnimation: animationId },
    { timeout: 5_000 },
  );
}

const browser = await chromium.launch(launchOptions);
try {
  const emberPage = await openCharacter(browser, null);
  const emberSnapshot = {
    selected: await dataset(emberPage, 'playerSelectedCharacterId'),
    characterMap: await dataset(emberPage, 'playerCharacterAnimationMap'),
    mapId: await dataset(emberPage, 'playerAnimationMapId'),
    semantic: await dataset(emberPage, 'playerAnimationSemantic'),
    animationId: await dataset(emberPage, 'playerAnimationId'),
    error: await dataset(emberPage, 'playerAnimationLoadError'),
  };
  if (
    emberSnapshot.selected !== 'ember_vanguard_001' ||
    emberSnapshot.characterMap !== 'ember_vanguard' ||
    emberSnapshot.mapId !== 'ember_vanguard' ||
    emberSnapshot.semantic !== 'ready' ||
    emberSnapshot.animationId !== 'ember_ready' ||
    emberSnapshot.error !== ''
  ) {
    throw new Error(`Ember animation mapping mismatch: ${JSON.stringify(emberSnapshot)}`);
  }
  await emberPage.close();

  const stormPage = await openCharacter(browser, 'storm_duelist_001');
  const stormSnapshot = {
    selected: await dataset(stormPage, 'playerSelectedCharacterId'),
    characterMap: await dataset(stormPage, 'playerCharacterAnimationMap'),
    mapId: await dataset(stormPage, 'playerAnimationMapId'),
    semantic: await dataset(stormPage, 'playerAnimationSemantic'),
    animationId: await dataset(stormPage, 'playerAnimationId'),
    error: await dataset(stormPage, 'playerAnimationLoadError'),
  };
  if (
    stormSnapshot.selected !== 'storm_duelist_001' ||
    stormSnapshot.characterMap !== 'storm_duelist' ||
    stormSnapshot.mapId !== 'storm_duelist' ||
    stormSnapshot.semantic !== 'ready' ||
    stormSnapshot.animationId !== 'storm_ready' ||
    stormSnapshot.error !== ''
  ) {
    throw new Error(`Storm animation mapping mismatch: ${JSON.stringify(stormSnapshot)}`);
  }

  await stormPage.keyboard.down('d');
  try {
    await waitAnimation(stormPage, 'walk', 'storm_walk');
  } finally {
    await stormPage.keyboard.up('d');
  }
  await waitAnimation(stormPage, 'ready', 'storm_ready');

  await stormPage.keyboard.down('j');
  try {
    await waitAnimation(stormPage, 'attack_1', 'storm_attack_1');
  } finally {
    await stormPage.keyboard.up('j');
  }
  await waitAnimation(stormPage, 'ready', 'storm_ready');

  await stormPage.keyboard.down('u');
  try {
    await waitAnimation(stormPage, 'skill_1', 'storm_skill_1');
  } finally {
    await stormPage.keyboard.up('u');
  }

  console.log('WEB_CHARACTER_ANIMATION_SMOKE_PASSED ember=ember_vanguard storm=storm_duelist states=ready,walk,attack_1,skill_1');
  await stormPage.close();
} finally {
  await browser.close();
}
