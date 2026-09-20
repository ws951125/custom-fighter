import { chromium } from 'playwright';

const baseUrl = process.env.CUSTOM_FIGHTER_WEB_URL ?? 'http://127.0.0.1:8000';
const browserChannel = process.env.BROWSER_CHANNEL?.trim();
const launchOptions = { headless: true };
if (browserChannel) launchOptions.channel = browserChannel;

console.log(`CREATOR_VFX_BROWSER=${browserChannel || 'playwright-chromium'}`);
console.log(`CREATOR_VFX_BASE_URL=${baseUrl}`);

function modeUrl(mode) {
  const url = new URL(baseUrl);
  url.searchParams.set('mode', mode);
  return url.toString();
}

async function dataset(page, key) {
  return String(await page.evaluate((name) => document.documentElement.dataset[name] ?? '', key));
}

async function waitForRevision(page, before) {
  // Revision is persistent once the Creator mutation is applied. Use a bounded state-driven
  // window that tolerates hosted Windows/Edge scheduling stalls without adding fixed sleeps.
  await page.waitForFunction(
    (previous) => Number(document.documentElement.dataset.creatorVfxRevision ?? '0') > previous,
    before,
    { timeout: 15_000 },
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
      document.documentElement.dataset.creatorVfxNavigationReady === 'true' &&
      typeof window.customFighterCreatorOpenVfx === 'function',
    null,
    { timeout: 60_000 },
  );

  await page.evaluate(() => window.customFighterCreatorOpenVfx());
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.appMode === 'vfx' &&
      document.documentElement.dataset.creatorVfxReady === 'true' &&
      typeof window.customFighterCreatorVfxImportPng === 'function' &&
      typeof window.customFighterCreatorVfxSetCrop === 'function' &&
      typeof window.customFighterCreatorVfxSetScale === 'function' &&
      typeof window.customFighterCreatorVfxSetFrameCount === 'function' &&
      typeof window.customFighterCreatorVfxSetFps === 'function' &&
      typeof window.customFighterCreatorVfxSetOffset === 'function' &&
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
  await page.evaluate(() =>
    window.customFighterCreatorVfxImportPng(
      'payload.js',
      'application/javascript',
      'data:application/javascript;base64,YWxlcnQoMSk=',
    ),
  );
  await waitForRevision(page, revision);
  if ((await dataset(page, 'creatorVfxImported')) !== 'false' || (await dataset(page, 'creatorVfxValid')) !== 'false') {
    throw new Error('Unsupported non-image input must fail closed');
  }
  if (!(await dataset(page, 'creatorVfxError')).includes('image/png data URL')) {
    throw new Error(`Unsupported-input error missing: ${await dataset(page, 'creatorVfxError')}`);
  }

  revision = Number(await dataset(page, 'creatorVfxRevision'));
  await page.evaluate(() => {
    const canvas = document.createElement('canvas');
    canvas.width = 16;
    canvas.height = 4;
    const context = canvas.getContext('2d');
    const colors = ['#ff3300', '#ffcc00', '#33ccff', '#9933ff'];
    colors.forEach((color, index) => {
      context.fillStyle = color;
      context.fillRect(index * 4, 0, 4, 4);
    });
    const dataUrl = canvas.toDataURL('image/png');
    window.customFighterCreatorVfxImportPng('ci-strip.png', 'image/png', dataUrl);
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
    frameCount: Number(await dataset(page, 'creatorVfxFrameCount')),
    frameWidth: Number(await dataset(page, 'creatorVfxFrameWidth')),
  };
  if (
    imported.imported !== 'true' ||
    imported.valid !== 'true' ||
    imported.fileName !== 'ci-strip.png' ||
    imported.mime !== 'image/png' ||
    imported.width !== 16 ||
    imported.height !== 4 ||
    imported.cropWidth !== 16 ||
    imported.cropHeight !== 4 ||
    imported.frameCount !== 1 ||
    imported.frameWidth !== 16
  ) {
    throw new Error(`Imported PNG metadata mismatch: ${JSON.stringify(imported)}`);
  }

  revision = Number(await dataset(page, 'creatorVfxRevision'));
  await page.evaluate(() => window.customFighterCreatorVfxSetCrop(1, 0, 8, 4));
  await waitForRevision(page, revision);
  if ((await dataset(page, 'creatorVfxValid')) !== 'true') {
    throw new Error(`Valid single-frame crop should remain valid: ${await dataset(page, 'creatorVfxError')}`);
  }
  if (Number(await dataset(page, 'creatorVfxCropX')) !== 1 || Number(await dataset(page, 'creatorVfxCropWidth')) !== 8) {
    throw new Error('Valid crop metadata did not persist');
  }

  revision = Number(await dataset(page, 'creatorVfxRevision'));
  await page.evaluate(() => window.customFighterCreatorVfxSetCrop(12, 0, 8, 4));
  await waitForRevision(page, revision);
  if ((await dataset(page, 'creatorVfxValid')) !== 'false') {
    throw new Error('Out-of-bounds crop should invalidate the VFX draft');
  }
  if (!(await dataset(page, 'creatorVfxError')).includes('crop must stay inside image bounds')) {
    throw new Error(`Expected crop-boundary error missing: ${await dataset(page, 'creatorVfxError')}`);
  }

  revision = Number(await dataset(page, 'creatorVfxRevision'));
  await page.evaluate(() => window.customFighterCreatorVfxSetCrop(0, 0, 16, 4));
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
  if (Number(await dataset(page, 'creatorVfxPreviewScale')) !== 1) {
    throw new Error('Invalid authored scale must fail closed to identity preview scale');
  }

  revision = Number(await dataset(page, 'creatorVfxRevision'));
  await page.evaluate(() => window.customFighterCreatorVfxSetScale(2));
  await waitForRevision(page, revision);
  if ((await dataset(page, 'creatorVfxValid')) !== 'true') {
    throw new Error(`Safe scale should restore validity: ${await dataset(page, 'creatorVfxError')}`);
  }
  if (Number(await dataset(page, 'creatorVfxPreviewScale')) !== 2) {
    throw new Error(`Authored scale was not applied to preview: ${await dataset(page, 'creatorVfxPreviewScale')}`);
  }

  revision = Number(await dataset(page, 'creatorVfxRevision'));
  await page.evaluate(() => window.customFighterCreatorVfxSetOffset(12, -8));
  await waitForRevision(page, revision);
  if (
    Number(await dataset(page, 'creatorVfxPreviewOffsetX')) !== 12 ||
    Number(await dataset(page, 'creatorVfxPreviewOffsetY')) !== -8
  ) {
    throw new Error(
      `Authored offset was not applied to preview: ${await dataset(page, 'creatorVfxPreviewOffsetX')},${await dataset(page, 'creatorVfxPreviewOffsetY')}`,
    );
  }

  revision = Number(await dataset(page, 'creatorVfxRevision'));
  await page.evaluate(() => window.customFighterCreatorVfxSetFrameCount(3));
  await waitForRevision(page, revision);
  if ((await dataset(page, 'creatorVfxValid')) !== 'false') {
    throw new Error('Non-divisible horizontal strip should invalidate the VFX draft');
  }
  if (!(await dataset(page, 'creatorVfxError')).includes('crop width must divide evenly across frame_count')) {
    throw new Error(`Expected strip divisibility error missing: ${await dataset(page, 'creatorVfxError')}`);
  }

  revision = Number(await dataset(page, 'creatorVfxRevision'));
  await page.evaluate(() => window.customFighterCreatorVfxSetFrameCount(4));
  await waitForRevision(page, revision);
  if ((await dataset(page, 'creatorVfxValid')) !== 'true') {
    throw new Error(`Four-frame strip should validate: ${await dataset(page, 'creatorVfxError')}`);
  }
  if (
    Number(await dataset(page, 'creatorVfxFrameCount')) !== 4 ||
    Number(await dataset(page, 'creatorVfxFrameWidth')) !== 4
  ) {
    throw new Error('Four-frame strip did not derive deterministic 4 px frame width');
  }

  revision = Number(await dataset(page, 'creatorVfxRevision'));
  await page.evaluate(() => window.customFighterCreatorVfxSetFps(20));
  await waitForRevision(page, revision);
  if (Number(await dataset(page, 'creatorVfxFps')) !== 20) {
    throw new Error('Authored FPS did not persist');
  }

  const frameBefore = Number(await dataset(page, 'creatorVfxCurrentFrame'));
  await page.waitForFunction(
    (previous) => Number(document.documentElement.dataset.creatorVfxCurrentFrame ?? '-1') !== previous,
    frameBefore,
    { timeout: 5_000 },
  );
  const frameAfter = Number(await dataset(page, 'creatorVfxCurrentFrame'));
  if (frameAfter < 0 || frameAfter > 3) {
    throw new Error(`Animated frame index escaped four-frame strip: ${frameAfter}`);
  }

  revision = Number(await dataset(page, 'creatorVfxRevision'));
  await page.evaluate(() => window.customFighterCreatorVfxReset());
  await waitForRevision(page, revision);
  if ((await dataset(page, 'creatorVfxImported')) !== 'false' || (await dataset(page, 'creatorVfxValid')) !== 'false') {
    throw new Error('Reset should clear the in-memory PNG and return the VFX draft to unimported state');
  }
  if (
    Number(await dataset(page, 'creatorVfxFrameCount')) !== 1 ||
    Number(await dataset(page, 'creatorVfxCurrentFrame')) !== 0 ||
    Number(await dataset(page, 'creatorVfxPreviewScale')) !== 1 ||
    Number(await dataset(page, 'creatorVfxPreviewOffsetX')) !== 0 ||
    Number(await dataset(page, 'creatorVfxPreviewOffsetY')) !== 0
  ) {
    throw new Error('Reset should restore one-frame identity preview transform state');
  }

  console.log(
    'WEB_CREATOR_VFX_EDITOR_SMOKE_PASSED navigation=true failClosed=true pngDecode=true cropValidation=true scaleApplied=true offsetApplied=true stripValidation=true animation=true reset=true',
  );
} finally {
  await browser.close();
}
