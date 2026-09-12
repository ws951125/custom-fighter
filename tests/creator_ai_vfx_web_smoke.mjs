import { chromium } from 'playwright';

const baseUrl = process.env.CUSTOM_FIGHTER_WEB_URL ?? 'http://127.0.0.1:8000';
const browserChannel = process.env.BROWSER_CHANNEL?.trim();
const launchOptions = { headless: true };
if (browserChannel) launchOptions.channel = browserChannel;

console.log(`CREATOR_AI_VFX_BROWSER=${browserChannel || 'playwright-chromium'}`);
console.log(`CREATOR_AI_VFX_BASE_URL=${baseUrl}`);

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
      typeof window.customFighterCreatorOpenVfx === 'function' &&
      typeof window.customFighterCreatorSetSkillDamage === 'function' &&
      typeof window.customFighterCreatorSetSkillMpCost === 'function',
    null,
    { timeout: 60_000 },
  );

  await page.evaluate(() => {
    window.customFighterCreatorSetSkillDamage(33);
    window.customFighterCreatorSetSkillMpCost(17);
  });
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorSkillDraftValid === 'true' &&
      document.documentElement.dataset.creatorSkillDraftDamage === '33' &&
      document.documentElement.dataset.creatorSkillDraftMpCost === '17',
    null,
    { timeout: 5_000 },
  );

  await page.evaluate(() => window.customFighterCreatorOpenVfx());
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.appMode === 'vfx' &&
      document.documentElement.dataset.creatorVfxReady === 'true' &&
      document.documentElement.dataset.creatorAiVfxReady === 'true' &&
      typeof window.customFighterCreatorAiVfxSetPrompt === 'function' &&
      typeof window.customFighterCreatorAiVfxSetOutput === 'function' &&
      typeof window.customFighterCreatorAiVfxImportReference === 'function' &&
      typeof window.customFighterCreatorAiVfxClearReference === 'function' &&
      typeof window.customFighterCreatorAiVfxGenerate === 'function' &&
      typeof window.customFighterCreatorVfxBackToCreator === 'function',
    null,
    { timeout: 60_000 },
  );

  if ((await dataset(page, 'creatorAiVfxProvider')) !== 'mock_ai_vfx') {
    throw new Error(`Unexpected active provider: ${await dataset(page, 'creatorAiVfxProvider')}`);
  }
  if (Number(await dataset(page, 'creatorAiVfxGenerationCount')) !== 0) {
    throw new Error('AI VFX generation count should start at zero');
  }

  // Empty prompt must fail closed without manufacturing a VFX.
  let aiRevision = Number(await dataset(page, 'creatorAiVfxRevision'));
  await page.evaluate(() => window.customFighterCreatorAiVfxGenerate());
  await waitForRevision(page, 'creatorAiVfxRevision', aiRevision);
  if ((await dataset(page, 'creatorAiVfxLastStatus')) !== 'error') {
    throw new Error('Empty AI prompt should fail closed');
  }
  if (!(await dataset(page, 'creatorAiVfxError')).includes('prompt must not be empty')) {
    throw new Error(`Missing empty-prompt validation: ${await dataset(page, 'creatorAiVfxError')}`);
  }
  if ((await dataset(page, 'creatorVfxImported')) !== 'false') {
    throw new Error('Rejected AI request must not create a VFX');
  }

  aiRevision = Number(await dataset(page, 'creatorAiVfxRevision'));
  await page.evaluate(() => {
    window.customFighterCreatorAiVfxSetPrompt('electric blue comet projectile with a bright white core');
    window.customFighterCreatorAiVfxSetOutput(4, 32, 32, 20);
  });
  await waitForRevision(page, 'creatorAiVfxRevision', aiRevision);

  // Seed generation with an optional real PNG reference image.
  aiRevision = Number(await dataset(page, 'creatorAiVfxRevision'));
  await page.evaluate(() => {
    const canvas = document.createElement('canvas');
    canvas.width = 8;
    canvas.height = 8;
    const context = canvas.getContext('2d');
    context.fillStyle = '#125dff';
    context.fillRect(0, 0, 8, 8);
    context.fillStyle = '#ffffff';
    context.fillRect(2, 2, 4, 4);
    window.customFighterCreatorAiVfxImportReference(
      'reference-comet.png',
      'image/png',
      canvas.toDataURL('image/png'),
    );
  });
  await waitForRevision(page, 'creatorAiVfxRevision', aiRevision);
  if (
    (await dataset(page, 'creatorAiVfxReferencePresent')) !== 'true' ||
    (await dataset(page, 'creatorAiVfxReferenceFileName')) !== 'reference-comet.png' ||
    Number(await dataset(page, 'creatorAiVfxReferenceWidth')) !== 8 ||
    Number(await dataset(page, 'creatorAiVfxReferenceHeight')) !== 8
  ) {
    throw new Error('Validated AI reference PNG metadata did not persist');
  }

  aiRevision = Number(await dataset(page, 'creatorAiVfxRevision'));
  await page.evaluate(() => window.customFighterCreatorAiVfxGenerate());
  await waitForRevision(page, 'creatorAiVfxRevision', aiRevision);
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorAiVfxLastStatus === 'success' &&
      document.documentElement.dataset.creatorAiVfxGeneratedValid === 'true' &&
      document.documentElement.dataset.creatorVfxImported === 'true' &&
      document.documentElement.dataset.creatorVfxValid === 'true' &&
      document.documentElement.dataset.creatorVfxStored === 'true',
    null,
    { timeout: 5_000 },
  );

  const generated = {
    count: Number(await dataset(page, 'creatorAiVfxGenerationCount')),
    requestId: await dataset(page, 'creatorAiVfxLastRequestId'),
    width: Number(await dataset(page, 'creatorVfxWidth')),
    height: Number(await dataset(page, 'creatorVfxHeight')),
    frames: Number(await dataset(page, 'creatorVfxFrameCount')),
    frameWidth: Number(await dataset(page, 'creatorVfxFrameWidth')),
    fps: Number(await dataset(page, 'creatorVfxFps')),
  };
  if (
    generated.count !== 1 ||
    generated.requestId !== 'creator_ai_vfx_1' ||
    generated.width !== 128 ||
    generated.height !== 32 ||
    generated.frames !== 4 ||
    generated.frameWidth !== 32 ||
    Math.abs(generated.fps - 20) > 0.001
  ) {
    throw new Error(`Generated VFX metadata mismatch: ${JSON.stringify(generated)}`);
  }

  const frameBefore = Number(await dataset(page, 'creatorVfxCurrentFrame'));
  await page.waitForFunction(
    (previous) => Number(document.documentElement.dataset.creatorVfxCurrentFrame ?? '-1') !== previous,
    frameBefore,
    { timeout: 5_000 },
  );

  // Regenerate through the same provider-neutral adapter; a new request identity is required.
  aiRevision = Number(await dataset(page, 'creatorAiVfxRevision'));
  await page.evaluate(() => {
    window.customFighterCreatorAiVfxSetPrompt('electric blue comet projectile with a brighter trailing core');
    window.customFighterCreatorAiVfxGenerate();
  });
  await waitForRevision(page, 'creatorAiVfxRevision', aiRevision);
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorAiVfxLastStatus === 'success' &&
      document.documentElement.dataset.creatorAiVfxGenerationCount === '2' &&
      document.documentElement.dataset.creatorAiVfxLastRequestId === 'creator_ai_vfx_2' &&
      document.documentElement.dataset.creatorVfxValid === 'true' &&
      document.documentElement.dataset.creatorVfxStored === 'true',
    null,
    { timeout: 5_000 },
  );

  aiRevision = Number(await dataset(page, 'creatorAiVfxRevision'));
  await page.evaluate(() => window.customFighterCreatorAiVfxClearReference());
  await waitForRevision(page, 'creatorAiVfxRevision', aiRevision);
  if ((await dataset(page, 'creatorAiVfxReferencePresent')) !== 'false') {
    throw new Error('Reference PNG should be optional and clearable');
  }

  // Generated VFX uses the same in-memory Creator binding and real Training projectile path as M5 assets.
  await page.evaluate(() => window.customFighterCreatorVfxBackToCreator());
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.appMode === 'creator' &&
      document.documentElement.dataset.creatorPreviewVfxBound === 'true' &&
      document.documentElement.dataset.creatorPreviewVfxFrameCount === '4' &&
      document.documentElement.dataset.creatorSkillDraftDamage === '33' &&
      document.documentElement.dataset.creatorSkillDraftMpCost === '17' &&
      typeof window.customFighterCreatorPreview === 'function',
    null,
    { timeout: 10_000 },
  );

  await page.evaluate(() => window.customFighterCreatorPreview());
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.appMode === 'training' &&
      document.documentElement.dataset.creatorPreviewActive === 'true' &&
      document.documentElement.dataset.creatorPreviewVfxRuntimeLoaded === 'true' &&
      document.documentElement.dataset.creatorPreviewVfxRuntimeFrameCount === '4' &&
      document.documentElement.dataset.creatorPreviewVfxRuntimeLoadError === '',
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
  const runtimeFrameBefore = Number(await dataset(page, 'creatorPreviewVfxRuntimeCurrentFrame'));
  await page.waitForFunction(
    (previous) =>
      document.documentElement.dataset.creatorPreviewVfxProjectileVisible === 'true' &&
      Number(document.documentElement.dataset.creatorPreviewVfxRuntimeCurrentFrame ?? '-1') !== previous,
    runtimeFrameBefore,
    { timeout: 3_000 },
  );
  await page.waitForFunction(
    () =>
      Number(document.documentElement.dataset.dummyHp) === 67 &&
      document.documentElement.dataset.lastSkillHit === 'true' &&
      Number(document.documentElement.dataset.skillHitCount) >= 1,
    null,
    { timeout: 5_000 },
  );

  console.log(
    'WEB_CREATOR_AI_VFX_SMOKE_PASSED emptyPromptBlocked=true reference=true generate=true regenerate=true generatedFrames=4 runtimeLoaded=true cast=true damage=33 mpCost=17',
  );
} finally {
  await browser.close();
}
