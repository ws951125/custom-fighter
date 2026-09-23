import { chromium } from 'playwright';

const baseUrl = process.env.CUSTOM_FIGHTER_WEB_URL ?? 'http://127.0.0.1:8000';
const browserChannel = process.env.BROWSER_CHANNEL?.trim();
const launchOptions = { headless: true };
if (browserChannel) launchOptions.channel = browserChannel;

const EMBER_FINGERPRINT = '56451d3bdf1c7bf74852a3620894667730ddb088f350eb598badfa74c6d3c28e';
const STORM_FINGERPRINT = '5822c6cfb4737c29007f2450a598c501b79c17d8ed9a432e4327976cc6a7026e';

console.log(`COMPETITIVE_LOCAL_BROWSER=${browserChannel || 'playwright-chromium'}`);
console.log(`COMPETITIVE_LOCAL_BASE_URL=${baseUrl}`);

function modeUrl(characterId) {
  const url = new URL(baseUrl);
  url.searchParams.set('mode', 'competitive_local');
  if (characterId !== null) url.searchParams.set('character', characterId);
  return url.toString();
}

async function openCompetitive(browser, characterId) {
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const pageErrors = [];
  const consoleErrors = [];
  const requestFailures = [];

  page.on('pageerror', (error) => {
    const detail = error?.stack || error?.message || String(error);
    pageErrors.push(detail);
    console.error(`[pageerror] ${detail}`);
  });
  page.on('console', (message) => {
    console.log(`[browser ${message.type()}] ${message.text()}`);
    if (message.type() === 'error') consoleErrors.push(message.text());
  });
  page.on('requestfailed', (request) => {
    const detail = `${request.url()} :: ${request.failure()?.errorText ?? 'unknown'}`;
    requestFailures.push(detail);
    console.error(`[requestfailed] ${detail}`);
  });

  const url = modeUrl(characterId);
  const response = await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60_000 });
  if (!response?.ok()) throw new Error(`Competitive URL returned HTTP ${response?.status() ?? 'unknown'}: ${url}`);
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.godotReady === 'true' &&
      document.documentElement.dataset.appRouterReady === 'true',
    null,
    { timeout: 60_000 },
  );
  return { page, pageErrors, consoleErrors, requestFailures };
}

async function dataset(page, key) {
  return String(await page.evaluate((name) => document.documentElement.dataset[name] ?? '', key));
}

function assertNoBrowserErrors(context, label) {
  if (context.pageErrors.length || context.consoleErrors.length || context.requestFailures.length) {
    throw new Error(
      `${label} browser errors: page=${context.pageErrors.join(' | ')} console=${context.consoleErrors.join(' | ')} request=${context.requestFailures.join(' | ')}`,
    );
  }
}

