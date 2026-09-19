import { chromium } from 'playwright';

const baseUrl = process.env.CUSTOM_FIGHTER_WEB_URL ?? 'http://127.0.0.1:8000';
const browserChannel = process.env.BROWSER_CHANNEL?.trim();
const launchOptions = { headless: true };
if (browserChannel) launchOptions.channel = browserChannel;

console.log(`CREATOR_STUDIO_BROWSER=${browserChannel || 'playwright-chromium'}`);
console.log(`CREATOR_STUDIO_BASE_URL=${baseUrl}`);

async function dataset(page, key) {
  return String(await page.evaluate((name) => document.documentElement.dataset[name] ?? '', key));
}

const browser = await chromium.launch(launchOptions);
try {
  const trainingPage = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const trainingResponse = await trainingPage.goto(baseUrl, { waitUntil: 'domcontentloaded', timeout: 60_000 });
  if (!trainingResponse?.ok()) throw new Error(`Training URL returned HTTP ${trainingResponse?.status() ?? 'unknown'}`);
  await trainingPage.waitForFunction(
    () => document.documentElement.dataset.godotReady === 'true' && document.documentElement.dataset.appMode === 'training',
    null,
    { timeout: 60_000 },
  );
  await trainingPage.close();

  const creatorUrl = new URL(baseUrl);
  creatorUrl.searchParams.set('mode', 'creator');
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const response = await page.goto(creatorUrl.toString(), { waitUntil: 'domcontentloaded', timeout: 60_000 });
  if (!response?.ok()) throw new Error(`Creator URL returned HTTP ${response?.status() ?? 'unknown'}`);

  await page.waitForFunction(
    () =>
      document.documentElement.dataset.appMode === 'creator' &&
      document.documentElement.dataset.creatorStudioReady === 'true' &&
      typeof window.customFighterCreatorSetName === 'function' &&
      typeof window.customFighterCreatorSetAnimationMap === 'function' &&
      typeof window.customFighterCreatorSetAnimationSemantic === 'function' &&
      typeof window.customFighterCreatorSetMaxHp === 'function' &&
      typeof window.customFighterCreatorResetDraft === 'function',
    null,
    { timeout: 60_000 },
  );

  const initial = {
    editor: await dataset(page, 'creatorEditor'),
    valid: await dataset(page, 'creatorDraftValid'),
    id: await dataset(page, 'creatorDraftId'),
    name: await dataset(page, 'creatorDraftName'),
    animationMap: await dataset(page, 'creatorDraftAnimationMap'),
    animationDraftValid: await dataset(page, 'creatorAnimationDraftValid'),
    animationDraftMapId: await dataset(page, 'creatorAnimationDraftMapId'),
    animationDraftSemantic: await dataset(page, 'creatorAnimationDraftSemantic'),
    animationDraftAnimationId: await dataset(page, 'creatorAnimationDraftAnimationId'),
    hp: Number(await dataset(page, 'creatorDraftMaxHp')),
    mp: Number(await dataset(page, 'creatorDraftMaxMp')),
    speed: Number(await dataset(page, 'creatorDraftMoveSpeed')),
    error: await dataset(page, 'creatorDraftError'),
  };
  if (
    initial.editor !== 'character' ||
    initial.valid !== 'true' ||
    initial.id !== 'my_fighter_001' ||
    initial.name !== 'My Fighter' ||
    initial.animationMap !== 'ember_vanguard' ||
    initial.animationDraftValid !== 'true' ||
    initial.animationDraftMapId !== 'ember_vanguard' ||
    initial.animationDraftSemantic !== 'ready' ||
    initial.animationDraftAnimationId !== 'ember_ready' ||
    initial.hp !== 100 ||
    initial.mp !== 100 ||
    Math.abs(initial.speed - 360) > 0.01 ||
    initial.error !== ''
  ) {
    throw new Error(`Creator starter draft mismatch: ${JSON.stringify(initial)}`);
  }

  await page.evaluate(() => window.customFighterCreatorSetName(''));
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorDraftValid === 'false' &&
      (document.documentElement.dataset.creatorDraftError ?? '').includes('name must not be empty'),
    null,
    { timeout: 5_000 },
  );

  await page.evaluate(() => window.customFighterCreatorSetName('Nova Smith'));
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorDraftValid === 'true' &&
      document.documentElement.dataset.creatorDraftName === 'Nova Smith',
    null,
    { timeout: 5_000 },
  );

  await page.evaluate(() => window.customFighterCreatorSetAnimationMap('missing_animation_map'));
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorDraftValid === 'false' &&
      document.documentElement.dataset.creatorDraftAnimationMap === 'missing_animation_map' &&
      (document.documentElement.dataset.creatorDraftError ?? '').includes('animation map file is empty or missing'),
    null,
    { timeout: 5_000 },
  );

  await page.evaluate(() => window.customFighterCreatorSetAnimationMap('storm_duelist'));
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorDraftValid === 'true' &&
      document.documentElement.dataset.creatorDraftAnimationMap === 'storm_duelist',
    null,
    { timeout: 5_000 },
  );

  await page.evaluate(() => window.customFighterCreatorSetAnimationSemantic('attack_1', 'custom_attack_one'));
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorDraftValid === 'true' &&
      document.documentElement.dataset.creatorAnimationDraftValid === 'true' &&
      document.documentElement.dataset.creatorAnimationDraftSemantic === 'attack_1' &&
      document.documentElement.dataset.creatorAnimationDraftAnimationId === 'custom_attack_one',
    null,
    { timeout: 5_000 },
  );

  await page.evaluate(() => window.customFighterCreatorSetAnimationSemantic('attack_1', '../evil.gd'));
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorDraftValid === 'false' &&
      document.documentElement.dataset.creatorAnimationDraftValid === 'false' &&
      (document.documentElement.dataset.creatorDraftError ?? '').includes('safe lowercase token'),
    null,
    { timeout: 5_000 },
  );

  await page.evaluate(() => window.customFighterCreatorSetAnimationSemantic('attack_1', 'custom_attack_one'));
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorDraftValid === 'true' &&
      document.documentElement.dataset.creatorAnimationDraftValid === 'true' &&
      document.documentElement.dataset.creatorAnimationDraftAnimationId === 'custom_attack_one',
    null,
    { timeout: 5_000 },
  );

  await page.evaluate(() => window.customFighterCreatorSetMaxHp(0));
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorDraftValid === 'false' &&
      (document.documentElement.dataset.creatorDraftError ?? '').includes('max_hp must be between 1 and 10000'),
    null,
    { timeout: 5_000 },
  );

  await page.evaluate(() => window.customFighterCreatorSetMaxHp(180));
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorDraftValid === 'true' &&
      document.documentElement.dataset.creatorDraftMaxHp === '180',
    null,
    { timeout: 5_000 },
  );

  const revisionBeforeReset = Number(await dataset(page, 'creatorDraftRevision'));
  await page.evaluate(() => window.customFighterCreatorResetDraft());
  await page.waitForFunction(
    (previousRevision) =>
      document.documentElement.dataset.creatorDraftValid === 'true' &&
      document.documentElement.dataset.creatorDraftName === 'My Fighter' &&
      document.documentElement.dataset.creatorDraftAnimationMap === 'ember_vanguard' &&
      document.documentElement.dataset.creatorAnimationDraftValid === 'true' &&
      document.documentElement.dataset.creatorAnimationDraftMapId === 'ember_vanguard' &&
      document.documentElement.dataset.creatorAnimationDraftAnimationId === 'ember_attack_1' &&
      document.documentElement.dataset.creatorDraftMaxHp === '100' &&
      Number(document.documentElement.dataset.creatorDraftRevision ?? '0') > previousRevision,
    revisionBeforeReset,
    { timeout: 5_000 },
  );

  console.log('WEB_CREATOR_STUDIO_SMOKE_PASSED mode=creator valid-invalid-valid-reset animationMapAuthoring=true semanticAuthoring=true unsafeSemanticTokenBlocked=true missingMapBlocked=true trainingDefaultPreserved=true');
  await page.close();
} finally {
  await browser.close();
}
