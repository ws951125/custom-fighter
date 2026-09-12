import { chromium } from 'playwright';

const baseUrl = process.env.CUSTOM_FIGHTER_WEB_URL ?? 'http://127.0.0.1:8000';
const browserChannel = process.env.BROWSER_CHANNEL?.trim();
const launchOptions = { headless: true };
if (browserChannel) launchOptions.channel = browserChannel;

console.log(`CREATOR_VFX_BROWSER=${browserChannel || 'playwright-chromium'}`);
console.log(`CREATOR_VFX_BASE_URL=${baseUrl}`);

function vfxUrl() {
  const url = new URL(baseUrl);
  url.searchParams.set('mode', 'vfx');
  return url.toString();
}

async function dataset(page, key) {
  return String(await page.evaluate((name) => document.documentElement.dataset[name] ?? '', key));
}

async function waitForRevision(page, before) {
  await page.waitForFunction(
    (previous) => Number(document.documentElement.dataset.creatorVfxRevision ?? '0') > previous,
    before,
    { timeout: 5_000 },
  );
}

const browser = await chromium.launch(launchOptions);
try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const response = await page.goto(vfxUrl(), { waitUntil: 'domcontentloaded', timeout: 60_000 });
  if (!response?.ok()) throw new Error(`VFX Creator URL returned HTTP ${response?.status() ?? 'unknown'}`);

  await page.waitForFunction(
    () =>
      document.documentElement.dataset.appMode === 'vfx' &&
      document.documentElement.dataset.creatorVfxReady === 'true' &&
      typeof window.customFighterCreatorVfxImportPng === 'function' &&
      typeof window.customFighterCreatorVfxSetCrop === 'function' &&
      typeof window.customFighterCreatorVfxSetScale === 'function' &&
      typeof window.customFighterCreatorVfxReset === 'function',
    null,
    { timeout: 60_000 },
  );

  if ((await dataset(page, 'creatorVfxImported')) !== 'false') {
    throw new Error('VFX draft should start without imported PNG');
  }
  if ((await dataset(page, 'creatorVfxValid')) !== 'false') {
    throw new Error('VFX draft should start invalid until a PNG is imported');
  }

  let revision = Number(await dataset(page, 'creatorVfxRevision'));
  await page.evaluate(() => {
    const canvas = document.createElement('canvas');
    canvas.width = 4;
    canvas.height = 3;
    const context = canvas.getContext('2d');
    context.fillStyle = '#ff6600';
    context.fillRect(0, 0, 4, 3);
    const dataUrl = canvas.toDataURL('image/png');
    window.customFighterCreatorVfxImportPng('ci-spark.png', 'image/png', dataUrl);
  });
  await waitForRevision(page, revision);

  const imported = {
    imported: await dataset(page, 'creatorVfxImported'),
    valid: await dataset(page, 'creatorVfxValid'),
    fileName: await dataset(page, 'creatorVfxFileName'),
    mime: await dataset(page, 'creatorVfxMime'),
    width: Number(await dataset(page, 'creatorVfxWidth')),
    height: Number(await dataset(page, 'creatorVfxHeight')),
    cropWidth: Number(await dataset(page, 'creatorVfxCropWidth')),
    cropHeight: Number(await dataset(page, 'creatorVfxCropHeight')),
  };
  if (
    imported.imported !== 'true' ||
    imported.valid !== 'true' ||
    imported.fileName !== 'ci-spark.png' ||
    imported.mime !== 'image/png' ||
    imported.width !== 4 ||
    imported.height !== 3 ||
    imported.cropWidth !== 4 ||
    imported.cropHeight !== 3
  ) {
    throw new Error(`Imported PNG metadata mismatch: ${JSON.stringify(imported)}`);
  }

  revision = Number(await dataset(page, 'creatorVfxRevision'));
  await page.evaluate(() => window.customFighterCreatorVfxSetCrop(1, 0, 2, 3));
  await waitForRevision(page, revision);
  if ((await dataset(page, 'creatorVfxValid')) !== 'true') {
    throw new Error(`Valid crop should remain valid: ${await dataset(page, 'creatorVfxError')}`);
  }
  if (Number(await dataset(page, 'creatorVfxCropX')) !== 1 || Number(await dataset(page, 'creatorVfxCropWidth')) !== 2) {
    throw new Error('Valid crop metadata did not persist');
  }

  revision = Number(await dataset(page, 'creatorVfxRevision'));
  await page.evaluate(() => window.customFighterCreatorVfxSetCrop(3, 0, 2, 3));
  await waitForRevision(page, revision);
  if ((await dataset(page, 'creatorVfxValid')) !== 'false') {
    throw new Error('Out-of-bounds crop should invalidate the VFX draft');
  }
  if (!(await dataset(page, 'creatorVfxError')).includes('crop must stay inside image bounds')) {
    throw new Error(`Expected crop-boundary error missing: ${await dataset(page, 'creatorVfxError')}`);
  }

  revision = Number(await dataset(page, 'creatorVfxRevision'));
  await page.evaluate(() => window.customFighterCreatorVfxSetCrop(0, 0, 4, 3));
  await waitForRevision(page, revision);
  if ((await dataset(page, 'creatorVfxValid')) !== 'true') {
    throw new Error(`Full-image crop should restore validity: ${await dataset(page, 'creatorVfxError')}`);
  }

  revision = Number(await dataset(page, 'creatorVfxRevision'));
  await page.evaluate(() => window.customFighterCreatorVfxSetScale(0.01));
  await waitForRevision(page, revision);
  if ((await dataset(page, 'creatorVfxValid')) !== 'false') {
    throw new Error('Scale below safety range should invalidate the VFX draft');
  }
  if (!(await dataset(page, 'creatorVfxError')).includes('scale must be between 0.1 and 8.0')) {
    throw new Error(`Expected scale error missing: ${await dataset(page, 'creatorVfxError')}`);
  }

  revision = Number(await dataset(page, 'creatorVfxRevision'));
  await page.evaluate(() => window.customFighterCreatorVfxSetScale(2));
  await waitForRevision(page, revision);
  if ((await dataset(page, 'creatorVfxValid')) !== 'true') {
    throw new Error(`Safe scale should restore validity: ${await dataset(page, 'creatorVfxError')}`);
  }

  revision = Number(await dataset(page, 'creatorVfxRevision'));
  await page.evaluate(() => window.customFighterCreatorVfxReset());
  await waitForRevision(page, revision);
  if ((await dataset(page, 'creatorVfxImported')) !== 'false' || (await dataset(page, 'creatorVfxValid')) !== 'false') {
    throw new Error('Reset should clear the in-memory PNG and return the VFX draft to unimported state');
  }

  console.log('WEB_CREATOR_VFX_EDITOR_SMOKE_PASSED pngDecode=true cropValidation=true scaleValidation=true reset=true');
} finally {
  await browser.close();
}
