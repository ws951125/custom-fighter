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

async function newTrackedPage(browser) {
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

  return { page, pageErrors, consoleErrors, requestFailures };
}

async function openCompetitive(browser, characterId) {
  const context = await newTrackedPage(browser);
  const url = modeUrl(characterId);
  const response = await context.page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60_000 });
  if (!response?.ok()) throw new Error(`Competitive URL returned HTTP ${response?.status() ?? 'unknown'}: ${url}`);
  await context.page.waitForFunction(
    () =>
      document.documentElement.dataset.godotReady === 'true' &&
      document.documentElement.dataset.appRouterReady === 'true',
    null,
    { timeout: 60_000 },
  );
  return context;
}

async function openSandboxOverspecPreview(browser) {
  const context = await newTrackedPage(browser);
  const creatorUrl = new URL(baseUrl);
  creatorUrl.searchParams.set('mode', 'creator');
  const response = await context.page.goto(creatorUrl.toString(), {
    waitUntil: 'domcontentloaded',
    timeout: 60_000,
  });
  if (!response?.ok()) throw new Error(`Creator URL returned HTTP ${response?.status() ?? 'unknown'}`);

  await context.page.waitForFunction(
    () =>
      document.documentElement.dataset.appMode === 'creator' &&
      document.documentElement.dataset.creatorStudioReady === 'true' &&
      document.documentElement.dataset.creatorPreviewReady === 'true' &&
      typeof window.customFighterCreatorSetName === 'function' &&
      typeof window.customFighterCreatorSetMaxHp === 'function' &&
      typeof window.customFighterCreatorSetSkillName === 'function' &&
      typeof window.customFighterCreatorSetSkillDamage === 'function' &&
      typeof window.customFighterCreatorSetSkillMpCost === 'function' &&
      typeof window.customFighterCreatorSetSkillCooldown === 'function' &&
      typeof window.customFighterCreatorPreview === 'function',
    null,
    { timeout: 60_000 },
  );

  await context.page.evaluate(() => {
    window.customFighterCreatorSetName('WU6 Sandbox Overspec');
    window.customFighterCreatorSetMaxHp(222);
    window.customFighterCreatorSetSkillName('WU6 Overspec Projectile');
    window.customFighterCreatorSetSkillDamage(41);
    window.customFighterCreatorSetSkillMpCost(4);
    window.customFighterCreatorSetSkillCooldown(0.25);
  });

  await context.page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorDraftMaxHp === '222' &&
      document.documentElement.dataset.creatorSkillDraftDamage === '41' &&
      document.documentElement.dataset.creatorSkillDraftMpCost === '4' &&
      Math.abs(Number(document.documentElement.dataset.creatorSkillDraftCooldown) - 0.25) < 0.001 &&
      document.documentElement.dataset.creatorPreviewCanLaunch === 'true',
    null,
    { timeout: 10_000 },
  );

  await context.page.evaluate(() => window.customFighterCreatorPreview());
  await context.page.waitForFunction(
    () =>
      document.documentElement.dataset.appMode === 'training' &&
      document.documentElement.dataset.creatorPreviewActive === 'true' &&
      document.documentElement.dataset.playerCharacterSource === 'creator_preview_session' &&
      document.documentElement.dataset.playerCharacterMaxHp === '222' &&
      document.documentElement.dataset.creatorPreviewRuntimeSkillDamage === '41' &&
      document.documentElement.dataset.creatorPreviewRuntimeSkillMpCost === '4' &&
      Math.abs(Number(document.documentElement.dataset.creatorPreviewRuntimeSkillCooldown) - 0.25) < 0.001,
    null,
    { timeout: 60_000 },
  );

  return context;
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
  const sandbox = await openSandboxOverspecPreview(browser);
  const sandboxSnapshot = {
    mode: await dataset(sandbox.page, 'appMode'),
    source: await dataset(sandbox.page, 'playerCharacterSource'),
    maxHp: Number(await dataset(sandbox.page, 'playerCharacterMaxHp')),
    damage: Number(await dataset(sandbox.page, 'creatorPreviewRuntimeSkillDamage')),
    mpCost: Number(await dataset(sandbox.page, 'creatorPreviewRuntimeSkillMpCost')),
    cooldown: Number(await dataset(sandbox.page, 'creatorPreviewRuntimeSkillCooldown')),
  };
  if (
    sandboxSnapshot.mode !== 'training' ||
    sandboxSnapshot.source !== 'creator_preview_session' ||
    sandboxSnapshot.maxHp !== 222 ||
    sandboxSnapshot.damage !== 41 ||
    sandboxSnapshot.mpCost !== 4 ||
    Math.abs(sandboxSnapshot.cooldown - 0.25) >= 0.001
  ) {
    throw new Error(`Sandbox-safe overspec preview mismatch: ${JSON.stringify(sandboxSnapshot)}`);
  }
  assertNoBrowserErrors(sandbox, 'sandbox-overspec');
  await sandbox.page.close();

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
    authoritySkill1: await dataset(ember.page, 'competitiveAuthoritySkill1Id'),
    authoritySkill1Damage: Number(await dataset(ember.page, 'competitiveAuthoritySkill1Damage')),
    authoritySkill1MpCost: Number(await dataset(ember.page, 'competitiveAuthoritySkill1MpCost')),
    authoritySkill1Cooldown: Number(await dataset(ember.page, 'competitiveAuthoritySkill1Cooldown')),
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
    emberSnapshot.authoritySkill1 !== 'fireball_001' ||
    emberSnapshot.authoritySkill1Damage !== 18 ||
    emberSnapshot.authoritySkill1MpCost !== 25 ||
    Math.abs(emberSnapshot.authoritySkill1Cooldown - 1.8) >= 0.001 ||
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
    `V2_5_COMPETITIVE_CROSS_BROWSER_ACCEPTANCE_PASSED sandboxHp=${sandboxSnapshot.maxHp} sandboxDamage=${sandboxSnapshot.damage} sandboxMpCost=${sandboxSnapshot.mpCost} sandboxCooldown=${sandboxSnapshot.cooldown} emberFingerprint=${emberSnapshot.fingerprint} emberDamage=${emberSnapshot.authoritySkill1Damage} emberMpCost=${emberSnapshot.authoritySkill1MpCost} emberCooldown=${emberSnapshot.authoritySkill1Cooldown} stormFingerprint=${stormFingerprint} invalidFailClosed=true`,
  );
  console.log(
    `COMPETITIVE_LOCAL_WEB_SMOKE_PASSED emberFingerprint=${emberSnapshot.fingerprint} stormFingerprint=${stormFingerprint} invalidFailClosed=true`,
  );
} finally {
  await browser.close();
}
