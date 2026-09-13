import { chromium } from 'playwright';

const baseUrl = process.env.CUSTOM_FIGHTER_WEB_URL ?? 'http://127.0.0.1:8000';
const browserChannel = process.env.BROWSER_CHANNEL?.trim();
const launchOptions = { headless: true };
if (browserChannel) launchOptions.channel = browserChannel;

console.log(`CREATOR_PACKAGE_VFX_BROWSER=${browserChannel || 'playwright-chromium'}`);
const browser = await chromium.launch(launchOptions);

function creatorUrl() {
  const url = new URL(baseUrl);
  url.searchParams.set('mode', 'creator');
  return url.toString();
}

async function waitCreator(page) {
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.appMode === 'creator' &&
      document.documentElement.dataset.creatorStudioReady === 'true' &&
      document.documentElement.dataset.creatorPackageReady === 'true' &&
      document.documentElement.dataset.creatorPreviewReady === 'true' &&
      typeof window.customFighterCreatorExportPackage === 'function' &&
      typeof window.customFighterCreatorImportPackageJson === 'function' &&
      typeof window.customFighterCreatorOpenVfx === 'function',
    null,
    { timeout: 60_000 },
  );
}

try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  let response = await page.goto(creatorUrl(), { waitUntil: 'domcontentloaded', timeout: 60_000 });
  if (!response?.ok()) throw new Error(`Creator URL returned HTTP ${response?.status() ?? 'unknown'}`);
  await waitCreator(page);

  await page.evaluate(() => {
    window.customFighterCreatorSetName('Packaged VFX Hero');
    window.customFighterCreatorSetMaxHp(180);
    window.customFighterCreatorSetSkillName('Package Prism Bolt');
    window.customFighterCreatorSetSkillDamage(33);
    window.customFighterCreatorSetSkillMpCost(17);
    window.customFighterCreatorOpenVfx();
  });
  await page.waitForFunction(
    () => document.documentElement.dataset.appMode === 'vfx' && document.documentElement.dataset.creatorVfxReady === 'true',
    null,
    { timeout: 60_000 },
  );

  await page.evaluate(() => {
    const canvas = document.createElement('canvas');
    canvas.width = 16;
    canvas.height = 4;
    const context = canvas.getContext('2d');
    ['#ff2200', '#ffcc00', '#00ddff', '#aa33ff'].forEach((color, index) => {
      context.fillStyle = color;
      context.fillRect(index * 4, 0, 4, 4);
    });
    window.customFighterCreatorVfxImportPng('package-strip.png', 'image/png', canvas.toDataURL('image/png'));
  });
  await page.waitForFunction(() => document.documentElement.dataset.creatorVfxValid === 'true', null, { timeout: 5_000 });
  await page.evaluate(() => {
    window.customFighterCreatorVfxSetFrameCount(4);
    window.customFighterCreatorVfxSetFps(20);
    window.customFighterCreatorVfxSetScale(2);
    window.customFighterCreatorVfxSetOffset(12, -8);
    window.customFighterCreatorVfxBackToCreator();
  });
  await waitCreator(page);
  await page.waitForFunction(
    () => document.documentElement.dataset.creatorPackageVfxBound === 'true',
    null,
    { timeout: 10_000 },
  );

  await page.evaluate(() => window.customFighterCreatorExportPackage());
  await page.waitForFunction(
    () => Number(document.documentElement.dataset.creatorPackageExportCount ?? '0') >= 1 && typeof window.customFighterLastPackageJson === 'string',
    null,
    { timeout: 5_000 },
  );
  const exportedJson = await page.evaluate(() => window.customFighterLastPackageJson);
  const exported = JSON.parse(exportedJson);
  if (exported.schema_version !== 2) throw new Error(`Expected schema 2, got ${exported.schema_version}`);
  if (exported.vfx_asset?.metadata?.frame_count !== 4) throw new Error('VFX metadata missing from package');
  if (!String(exported.vfx_asset?.png_base64 ?? '').length) throw new Error('VFX PNG payload missing from package');

  response = await page.goto(creatorUrl(), { waitUntil: 'domcontentloaded', timeout: 60_000 });
  if (!response?.ok()) throw new Error(`Reloaded Creator URL returned HTTP ${response?.status() ?? 'unknown'}`);
  await waitCreator(page);
  await page.evaluate((text) => window.customFighterCreatorImportPackageJson(text), exportedJson);
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorPackageImportStatus === 'valid' &&
      document.documentElement.dataset.creatorDraftName === 'Packaged VFX Hero' &&
      document.documentElement.dataset.creatorSkillDraftName === 'Package Prism Bolt' &&
      document.documentElement.dataset.creatorPreviewVfxBound === 'true' &&
      document.documentElement.dataset.creatorPreviewVfxFrameCount === '4' &&
      document.documentElement.dataset.creatorPackageVfxBound === 'true',
    null,
    { timeout: 10_000 },
  );

  await page.evaluate(() => window.customFighterCreatorPreview());
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.appMode === 'training' &&
      document.documentElement.dataset.creatorPreviewVfxRuntimeLoaded === 'true' &&
      document.documentElement.dataset.creatorPreviewVfxRuntimeFrameCount === '4' &&
      document.documentElement.dataset.playerCharacterName === 'Packaged VFX Hero',
    null,
    { timeout: 60_000 },
  );
  await page.keyboard.down('u');
  await page.waitForFunction(() => Number(document.documentElement.dataset.playerMp) === 83, null, { timeout: 3_000 });
  await page.keyboard.up('u');
  await page.waitForFunction(
    () => document.documentElement.dataset.creatorPreviewVfxProjectileVisible === 'true',
    null,
    { timeout: 3_000 },
  );
  await page.waitForFunction(
    () => Number(document.documentElement.dataset.dummyHp) === 67 && document.documentElement.dataset.lastSkillHit === 'true',
    null,
    { timeout: 5_000 },
  );

  console.log('WEB_CREATOR_PACKAGE_VFX_SMOKE_PASSED schema=2 embeddedVfx=true secondSessionImport=true runtimeLoaded=true cast=true');
  await page.close();
} finally {
  await browser.close();
}