const browser = await chromium.launch(launchOptions);
try {
  const ember = await openCompetitive(browser, 'ember_vanguard_001');
  await ember.page.waitForFunction(
    () =>
      document.documentElement.dataset.competitiveAuthorityActive === 'true' &&
      document.documentElement.dataset.competitiveAuthorityAdmitted === 'true' &&
      document.documentElement.dataset.playerSkillLoadoutReady === 'true',
    null,
    { timeout: 10_000 },
  );

  const emberSnapshot = {
    mode: await dataset(ember.page, 'appMode'),
    admitted: await dataset(ember.page, 'competitiveAuthorityAdmitted'),
    fingerprint: await dataset(ember.page, 'competitiveAuthorityFingerprint'),
    ruleset: await dataset(ember.page, 'competitiveAuthorityRulesetId'),
    rulesetVersion: Number(await dataset(ember.page, 'competitiveAuthorityRulesetVersion')),
    budget: await dataset(ember.page, 'competitiveAuthorityPowerBudgetId'),
    authorityCharacter: await dataset(ember.page, 'competitiveAuthorityCharacterId'),
    selectedCharacter: await dataset(ember.page, 'playerSelectedCharacterId'),
    source: await dataset(ember.page, 'playerCharacterSource'),
    maxHp: Number(await dataset(ember.page, 'playerCharacterMaxHp')),
    maxMp: Number(await dataset(ember.page, 'playerCharacterMaxMp')),
    runtimeSkill1: await dataset(ember.page, 'playerRuntimeSkill1'),
    runtimeSkill1Source: await dataset(ember.page, 'playerRuntimeSkill1Source'),
    inputEnabled: await dataset(ember.page, 'competitiveRuntimeInputEnabled'),
    diagnostics: await dataset(ember.page, 'competitiveAuthorityDiagnostics'),
  };

  if (
    emberSnapshot.mode !== 'competitive_local' ||
    emberSnapshot.admitted !== 'true' ||
    emberSnapshot.fingerprint !== EMBER_FINGERPRINT ||
    emberSnapshot.ruleset !== 'competitive_standard' ||
    emberSnapshot.rulesetVersion !== 1 ||
    emberSnapshot.budget !== 'competitive_standard_v1' ||
    emberSnapshot.authorityCharacter !== 'ember_vanguard_001' ||
    emberSnapshot.selectedCharacter !== 'ember_vanguard_001' ||
    !emberSnapshot.source.startsWith('competitive_authority_snapshot:') ||
    emberSnapshot.maxHp !== 100 ||
    emberSnapshot.maxMp !== 100 ||
    emberSnapshot.runtimeSkill1 !== 'fireball_001' ||
    !emberSnapshot.runtimeSkill1Source.startsWith('competitive_authority_snapshot:') ||
    emberSnapshot.inputEnabled !== 'true' ||
    emberSnapshot.diagnostics !== ''
  ) {
    throw new Error(`Ember competitive authority mismatch: ${JSON.stringify(emberSnapshot)}`);
  }
  assertNoBrowserErrors(ember, 'ember');
  await ember.page.close();

  const storm = await openCompetitive(browser, 'storm_duelist_001');
  await storm.page.waitForFunction(
    () => document.documentElement.dataset.competitiveAuthorityAdmitted === 'true',
    null,
    { timeout: 10_000 },
  );
  const stormFingerprint = await dataset(storm.page, 'competitiveAuthorityFingerprint');
  const stormSnapshot = {
    selected: await dataset(storm.page, 'playerSelectedCharacterId'),
    authorityCharacter: await dataset(storm.page, 'competitiveAuthorityCharacterId'),
    maxHp: Number(await dataset(storm.page, 'playerCharacterMaxHp')),
    maxMp: Number(await dataset(storm.page, 'playerCharacterMaxMp')),
    runtimeSkill1: await dataset(storm.page, 'playerRuntimeSkill1'),
    inputEnabled: await dataset(storm.page, 'competitiveRuntimeInputEnabled'),
  };
  if (
    stormSnapshot.selected !== 'storm_duelist_001' ||
    stormSnapshot.authorityCharacter !== 'storm_duelist_001' ||
    stormSnapshot.maxHp !== 90 ||
    stormSnapshot.maxMp !== 120 ||
    stormSnapshot.runtimeSkill1 !== 'training_bolt_001' ||
    stormSnapshot.inputEnabled !== 'true' ||
    stormFingerprint !== STORM_FINGERPRINT ||
    stormFingerprint === emberSnapshot.fingerprint
  ) {
    throw new Error(`Storm competitive authority mismatch: ${JSON.stringify({ ...stormSnapshot, stormFingerprint })}`);
  }
  assertNoBrowserErrors(storm, 'storm');
  await storm.page.close();

  const rejected = await openCompetitive(browser, '../evil.gd');
  await rejected.page.waitForFunction(
    () => document.documentElement.dataset.competitiveAuthorityActive === 'true',
    null,
    { timeout: 10_000 },
  );
  const rejectedSnapshot = {
    admitted: await dataset(rejected.page, 'competitiveAuthorityAdmitted'),
    fingerprint: await dataset(rejected.page, 'competitiveAuthorityFingerprint'),
    source: await dataset(rejected.page, 'playerCharacterSource'),
    loaded: await dataset(rejected.page, 'playerCharacterLoaded'),
    inputEnabled: await dataset(rejected.page, 'competitiveRuntimeInputEnabled'),
    diagnostics: await dataset(rejected.page, 'competitiveAuthorityDiagnostics'),
  };
  if (
    rejectedSnapshot.admitted !== 'false' ||
    rejectedSnapshot.fingerprint !== '' ||
    rejectedSnapshot.source !== 'competitive_authority_rejected' ||
    rejectedSnapshot.loaded !== 'false' ||
    rejectedSnapshot.inputEnabled !== 'false' ||
    !rejectedSnapshot.diagnostics.includes('SNAPSHOT_ADMISSION_FAILED') ||
    !rejectedSnapshot.diagnostics.includes('SNAPSHOT:CHARACTER_RESOLUTION_FAILED')
  ) {
    throw new Error(`Rejected competitive loadout did not fail closed: ${JSON.stringify(rejectedSnapshot)}`);
  }
  // The rejected path intentionally emits a Godot push_error; that diagnostic is expected.
  if (rejected.pageErrors.length || rejected.requestFailures.length) {
    throw new Error(
      `Rejected competitive page had unexpected transport/runtime errors: page=${rejected.pageErrors.join(' | ')} request=${rejected.requestFailures.join(' | ')}`,
    );
  }
  await rejected.page.close();

  console.log(
    `COMPETITIVE_LOCAL_WEB_SMOKE_PASSED emberFingerprint=${emberSnapshot.fingerprint} stormFingerprint=${stormFingerprint} deterministicAcrossBrowserContract=true invalidFailClosed=true`,
  );
} finally {
  await browser.close();
}
