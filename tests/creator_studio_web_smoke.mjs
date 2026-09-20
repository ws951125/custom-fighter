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

function pcmWavDataUrl({ sampleRate = 8000, channels = 1, bits = 8, dataSize = 800 } = {}) {
  const bytes = new Uint8Array(44 + dataSize);
  const view = new DataView(bytes.buffer);
  const ascii = (offset, text) => {
    for (let i = 0; i < text.length; i += 1) bytes[offset + i] = text.charCodeAt(i);
  };
  ascii(0, 'RIFF');
  view.setUint32(4, 36 + dataSize, true);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  view.setUint32(16, 16, true);
  view.setUint16(20, 1, true);
  view.setUint16(22, channels, true);
  view.setUint32(24, sampleRate, true);
  const blockAlign = (channels * bits) / 8;
  view.setUint32(28, sampleRate * blockAlign, true);
  view.setUint16(32, blockAlign, true);
  view.setUint16(34, bits, true);
  ascii(36, 'data');
  view.setUint32(40, dataSize, true);
  bytes.fill(bits === 8 ? 128 : 0, 44);
  return `data:audio/wav;base64,${Buffer.from(bytes).toString('base64')}`;
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
      typeof window.customFighterCreatorImportAnimationPng === 'function' &&
      typeof window.customFighterCreatorClearAnimationAsset === 'function' &&
      typeof window.customFighterCreatorSetAnimationAssetTiming === 'function' &&
      typeof window.customFighterCreatorSetAudioBinding === 'function' &&
      typeof window.customFighterCreatorImportWav === 'function' &&
      typeof window.customFighterCreatorClearAudioAsset === 'function' &&
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
    animationAssetValid: await dataset(page, 'creatorAnimationAssetValid'),
    animationAssetBytes: Number(await dataset(page, 'creatorAnimationAssetBytes')),
    audioDraftValid: await dataset(page, 'creatorAudioDraftValid'),
    audioDraftBinding: await dataset(page, 'creatorAudioDraftBinding'),
    audioDraftCue: await dataset(page, 'creatorAudioDraftCue'),
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
    initial.animationAssetValid !== 'false' ||
    initial.animationAssetBytes !== 0 ||
    initial.audioDraftValid !== 'true' ||
    initial.audioDraftBinding !== 'ready' ||
    initial.audioDraftCue !== 'character_ready' ||
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

  await page.evaluate(() => window.customFighterCreatorSetAnimationAssetTiming(4, 18));
  const animationPngDataUrl = await page.evaluate(() => {
    const canvas = document.createElement('canvas');
    canvas.width = 16;
    canvas.height = 4;
    const context = canvas.getContext('2d');
    ['#ff3344', '#33ff66', '#3377ff', '#ffee33'].forEach((color, index) => {
      context.fillStyle = color;
      context.fillRect(index * 4, 0, 4, 4);
    });
    return canvas.toDataURL('image/png');
  });
  await page.evaluate(
    ({ dataUrl }) => window.customFighterCreatorImportAnimationPng('attack-strip.png', 'image/png', dataUrl),
    { dataUrl: animationPngDataUrl },
  );
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorAnimationAssetValid === 'true' &&
      document.documentElement.dataset.creatorAnimationAssetSemantic === 'attack_1' &&
      document.documentElement.dataset.creatorAnimationAssetAnimationId === 'custom_attack_one' &&
      document.documentElement.dataset.creatorAnimationAssetFile === 'attack-strip.png' &&
      Number(document.documentElement.dataset.creatorAnimationAssetBytes ?? '0') > 0 &&
      document.documentElement.dataset.creatorAnimationAssetWidth === '16' &&
      document.documentElement.dataset.creatorAnimationAssetHeight === '4' &&
      document.documentElement.dataset.creatorAnimationAssetFrameCount === '4' &&
      document.documentElement.dataset.creatorAnimationAssetFps === '18.000' &&
      document.documentElement.dataset.creatorAnimationAssetError === '',
    null,
    { timeout: 5_000 },
  );

  await page.evaluate(() => window.customFighterCreatorSetAnimationAssetTiming(2, 24));
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorAnimationAssetValid === 'true' &&
      document.documentElement.dataset.creatorAnimationAssetFrameCount === '2' &&
      document.documentElement.dataset.creatorAnimationAssetFps === '24.000',
    null,
    { timeout: 5_000 },
  );

  await page.evaluate(() => window.customFighterCreatorSetAnimationSemantic('attack_1', 'custom_attack_two'));
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorAnimationDraftAnimationId === 'custom_attack_two' &&
      document.documentElement.dataset.creatorAnimationAssetValid === 'false' &&
      document.documentElement.dataset.creatorAnimationAssetBytes === '0' &&
      (document.documentElement.dataset.creatorAnimationAssetError ?? '').includes('bound animation ID changed'),
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
  await page.evaluate(() => window.customFighterCreatorSetAnimationAssetTiming(4, 18));
  await page.evaluate(
    ({ dataUrl }) => window.customFighterCreatorImportAnimationPng('attack-strip.png', 'image/png', dataUrl),
    { dataUrl: animationPngDataUrl },
  );
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorAnimationAssetValid === 'true' &&
      document.documentElement.dataset.creatorAnimationAssetAnimationId === 'custom_attack_one',
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

  await page.evaluate(() => window.customFighterCreatorSetAudioBinding('skill_cast', 'nova_skill_cast'));
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorDraftValid === 'true' &&
      document.documentElement.dataset.creatorAudioDraftValid === 'true' &&
      document.documentElement.dataset.creatorAudioDraftBinding === 'skill_cast' &&
      document.documentElement.dataset.creatorAudioDraftCue === 'nova_skill_cast',
    null,
    { timeout: 5_000 },
  );

  await page.evaluate(() => window.customFighterCreatorSetAudioBinding('skill_cast', '../evil.wav'));
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorDraftValid === 'false' &&
      document.documentElement.dataset.creatorAudioDraftValid === 'false' &&
      (document.documentElement.dataset.creatorDraftError ?? '').includes('audio cue for skill_cast must be a safe lowercase token'),
    null,
    { timeout: 5_000 },
  );

  await page.evaluate(() => window.customFighterCreatorSetAudioBinding('skill_cast', 'nova_skill_cast'));
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorDraftValid === 'true' &&
      document.documentElement.dataset.creatorAudioDraftValid === 'true' &&
      document.documentElement.dataset.creatorAudioDraftCue === 'nova_skill_cast',
    null,
    { timeout: 5_000 },
  );

  const wavDataUrl = pcmWavDataUrl();
  await page.evaluate(
    ({ dataUrl }) => window.customFighterCreatorImportWav('skill-cast.wav', 'audio/wav', dataUrl),
    { dataUrl: wavDataUrl },
  );
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorAudioAssetValid === 'true' &&
      document.documentElement.dataset.creatorAudioAssetBinding === 'skill_cast' &&
      document.documentElement.dataset.creatorAudioAssetCue === 'nova_skill_cast' &&
      document.documentElement.dataset.creatorAudioAssetFile === 'skill-cast.wav' &&
      document.documentElement.dataset.creatorAudioAssetBytes === '844' &&
      document.documentElement.dataset.creatorAudioAssetDurationMs === '100' &&
      document.documentElement.dataset.creatorAudioAssetSampleRate === '8000' &&
      document.documentElement.dataset.creatorAudioAssetChannels === '1' &&
      document.documentElement.dataset.creatorAudioAssetBits === '8' &&
      document.documentElement.dataset.creatorAudioAssetError === '',
    null,
    { timeout: 5_000 },
  );

  await page.evaluate(() => window.customFighterCreatorSetAudioBinding('skill_cast', 'nova_skill_cast_v2'));
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorAudioDraftCue === 'nova_skill_cast_v2' &&
      document.documentElement.dataset.creatorAudioAssetValid === 'false' &&
      document.documentElement.dataset.creatorAudioAssetBytes === '0' &&
      (document.documentElement.dataset.creatorAudioAssetError ?? '').includes('bound Cue ID changed'),
    null,
    { timeout: 5_000 },
  );

  await page.evaluate(
    ({ dataUrl }) => window.customFighterCreatorImportWav('skill-cast-v2.wav', 'audio/wav', dataUrl),
    { dataUrl: wavDataUrl },
  );
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorAudioAssetValid === 'true' &&
      document.documentElement.dataset.creatorAudioAssetCue === 'nova_skill_cast_v2' &&
      document.documentElement.dataset.creatorAudioAssetFile === 'skill-cast-v2.wav',
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
      document.documentElement.dataset.creatorAnimationAssetValid === 'false' &&
      document.documentElement.dataset.creatorAnimationAssetBytes === '0' &&
      document.documentElement.dataset.creatorAnimationAssetError === '' &&
      document.documentElement.dataset.creatorAudioDraftValid === 'true' &&
      document.documentElement.dataset.creatorAudioDraftBinding === 'skill_cast' &&
      document.documentElement.dataset.creatorAudioDraftCue === 'skill_cast' &&
      document.documentElement.dataset.creatorAudioAssetValid === 'false' &&
      document.documentElement.dataset.creatorAudioAssetBytes === '0' &&
      document.documentElement.dataset.creatorAudioAssetError === '' &&
      document.documentElement.dataset.creatorDraftMaxHp === '100' &&
      Number(document.documentElement.dataset.creatorDraftRevision ?? '0') > previousRevision,
    revisionBeforeReset,
    { timeout: 5_000 },
  );

  console.log('WEB_CREATOR_STUDIO_SMOKE_PASSED mode=creator valid-invalid-valid-reset animationMapAuthoring=true semanticAuthoring=true animationPngImport=true animationPngTiming=true staleAnimationPngCleared=true animationPngResetCleared=true audioBindingAuthoring=true wavImport=true staleWavCleared=true wavResetCleared=true unsafeSemanticTokenBlocked=true unsafeAudioCueBlocked=true missingMapBlocked=true trainingDefaultPreserved=true');
  await page.close();
} finally {
  await browser.close();
}
