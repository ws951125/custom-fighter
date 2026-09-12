import { chromium } from 'playwright';

const baseUrl = process.env.CUSTOM_FIGHTER_WEB_URL ?? 'http://127.0.0.1:8000';
const browserChannel = process.env.BROWSER_CHANNEL?.trim();
const launchOptions = { headless: true };
if (browserChannel) launchOptions.channel = browserChannel;

console.log(`CHARACTER_SELECTION_BROWSER=${browserChannel || 'playwright-chromium'}`);
console.log(`CHARACTER_SELECTION_BASE_URL=${baseUrl}`);

function characterUrl(characterId) {
  const url = new URL(baseUrl);
  if (characterId !== null) url.searchParams.set('character', characterId);
  return url.toString();
}

async function openCharacter(browser, characterId) {
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const url = characterUrl(characterId);
  const response = await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60_000 });
  if (!response?.ok()) throw new Error(`Character URL returned HTTP ${response?.status() ?? 'unknown'}: ${url}`);
  await page.waitForFunction(
    () => document.documentElement.dataset.godotReady === 'true',
    null,
    { timeout: 60_000 },
  );
  await page.waitForFunction(
    () => document.documentElement.dataset.playerCharacterRegistryLoaded === 'true',
    null,
    { timeout: 5_000 },
  );
  return page;
}

async function dataset(page, key) {
  return String(await page.evaluate((name) => document.documentElement.dataset[name] ?? '', key));
}

const browser = await chromium.launch(launchOptions);
try {
  const defaultPage = await openCharacter(browser, null);
  if ((await dataset(defaultPage, 'playerSelectedCharacterId')) !== 'ember_vanguard_001') {
    throw new Error(`Default character mismatch: ${await dataset(defaultPage, 'playerSelectedCharacterId')}`);
  }
  if ((await dataset(defaultPage, 'playerCharacterRegistryDefault')) !== 'ember_vanguard_001') {
    throw new Error('Character registry default mismatch');
  }
  if ((await dataset(defaultPage, 'playerCharacterSelectionFallback')) !== 'false') {
    throw new Error('Default character unexpectedly used selection fallback');
  }
  await defaultPage.close();

  const stormPage = await openCharacter(browser, 'storm_duelist_001');
  const stormSnapshot = {
    requested: await dataset(stormPage, 'playerRequestedCharacterId'),
    selected: await dataset(stormPage, 'playerSelectedCharacterId'),
    id: await dataset(stormPage, 'playerCharacterId'),
    name: await dataset(stormPage, 'playerCharacterName'),
    archetype: await dataset(stormPage, 'playerCharacterArchetype'),
    maxHp: Number(await dataset(stormPage, 'playerCharacterMaxHp')),
    maxMp: Number(await dataset(stormPage, 'playerCharacterMaxMp')),
    moveSpeed: Number(await dataset(stormPage, 'playerCharacterMoveSpeed')),
    profile: await dataset(stormPage, 'playerCharacterVisualProfile'),
    profileLoaded: await dataset(stormPage, 'playerVisualProfileLoaded'),
    characterSkill1: await dataset(stormPage, 'playerCharacterSkill1'),
    runtimeSkill1: await dataset(stormPage, 'playerRuntimeSkill1'),
    loadoutReady: await dataset(stormPage, 'playerSkillLoadoutReady'),
    fallback: await dataset(stormPage, 'playerCharacterSelectionFallback'),
    error: await dataset(stormPage, 'playerCharacterSelectionError'),
    source: await dataset(stormPage, 'playerCharacterSource'),
  };
  if (
    stormSnapshot.requested !== 'storm_duelist_001' ||
    stormSnapshot.selected !== 'storm_duelist_001' ||
    stormSnapshot.id !== 'storm_duelist_001' ||
    stormSnapshot.name !== 'Storm Duelist' ||
    stormSnapshot.archetype !== 'agile' ||
    stormSnapshot.maxHp !== 90 ||
    stormSnapshot.maxMp !== 120 ||
    Math.abs(stormSnapshot.moveSpeed - 405) > 0.01 ||
    stormSnapshot.profile !== 'storm_violet' ||
    stormSnapshot.profileLoaded !== 'true' ||
    stormSnapshot.characterSkill1 !== 'training_bolt_001' ||
    stormSnapshot.runtimeSkill1 !== 'training_bolt_001' ||
    stormSnapshot.loadoutReady !== 'true' ||
    stormSnapshot.fallback !== 'false' ||
    stormSnapshot.error !== '' ||
    !stormSnapshot.source.endsWith('/storm_duelist.sample.json')
  ) {
    throw new Error(`Storm Duelist runtime mismatch: ${JSON.stringify(stormSnapshot)}`);
  }
  await stormPage.close();

  const invalidPage = await openCharacter(browser, '../evil.gd');
  const invalidSnapshot = {
    requested: await dataset(invalidPage, 'playerRequestedCharacterId'),
    selected: await dataset(invalidPage, 'playerSelectedCharacterId'),
    fallback: await dataset(invalidPage, 'playerCharacterSelectionFallback'),
    error: await dataset(invalidPage, 'playerCharacterSelectionError'),
  };
  if (
    invalidSnapshot.requested !== '../evil.gd' ||
    invalidSnapshot.selected !== 'ember_vanguard_001' ||
    invalidSnapshot.fallback !== 'true' ||
    !invalidSnapshot.error.includes('character id must be a safe lowercase token')
  ) {
    throw new Error(`Invalid character fallback mismatch: ${JSON.stringify(invalidSnapshot)}`);
  }
  await invalidPage.close();

  console.log('WEB_CHARACTER_SELECTION_SMOKE_PASSED default=ember_vanguard_001 alternate=storm_duelist_001 invalidFallback=ember_vanguard_001');
} finally {
  await browser.close();
}
