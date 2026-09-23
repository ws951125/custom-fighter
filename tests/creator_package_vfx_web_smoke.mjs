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

async function waitCreator(page) {
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.appMode === 'creator' &&
      document.documentElement.dataset.creatorStudioReady === 'true' &&
      document.documentElement.dataset.creatorPackageReady === 'true' &&
      document.documentElement.dataset.creatorPreviewReady === 'true' &&
      typeof window.customFighterCreatorExportPackage === 'function' &&
      typeof window.customFighterCreatorImportPackageJson === 'function' &&
      typeof window.customFighterCreatorSetAnimationSemantic === 'function' &&
      typeof window.customFighterCreatorSetAnimationAssetTiming === 'function' &&
      typeof window.customFighterCreatorImportAnimationPng === 'function' &&
      typeof window.customFighterCreatorSetAudioBinding === 'function' &&
      typeof window.customFighterCreatorImportWav === 'function' &&
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
    window.customFighterCreatorSetAnimationSemantic('ready', 'package_ready_custom');
    window.customFighterCreatorSetAnimationAssetTiming(4, 18);
    window.customFighterCreatorSetMaxHp(180);
    window.customFighterCreatorSetSkillName('Package Prism Bolt');
    window.customFighterCreatorSetSkillDamage(33);
    window.customFighterCreatorSetSkillMpCost(17);
    window.customFighterCreatorSetAudioBinding('basic_attack', 'package_attack_custom');
  });

  const audioWavDataUrl = pcmWavDataUrl();
  await page.evaluate(
    ({ dataUrl }) => window.customFighterCreatorImportWav('package-attack.wav', 'audio/wav', dataUrl),
    { dataUrl: audioWavDataUrl },
  );
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorAudioDraftValid === 'true' &&
      document.documentElement.dataset.creatorAudioAssetValid === 'true' &&
      document.documentElement.dataset.creatorAudioAssetBinding === 'basic_attack' &&
      document.documentElement.dataset.creatorAudioAssetCue === 'package_attack_custom' &&
      document.documentElement.dataset.creatorAudioAssetFile === 'package-attack.wav' &&
      document.documentElement.dataset.creatorAudioAssetBytes === '844',
    null,
    { timeout: 5_000 },
  );
  const animationPngDataUrl = await page.evaluate(() => {
    const canvas = document.createElement('canvas');
    canvas.width = 16;
    canvas.height = 4;
    const context = canvas.getContext('2d');
    ['#ff3355', '#33dd77', '#4477ff', '#ffee44'].forEach((color, index) => {
      context.fillStyle = color;
      context.fillRect(index * 4, 0, 4, 4);
    });
    return canvas.toDataURL('image/png');
  });
  await page.evaluate(
    ({ dataUrl }) => window.customFighterCreatorImportAnimationPng('package-ready.png', 'image/png', dataUrl),
    { dataUrl: animationPngDataUrl },
  );
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorAnimationAssetValid === 'true' &&
      document.documentElement.dataset.creatorAnimationAssetAnimationId === 'package_ready_custom' &&
      document.documentElement.dataset.creatorAnimationAssetFrameCount === '4',
    null,
    { timeout: 5_000 },
  );
  await page.evaluate(() => window.customFighterCreatorOpenVfx());
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
    () =>
      document.documentElement.dataset.creatorPackageVfxBound === 'true' &&
      document.documentElement.dataset.creatorPackageAnimationAssetBound === 'true' &&
      document.documentElement.dataset.creatorPackageAnimationAssetSemantic === 'ready' &&
      document.documentElement.dataset.creatorPackageAnimationAssetAnimationId === 'package_ready_custom' &&
      Number(document.documentElement.dataset.creatorPackageAnimationAssetBytes ?? '0') > 0,
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
  if (exported.animation_asset?.metadata?.semantic !== 'ready') throw new Error('Animation PNG semantic missing from package');
  if (exported.animation_asset?.metadata?.animation_id !== 'package_ready_custom') throw new Error('Animation PNG animation id missing from package');
  if (exported.animation_asset?.metadata?.frame_count !== 4) throw new Error('Animation PNG frame metadata missing from package');
  if (!String(exported.animation_asset?.png_base64 ?? '').length) throw new Error('Animation PNG payload missing from package');
  if (exported.audio_asset?.metadata?.binding !== 'basic_attack') throw new Error('WAV binding missing from package');
  if (exported.audio_asset?.metadata?.cue_id !== 'package_attack_custom') throw new Error('WAV cue missing from package');
  if (exported.audio_asset?.metadata?.file_name !== 'package-attack.wav') throw new Error('WAV filename missing from package');
  if (exported.audio_asset?.metadata?.byte_size !== 844) throw new Error('WAV byte metadata missing from package');
  if (Buffer.from(exported.audio_asset?.wav_base64 ?? '', 'base64').length !== 844) throw new Error('WAV payload missing from package');

  response = await page.goto(creatorUrl(), { waitUntil: 'domcontentloaded', timeout: 60_000 });
  if (!response?.ok()) throw new Error(`Reloaded Creator URL returned HTTP ${response?.status() ?? 'unknown'}`);
  await waitCreator(page);
  await page.evaluate((text) => window.customFighterCreatorImportPackageJson(text), exportedJson);
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorPackageImportStatus === 'valid' &&
      document.documentElement.dataset.creatorDraftName === 'Packaged VFX Hero' &&
      document.documentElement.dataset.creatorAnimationDraftAnimationId === 'package_ready_custom' &&
      document.documentElement.dataset.creatorAnimationAssetValid === 'true' &&
      document.documentElement.dataset.creatorAnimationAssetSemantic === 'ready' &&
      document.documentElement.dataset.creatorAnimationAssetAnimationId === 'package_ready_custom' &&
      document.documentElement.dataset.creatorAnimationAssetFile === 'package-ready.png' &&
      document.documentElement.dataset.creatorAnimationAssetFrameCount === '4' &&
      document.documentElement.dataset.creatorAnimationAssetFps === '18.000' &&
      Number(document.documentElement.dataset.creatorAnimationAssetBytes ?? '0') > 0 &&
      document.documentElement.dataset.creatorPackageAnimationAssetBound === 'true' &&
      document.documentElement.dataset.creatorAudioDraftValid === 'true' &&
      document.documentElement.dataset.creatorAudioAssetValid === 'true' &&
      document.documentElement.dataset.creatorAudioAssetBinding === 'basic_attack' &&
      document.documentElement.dataset.creatorAudioAssetCue === 'package_attack_custom' &&
      document.documentElement.dataset.creatorAudioAssetFile === 'package-attack.wav' &&
      document.documentElement.dataset.creatorAudioAssetBytes === '844' &&
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
      document.documentElement.dataset.playerCharacterName === 'Packaged VFX Hero' &&
      document.documentElement.dataset.playerAnimationSemantic === 'ready' &&
      document.documentElement.dataset.playerAnimationId === 'package_ready_custom' &&
      document.documentElement.dataset.creatorPreviewAnimationAssetRuntimeLoaded === 'true' &&
      document.documentElement.dataset.creatorPreviewAnimationAssetRuntimeActive === 'true' &&
      document.documentElement.dataset.creatorPreviewAnimationAssetRuntimeSemantic === 'ready' &&
      document.documentElement.dataset.creatorPreviewAnimationAssetRuntimeAnimationId === 'package_ready_custom' &&
      document.documentElement.dataset.creatorPreviewAnimationAssetRuntimeFrameCount === '4' &&
      document.documentElement.dataset.creatorPreviewAnimationAssetRuntimeLoadError === '' &&
      document.documentElement.dataset.playerAudioCueBasicAttack === 'package_attack_custom' &&
      document.documentElement.dataset.creatorPreviewAudioAssetLoaded === 'true' &&
      document.documentElement.dataset.creatorPreviewAudioAssetCue === 'package_attack_custom' &&
      document.documentElement.dataset.creatorPreviewAudioPlaybackCount === '0' &&
      document.documentElement.dataset.creatorPreviewAudioLastPlayedCue === '',
    null,
    { timeout: 60_000 },
  );
  await page.waitForFunction(
    () =>
      Number(document.documentElement.dataset.creatorPreviewAnimationAssetRuntimeMaxFrameSeen ?? '0') >= 1 &&
      Number(document.documentElement.dataset.creatorPreviewAnimationAssetRuntimeDrawCount ?? '0') > 0,
    null,
    { timeout: 5_000 },
  );

  await page.keyboard.press('j');
  await page.waitForFunction(
    () =>
      Number(document.documentElement.dataset.creatorPreviewAudioPlaybackCount ?? '0') === 1 &&
      document.documentElement.dataset.creatorPreviewAudioLastPlayedCue === 'package_attack_custom',
    null,
    { timeout: 5_000 },
  );

  // The basic-attack WAV acknowledgement can arrive before AttackChainState leaves
  // recovery. Skill 1 samples a held key only on its first unlatched frame, so pressing
  // U during basic-attack recovery can legitimately reject the cast and latch the held
  // input until release. Wait for the public READY runtime state before starting the
  // independent Skill 1 assertion instead of making runner frame cadence part of it.
  await page.waitForFunction(
    () => document.documentElement.dataset.playerState === 'READY',
    null,
    { timeout: 10_000 },
  );

  // Godot Web input is frame-polled. Keep U held until the runtime acknowledges the
  // authored 17 MP spend, then release it even if the observation times out. These
  // state-driven windows match the stable Creator AI-VFX runtime regression.
  await page.keyboard.down('u');
  try {
    await page.waitForFunction(
      () => Number(document.documentElement.dataset.playerMp) === 83,
      null,
      { timeout: 10_000 },
    );
  } finally {
    await page.keyboard.up('u');
  }
  await page.waitForFunction(
    () => document.documentElement.dataset.creatorPreviewVfxProjectileVisible === 'true',
    null,
    { timeout: 10_000 },
  );
  await page.waitForFunction(
    () => Number(document.documentElement.dataset.dummyHp) === 67 && document.documentElement.dataset.lastSkillHit === 'true',
    null,
    { timeout: 10_000 },
  );

  console.log('WEB_CREATOR_PACKAGE_VFX_SMOKE_PASSED schema=2 embeddedVfx=true embeddedAnimationPng=true embeddedWav=true secondSessionImport=true secondSessionAnimationPngRestored=true secondSessionWavRestored=true animationPngRuntimeRendering=true animationPngRuntimeFrameAdvance=true wavRuntimePlaybackAfterImport=true runtimeLoaded=true cast=true');
  await page.close();
} finally {
  await browser.close();
}
