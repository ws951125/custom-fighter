import { chromium } from 'playwright';

const baseUrl = process.env.CUSTOM_FIGHTER_WEB_URL ?? 'http://127.0.0.1:8000';
const browserChannel = process.env.BROWSER_CHANNEL?.trim();
const launchOptions = { headless: true };
if (browserChannel) launchOptions.channel = browserChannel;

console.log(`CREATOR_VFX_RUNTIME_BROWSER=${browserChannel || 'playwright-chromium'}`);
console.log(`CREATOR_VFX_RUNTIME_BASE_URL=${baseUrl}`);

function modeUrl(mode) {
  const url = new URL(baseUrl);
  url.searchParams.set('mode', mode);
  return url.toString();
}

async function dataset(page, key) {
  return String(await page.evaluate((name) => document.documentElement.dataset[name] ?? '', key));
}

async function waitForRevision(page, key, before) {
  await page.waitForFunction(
    ({ datasetKey, previous }) => Number(document.documentElement.dataset[datasetKey] ?? '0') > previous,
    { datasetKey: key, previous: before },
    { timeout: 5_000 },
  );
}

const browser = await chromium.launch(launchOptions);
try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const response = await page.goto(modeUrl('creator'), { waitUntil: 'domcontentloaded', timeout: 60_000 });
  if (!response?.ok()) throw new Error(`Creator URL returned HTTP ${response?.status() ?? 'unknown'}`);

  await page.waitForFunction(
    () =>
      document.documentElement.dataset.appMode === 'creator' &&
      document.documentElement.dataset.creatorStudioReady === 'true' &&
      document.documentElement.dataset.creatorPreviewReady === 'true' &&
      typeof window.customFighterCreatorPreview === 'function' &&
      typeof window.customFighterCreatorOpenVfx === 'function' &&
      typeof window.customFighterCreatorSetName === 'function' &&
      typeof window.customFighterCreatorSetMaxHp === 'function' &&
      typeof window.customFighterCreatorSetSkillName === 'function' &&
      typeof window.customFighterCreatorSetSkillDamage === 'function' &&
      typeof window.customFighterCreatorSetSkillMpCost === 'function' &&
      typeof window.customFighterCreatorSetSkillCooldown === 'function',
    null,
    { timeout: 60_000 },
  );

  await page.evaluate(() => {
    window.customFighterCreatorSetName('VFX Nova');
    window.customFighterCreatorSetMaxHp(180);
    window.customFighterCreatorSetSkillName('Prism Bolt');
    window.customFighterCreatorSetSkillDamage(33);
    window.customFighterCreatorSetSkillMpCost(17);
    window.customFighterCreatorSetSkillCooldown(2.4);
  });
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorDraftValid === 'true' &&
      document.documentElement.dataset.creatorSkillDraftValid === 'true' &&
      document.documentElement.dataset.creatorDraftName === 'VFX Nova' &&
      document.documentElement.dataset.creatorDraftMaxHp === '180' &&
      document.documentElement.dataset.creatorSkillDraftName === 'Prism Bolt' &&
      document.documentElement.dataset.creatorSkillDraftDamage === '33' &&
      document.documentElement.dataset.creatorSkillDraftMpCost === '17' &&
      Math.abs(Number(document.documentElement.dataset.creatorSkillDraftCooldown) - 2.4) < 0.001,
    null,
    { timeout: 5_000 },
  );

  await page.evaluate(() => window.customFighterCreatorOpenVfx());
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.appMode === 'vfx' &&
      document.documentElement.dataset.creatorVfxReady === 'true' &&
      typeof window.customFighterCreatorVfxImportPng === 'function' &&
      typeof window.customFighterCreatorVfxSetFrameCount === 'function' &&
      typeof window.customFighterCreatorVfxSetFps === 'function' &&
      typeof window.customFighterCreatorVfxSetScale === 'function' &&
      typeof window.customFighterCreatorVfxSetOffset === 'function' &&
      typeof window.customFighterCreatorVfxBackToCreator === 'function',
    null,
    { timeout: 60_000 },
  );

  let revision = Number(await dataset(page, 'creatorVfxRevision'));
  await page.evaluate(() => {
    const canvas = document.createElement('canvas');
    canvas.width = 16;
    canvas.height = 4;
    const context = canvas.getContext('2d');
    const colors = ['#ff2200', '#ffcc00', '#00ddff', '#aa33ff'];
    colors.forEach((color, index) => {
      context.fillStyle = color;
      context.fillRect(index * 4, 0, 4, 4);
    });
    window.customFighterCreatorVfxImportPng('runtime-strip.png', 'image/png', canvas.toDataURL('image/png'));
  });
  await waitForRevision(page, 'creatorVfxRevision', revision);
  if ((await dataset(page, 'creatorVfxValid')) !== 'true') {
    throw new Error(`Imported VFX should validate: ${await dataset(page, 'creatorVfxError')}`);
  }

  revision = Number(await dataset(page, 'creatorVfxRevision'));
  await page.evaluate(() => window.customFighterCreatorVfxSetFrameCount(4));
  await waitForRevision(page, 'creatorVfxRevision', revision);
  revision = Number(await dataset(page, 'creatorVfxRevision'));
  await page.evaluate(() => window.customFighterCreatorVfxSetFps(20));
  await waitForRevision(page, 'creatorVfxRevision', revision);
  revision = Number(await dataset(page, 'creatorVfxRevision'));
  await page.evaluate(() => window.customFighterCreatorVfxSetScale(2));
  await waitForRevision(page, 'creatorVfxRevision', revision);
  revision = Number(await dataset(page, 'creatorVfxRevision'));
  await page.evaluate(() => window.customFighterCreatorVfxSetOffset(12, -8));
  await waitForRevision(page, 'creatorVfxRevision', revision);

  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorVfxValid === 'true' &&
      document.documentElement.dataset.creatorVfxFrameCount === '4' &&
      document.documentElement.dataset.creatorVfxFrameWidth === '4' &&
      Math.abs(Number(document.documentElement.dataset.creatorVfxScale) - 2) < 0.001 &&
      Math.abs(Number(document.documentElement.dataset.creatorVfxOffsetX) - 12) < 0.001 &&
      Math.abs(Number(document.documentElement.dataset.creatorVfxOffsetY) + 8) < 0.001 &&
      Math.abs(Number(document.documentElement.dataset.creatorVfxFps) - 20) < 0.001,
    null,
    { timeout: 5_000 },
  );

  await page.evaluate(() => window.customFighterCreatorVfxBackToCreator());
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.appMode === 'creator' &&
      document.documentElement.dataset.creatorStudioReady === 'true' &&
      document.documentElement.dataset.creatorPreviewReady === 'true' &&
      document.documentElement.dataset.creatorDraftName === 'VFX Nova' &&
      document.documentElement.dataset.creatorDraftMaxHp === '180' &&
      document.documentElement.dataset.creatorSkillDraftName === 'Prism Bolt' &&
      document.documentElement.dataset.creatorSkillDraftDamage === '33' &&
      document.documentElement.dataset.creatorSkillDraftMpCost === '17' &&
      document.documentElement.dataset.creatorPreviewVfxBound === 'true' &&
      document.documentElement.dataset.creatorPreviewVfxFrameCount === '4' &&
      Math.abs(Number(document.documentElement.dataset.creatorPreviewVfxScale) - 2) < 0.001 &&
      Math.abs(Number(document.documentElement.dataset.creatorPreviewVfxOffsetX) - 12) < 0.001 &&
      Math.abs(Number(document.documentElement.dataset.creatorPreviewVfxOffsetY) + 8) < 0.001,
    null,
    { timeout: 10_000 },
  );

  await page.evaluate(() => window.customFighterCreatorPreview());
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.appMode === 'training' &&
      document.documentElement.dataset.creatorPreviewActive === 'true' &&
      document.documentElement.dataset.playerCharacterName === 'VFX Nova' &&
      document.documentElement.dataset.creatorPreviewVfxRuntimeLoaded === 'true' &&
      document.documentElement.dataset.creatorPreviewVfxRuntimeFrameCount === '4' &&
      Math.abs(Number(document.documentElement.dataset.creatorPreviewVfxRuntimeScale) - 2) < 0.001 &&
      Math.abs(Number(document.documentElement.dataset.creatorPreviewVfxRuntimeOffsetX) - 12) < 0.001 &&
      Math.abs(Number(document.documentElement.dataset.creatorPreviewVfxRuntimeOffsetY) + 8) < 0.001 &&
      document.documentElement.dataset.creatorPreviewVfxRuntimeLoadError === '' &&
      typeof window.customFighterPreviewReturnToCreator === 'function',
    null,
    { timeout: 60_000 },
  );

  await page.keyboard.down('u');
  await page.waitForFunction(
    () => Number(document.documentElement.dataset.playerMp) === 83,
    null,
    { timeout: 3_000 },
  );
  await page.keyboard.up('u');

  await page.waitForFunction(
    () => document.documentElement.dataset.creatorPreviewVfxProjectileVisible === 'true',
    null,
    { timeout: 3_000 },
  );
  const frameBefore = Number(await dataset(page, 'creatorPreviewVfxRuntimeCurrentFrame'));
  await page.waitForFunction(
    (previous) =>
      document.documentElement.dataset.creatorPreviewVfxProjectileVisible === 'true' &&
      Number(document.documentElement.dataset.creatorPreviewVfxRuntimeCurrentFrame ?? '-1') !== previous,
    frameBefore,
    { timeout: 3_000 },
  );
  const frameAfter = Number(await dataset(page, 'creatorPreviewVfxRuntimeCurrentFrame'));
  if (frameAfter < 0 || frameAfter > 3) {
    throw new Error(`Runtime VFX frame escaped authored strip: ${frameAfter}`);
  }

  await page.waitForFunction(
    () =>
      Number(document.documentElement.dataset.dummyHp) === 67 &&
      document.documentElement.dataset.lastSkillHit === 'true' &&
      Number(document.documentElement.dataset.skillHitCount) >= 1,
    null,
    { timeout: 5_000 },
  );

  await page.evaluate(() => window.customFighterPreviewReturnToCreator());
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.appMode === 'creator' &&
      document.documentElement.dataset.creatorDraftName === 'VFX Nova' &&
      document.documentElement.dataset.creatorSkillDraftName === 'Prism Bolt' &&
      document.documentElement.dataset.creatorPreviewVfxBound === 'true' &&
      typeof window.customFighterCreatorOpenVfx === 'function',
    null,
    { timeout: 10_000 },
  );

  await page.evaluate(() => window.customFighterCreatorOpenVfx());
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.appMode === 'vfx' &&
      document.documentElement.dataset.creatorVfxReady === 'true' &&
      document.documentElement.dataset.creatorVfxImported === 'true' &&
      document.documentElement.dataset.creatorVfxFrameCount === '4' &&
      typeof window.customFighterCreatorVfxReset === 'function',
    null,
    { timeout: 10_000 },
  );
  revision = Number(await dataset(page, 'creatorVfxRevision'));
  await page.evaluate(() => window.customFighterCreatorVfxReset());
  await waitForRevision(page, 'creatorVfxRevision', revision);
  if ((await dataset(page, 'creatorVfxImported')) !== 'false' || (await dataset(page, 'creatorVfxValid')) !== 'false') {
    throw new Error('Reset VFX should clear the imported binding source');
  }

  await page.evaluate(() => window.customFighterCreatorVfxBackToCreator());
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.appMode === 'creator' &&
      document.documentElement.dataset.creatorPreviewVfxBound === 'false' &&
      document.documentElement.dataset.creatorDraftName === 'VFX Nova' &&
      document.documentElement.dataset.creatorSkillDraftName === 'Prism Bolt',
    null,
    { timeout: 10_000 },
  );

  console.log(
    `WEB_CREATOR_VFX_RUNTIME_BINDING_SMOKE_PASSED draftsPreserved=true bound=true runtimeLoaded=true frames=4 frameBefore=${frameBefore} frameAfter=${frameAfter} scale=2 offset=12,-8 mpCost=17 damage=33 resetClears=true`,
  );
} finally {
  await browser.close();
}
