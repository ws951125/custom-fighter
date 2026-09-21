import { chromium } from 'playwright';

const baseUrl = process.env.CUSTOM_FIGHTER_WEB_URL ?? 'http://127.0.0.1:8000';
const browserChannel = process.env.BROWSER_CHANNEL?.trim();
const launchOptions = { headless: true };
if (browserChannel) launchOptions.channel = browserChannel;

console.log(`CREATOR_PACKAGE_BROWSER=${browserChannel || 'playwright-chromium'}`);
console.log(`CREATOR_PACKAGE_BASE_URL=${baseUrl}`);

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
  const creatorUrl = new URL(baseUrl);
  creatorUrl.searchParams.set('mode', 'creator');
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 }, acceptDownloads: true });
  const response = await page.goto(creatorUrl.toString(), { waitUntil: 'domcontentloaded', timeout: 60_000 });
  if (!response?.ok()) throw new Error(`Creator package URL returned HTTP ${response?.status() ?? 'unknown'}`);

  await page.waitForFunction(
    () =>
      document.documentElement.dataset.appMode === 'creator' &&
      document.documentElement.dataset.creatorStudioReady === 'true' &&
      document.documentElement.dataset.creatorPreviewReady === 'true' &&
      document.documentElement.dataset.creatorPackageReady === 'true' &&
      typeof window.customFighterCreatorExportPackage === 'function' &&
      typeof window.customFighterCreatorImportPackageJson === 'function' &&
      typeof window.customFighterCreatorSetAnimationMap === 'function' &&
      typeof window.customFighterCreatorSetAnimationSemantic === 'function' &&
      typeof window.customFighterCreatorImportAnimationPng === 'function' &&
      typeof window.customFighterCreatorSetAnimationAssetTiming === 'function' &&
      typeof window.customFighterCreatorSetAudioBinding === 'function' &&
      typeof window.customFighterCreatorImportWav === 'function' &&
      typeof window.customFighterCreatorPreview === 'function' &&
      typeof window.customFighterCreatorTimelineApplyComposition === 'function' &&
      typeof window.customFighterCreatorTimelineClear === 'function' &&
      document.documentElement.dataset.creatorTimelineCompositionReady === 'true',
    null,
    { timeout: 60_000 },
  );

  await page.evaluate(() => {
    window.customFighterCreatorSetName('Package Nova');
    window.customFighterCreatorSetAnimationMap('storm_duelist');
    window.customFighterCreatorSetAnimationSemantic('ready', 'package_ready_custom');
    window.customFighterCreatorSetAudioBinding('skill_cast', 'package_cast_custom');
    window.customFighterCreatorSetMaxHp(222);
    window.customFighterCreatorSetSkillName('Package Bolt');
    window.customFighterCreatorSetSkillDamage(41);
    window.customFighterCreatorSetSkillMpCost(19);
    window.customFighterCreatorSetSkillCooldown(2.25);
    window.customFighterCreatorTimelineClear();
    window.customFighterCreatorTimelineApplyComposition('guarded_impact', 0);
  });

  await page.evaluate(() => window.customFighterCreatorSetAnimationAssetTiming(4, 18));
  const packageAnimationPngDataUrl = await page.evaluate(() => {
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
    { dataUrl: packageAnimationPngDataUrl },
  );
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorAnimationAssetValid === 'true' &&
      document.documentElement.dataset.creatorAnimationAssetSemantic === 'ready' &&
      document.documentElement.dataset.creatorAnimationAssetAnimationId === 'package_ready_custom' &&
      document.documentElement.dataset.creatorAnimationAssetFile === 'package-ready.png' &&
      Number(document.documentElement.dataset.creatorAnimationAssetBytes ?? '0') > 0,
    null,
    { timeout: 5_000 },
  );

  const packageWavDataUrl = pcmWavDataUrl();
  await page.evaluate(
    ({ dataUrl }) => window.customFighterCreatorImportWav('package-cast.wav', 'audio/wav', dataUrl),
    { dataUrl: packageWavDataUrl },
  );

  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorAudioAssetValid === 'true' &&
      document.documentElement.dataset.creatorAudioAssetBinding === 'skill_cast' &&
      document.documentElement.dataset.creatorAudioAssetCue === 'package_cast_custom' &&
      document.documentElement.dataset.creatorAudioAssetBytes === '844',
    null,
    { timeout: 5_000 },
  );

  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorPackageCanExport === 'true' &&
      document.documentElement.dataset.creatorDraftName === 'Package Nova' &&
      document.documentElement.dataset.creatorDraftAnimationMap === 'storm_duelist' &&
      document.documentElement.dataset.creatorAnimationDraftValid === 'true' &&
      document.documentElement.dataset.creatorAnimationDraftMapId === 'storm_duelist' &&
      document.documentElement.dataset.creatorAnimationDraftSemantic === 'ready' &&
      document.documentElement.dataset.creatorAnimationDraftAnimationId === 'package_ready_custom' &&
      document.documentElement.dataset.creatorAnimationAssetValid === 'true' &&
      document.documentElement.dataset.creatorAnimationAssetSemantic === 'ready' &&
      document.documentElement.dataset.creatorAnimationAssetAnimationId === 'package_ready_custom' &&
      document.documentElement.dataset.creatorAnimationAssetFile === 'package-ready.png' &&
      Number(document.documentElement.dataset.creatorAnimationAssetBytes ?? '0') > 0 &&
      document.documentElement.dataset.creatorAnimationAssetError === '' &&
      document.documentElement.dataset.creatorAudioDraftValid === 'true' &&
      document.documentElement.dataset.creatorAudioDraftBinding === 'skill_cast' &&
      document.documentElement.dataset.creatorAudioDraftCue === 'package_cast_custom' &&
      document.documentElement.dataset.creatorAudioAssetValid === 'true' &&
      document.documentElement.dataset.creatorAudioAssetCue === 'package_cast_custom' &&
      document.documentElement.dataset.creatorAudioAssetFile === 'package-cast.wav' &&
      document.documentElement.dataset.creatorAudioAssetBytes === '844' &&
      document.documentElement.dataset.creatorDraftMaxHp === '222' &&
      document.documentElement.dataset.creatorSkillDraftName === 'Package Bolt' &&
      document.documentElement.dataset.creatorSkillDraftDamage === '41' &&
      document.documentElement.dataset.creatorSkillDraftMpCost === '19' &&
      document.documentElement.dataset.creatorTimelineCount === '5' &&
      document.documentElement.dataset.creatorTimelineValid === 'true',
    null,
    { timeout: 5_000 },
  );

  // Exercise the production Godot Web bridge directly. Package correctness is
  // proven by app-owned telemetry plus the serialized package itself. Browser
  // download/user-activation policy is intentionally not used as this core gate:
  // Blob downloads initiated through JavaScriptBridge are not exposed
  // deterministically as Playwright download/anchor events in headless engines.
  await page.evaluate(() => window.customFighterCreatorExportPackage());
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorPackageExportCount === '1' &&
      Number(document.documentElement.dataset.creatorPackageLastExportBytes) > 100 &&
      typeof window.customFighterLastPackageJson === 'string' &&
      window.customFighterLastPackageJson.length > 100,
    null,
    { timeout: 10_000 },
  );

  const exportedJson = await page.evaluate(() => window.customFighterLastPackageJson);
  const exported = JSON.parse(exportedJson);
  if (exported.schema_version !== 2) throw new Error('Exported package schema_version mismatch');
  if ('vfx_asset' in exported) throw new Error('Package without authored VFX must not emit a vfx_asset');
  if ('animation_assets' in exported) throw new Error('Character Package must not accept an unbounded animation asset collection');
  if (exported.animation_asset?.metadata?.semantic !== 'ready') throw new Error('Packaged Animation PNG semantic mismatch');
  if (exported.animation_asset?.metadata?.animation_id !== 'package_ready_custom') throw new Error('Packaged Animation PNG animation id mismatch');
  if (exported.animation_asset?.metadata?.file_name !== 'package-ready.png') throw new Error('Packaged Animation PNG filename mismatch');
  if (exported.animation_asset?.metadata?.mime_type !== 'image/png') throw new Error('Packaged Animation PNG MIME mismatch');
  if (exported.animation_asset?.metadata?.image_width !== 16 || exported.animation_asset?.metadata?.image_height !== 4) {
    throw new Error('Packaged Animation PNG dimensions mismatch');
  }
  if (exported.animation_asset?.metadata?.frame_count !== 4 || Math.abs(Number(exported.animation_asset?.metadata?.fps) - 18) > 0.001) {
    throw new Error('Packaged Animation PNG timing mismatch');
  }
  if (Buffer.from(exported.animation_asset?.png_base64 ?? '', 'base64').length <= 0) throw new Error('Packaged Animation PNG bytes did not serialize');
  if ('script' in (exported.animation_asset?.metadata ?? {}) || 'path' in (exported.animation_asset?.metadata ?? {}) || 'url' in (exported.animation_asset?.metadata ?? {})) {
    throw new Error('Packaged Animation PNG metadata must remain declarative data only');
  }
  if ('audio_assets' in exported) throw new Error('Character Package must not accept an unbounded audio asset collection');
  if (exported.audio_asset?.metadata?.binding !== 'skill_cast') throw new Error('Packaged WAV binding mismatch');
  if (exported.audio_asset?.metadata?.cue_id !== 'package_cast_custom') throw new Error('Packaged WAV cue mismatch');
  if (exported.audio_asset?.metadata?.file_name !== 'package-cast.wav') throw new Error('Packaged WAV filename mismatch');
  if (exported.audio_asset?.metadata?.mime_type !== 'audio/wav') throw new Error('Packaged WAV MIME mismatch');
  if (exported.audio_asset?.metadata?.byte_size !== 844) throw new Error('Packaged WAV byte metadata mismatch');
  if (Buffer.from(exported.audio_asset?.wav_base64 ?? '', 'base64').length !== 844) throw new Error('Packaged WAV bytes did not serialize');
  if (exported.package_id !== 'my_fighter_001') throw new Error(`Unexpected package_id ${exported.package_id}`);
  if (exported.character?.name !== 'Package Nova') throw new Error('Exported character name mismatch');
  if (exported.character?.animation_map !== 'storm_duelist') throw new Error('Exported animation map mismatch');
  if (exported.animation_map?.id !== 'storm_duelist') throw new Error('Packaged animation map id mismatch');
  if (exported.animation_map?.schema_version !== 1) throw new Error('Packaged animation map schema mismatch');
  if (exported.animation_map?.animations?.ready !== 'package_ready_custom') {
    throw new Error('Custom semantic animation mapping did not serialize');
  }
  if ('script' in exported.animation_map || 'path' in exported.animation_map || 'url' in exported.animation_map) {
    throw new Error('Packaged animation map must remain declarative safe-token data only');
  }
  if (exported.audio_bindings?.schema_version !== 1) throw new Error('Packaged audio bindings schema mismatch');
  if (exported.audio_bindings?.cues?.skill_cast !== 'package_cast_custom') {
    throw new Error('Custom skill_cast audio binding did not serialize');
  }
  if (Object.keys(exported.audio_bindings?.cues ?? {}).sort().join(',') !== 'basic_attack,hit_received,ready,skill_cast,skill_impact') {
    throw new Error('Packaged audio bindings must contain only the fixed binding vocabulary');
  }
  if (exported.character?.stats?.max_hp !== 222) throw new Error('Exported HP mismatch');
  if (exported.character?.skill_slots?.skill_1 !== 'my_projectile_001') throw new Error('Exported Skill 1 binding mismatch');
  if (!Array.isArray(exported.skills) || exported.skills.length !== 6) throw new Error('Export must contain six referenced skills');
  const exportedSkill1 = exported.skills.find((skill) => skill.id === 'my_projectile_001');
  if (!exportedSkill1 || exportedSkill1.damage !== 41 || exportedSkill1.mp_cost !== 19) {
    throw new Error('Exported authored projectile data mismatch');
  }
  if (!exportedSkill1.timeline || exportedSkill1.timeline.schema_version !== 1 || !Array.isArray(exportedSkill1.timeline.events) || exportedSkill1.timeline.events.length !== 5) {
    throw new Error(`Exported authored timeline mismatch: ${JSON.stringify(exportedSkill1?.timeline)}`);
  }
  if (exportedSkill1.timeline.events.map((event) => event.type).join(',') !== 'animation,vfx,hitbox,audio,hurtbox') {
    throw new Error(`Exported composition vocabulary mismatch: ${JSON.stringify(exportedSkill1.timeline.events)}`);
  }
  if ('composition' in exportedSkill1 || 'composition_recipe' in exportedSkill1 || 'script' in exportedSkill1) {
    throw new Error('Package must persist only expanded declarative timeline events, not executable composition metadata');
  }
  for (const skill of exported.skills) {
    if (skill.id !== 'my_projectile_001' && 'timeline' in skill) {
      throw new Error(`Legacy non-timeline skill shape changed: ${skill.id}`);
    }
  }

  await page.evaluate(() => window.customFighterCreatorSetAnimationSemantic('ready', '../unsafe.gd'));
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorDraftValid === 'false' &&
      document.documentElement.dataset.creatorPackageCanExport === 'false' &&
      (document.documentElement.dataset.creatorDraftError ?? '').includes('safe lowercase token'),
    null,
    { timeout: 5_000 },
  );

  await page.evaluate(() => {
    window.customFighterCreatorSetName('Mutated Draft');
    window.customFighterCreatorSetAnimationMap('ember_vanguard');
    window.customFighterCreatorSetAnimationSemantic('ready', 'transient_ready_custom');
    window.customFighterCreatorSetAudioBinding('skill_cast', 'transient_cast_custom');
    window.customFighterCreatorSetSkillDamage(7);
    window.customFighterCreatorSetSkillMpCost(3);
    window.customFighterCreatorTimelineClear();
  });
  await page.evaluate(() => window.customFighterCreatorSetAnimationAssetTiming(4, 20));
  await page.evaluate(
    ({ dataUrl }) => window.customFighterCreatorImportAnimationPng('transient-ready.png', 'image/png', dataUrl),
    { dataUrl: packageAnimationPngDataUrl },
  );
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorAnimationAssetValid === 'true' &&
      document.documentElement.dataset.creatorAnimationAssetSemantic === 'ready' &&
      document.documentElement.dataset.creatorAnimationAssetAnimationId === 'transient_ready_custom' &&
      document.documentElement.dataset.creatorAnimationAssetFile === 'transient-ready.png' &&
      Number(document.documentElement.dataset.creatorAnimationAssetBytes ?? '0') > 0,
    null,
    { timeout: 5_000 },
  );

  await page.evaluate(
    ({ dataUrl }) => window.customFighterCreatorImportWav('transient-cast.wav', 'audio/wav', dataUrl),
    { dataUrl: packageWavDataUrl },
  );

  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorDraftName === 'Mutated Draft' &&
      document.documentElement.dataset.creatorPackageCanExport === 'true' &&
      document.documentElement.dataset.creatorDraftAnimationMap === 'ember_vanguard' &&
      document.documentElement.dataset.creatorAnimationDraftValid === 'true' &&
      document.documentElement.dataset.creatorAnimationDraftSemantic === 'ready' &&
      document.documentElement.dataset.creatorAnimationDraftAnimationId === 'transient_ready_custom' &&
      document.documentElement.dataset.creatorAnimationAssetValid === 'true' &&
      document.documentElement.dataset.creatorAnimationAssetAnimationId === 'transient_ready_custom' &&
      document.documentElement.dataset.creatorAnimationAssetFile === 'transient-ready.png' &&
      document.documentElement.dataset.creatorAudioDraftValid === 'true' &&
      document.documentElement.dataset.creatorAudioDraftCue === 'transient_cast_custom' &&
      document.documentElement.dataset.creatorAudioAssetValid === 'true' &&
      document.documentElement.dataset.creatorAudioAssetCue === 'transient_cast_custom' &&
      document.documentElement.dataset.creatorAudioAssetFile === 'transient-cast.wav' &&
      document.documentElement.dataset.creatorSkillDraftDamage === '7' &&
      document.documentElement.dataset.creatorSkillDraftMpCost === '3' &&
      document.documentElement.dataset.creatorTimelineCount === '0',
    null,
    { timeout: 5_000 },
  );

  const invalidPackage = JSON.stringify({ ...exported, schema_version: 999 });
  await page.evaluate((json) => window.customFighterCreatorImportPackageJson(json), invalidPackage);
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorPackageImportStatus === 'invalid' &&
      (document.documentElement.dataset.creatorPackageImportError ?? '').includes('unsupported package schema_version') &&
      document.documentElement.dataset.creatorDraftName === 'Mutated Draft' &&
      document.documentElement.dataset.creatorDraftAnimationMap === 'ember_vanguard' &&
      document.documentElement.dataset.creatorAnimationDraftAnimationId === 'transient_ready_custom' &&
      document.documentElement.dataset.creatorAnimationAssetValid === 'true' &&
      document.documentElement.dataset.creatorAnimationAssetAnimationId === 'transient_ready_custom' &&
      document.documentElement.dataset.creatorAnimationAssetFile === 'transient-ready.png' &&
      document.documentElement.dataset.creatorAudioDraftCue === 'transient_cast_custom' &&
      document.documentElement.dataset.creatorAudioAssetValid === 'true' &&
      document.documentElement.dataset.creatorAudioAssetCue === 'transient_cast_custom' &&
      document.documentElement.dataset.creatorSkillDraftDamage === '7' &&
      document.documentElement.dataset.creatorSkillDraftMpCost === '3',
    null,
    { timeout: 5_000 },
  );

  const {
    animation_map: _omittedAnimationMap,
    animation_asset: _omittedAnimationAsset,
    ...exportedWithoutAnimationPayload
  } = exported;
  const missingAnimationPackage = JSON.stringify({
    ...exportedWithoutAnimationPayload,
    character: { ...exported.character, animation_map: 'missing_animation_map' },
  });
  await page.evaluate((json) => window.customFighterCreatorImportPackageJson(json), missingAnimationPackage);
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorPackageImportStatus === 'invalid' &&
      (document.documentElement.dataset.creatorPackageImportError ?? '').includes('animation map file is empty or missing') &&
      document.documentElement.dataset.creatorDraftName === 'Mutated Draft' &&
      document.documentElement.dataset.creatorDraftAnimationMap === 'ember_vanguard' &&
      document.documentElement.dataset.creatorAnimationDraftAnimationId === 'transient_ready_custom' &&
      document.documentElement.dataset.creatorAnimationAssetValid === 'true' &&
      document.documentElement.dataset.creatorAnimationAssetAnimationId === 'transient_ready_custom' &&
      document.documentElement.dataset.creatorAudioDraftCue === 'transient_cast_custom' &&
      document.documentElement.dataset.creatorSkillDraftDamage === '7' &&
      document.documentElement.dataset.creatorSkillDraftMpCost === '3',
    null,
    { timeout: 5_000 },
  );

  const unsafeAnimationPackage = JSON.stringify({
    ...exported,
    animation_map: {
      ...exported.animation_map,
      animations: { ...exported.animation_map.animations, ready: '../payload.gd' },
    },
  });
  await page.evaluate((json) => window.customFighterCreatorImportPackageJson(json), unsafeAnimationPackage);
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorPackageImportStatus === 'invalid' &&
      (document.documentElement.dataset.creatorPackageImportError ?? '').includes('safe lowercase token') &&
      document.documentElement.dataset.creatorDraftName === 'Mutated Draft' &&
      document.documentElement.dataset.creatorAnimationDraftAnimationId === 'transient_ready_custom' &&
      document.documentElement.dataset.creatorAnimationAssetValid === 'true' &&
      document.documentElement.dataset.creatorAnimationAssetAnimationId === 'transient_ready_custom',
    null,
    { timeout: 5_000 },
  );

  const tamperedAnimationBytes = Buffer.from(exported.animation_asset.png_base64, 'base64');
  tamperedAnimationBytes[0] = 0;
  const tamperedAnimationPackage = JSON.stringify({
    ...exported,
    animation_asset: {
      ...exported.animation_asset,
      png_base64: tamperedAnimationBytes.toString('base64'),
    },
  });
  await page.evaluate((json) => window.customFighterCreatorImportPackageJson(json), tamperedAnimationPackage);
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorPackageImportStatus === 'invalid' &&
      (document.documentElement.dataset.creatorPackageImportError ?? '').includes('PNG bytes failed runtime decode') &&
      document.documentElement.dataset.creatorDraftName === 'Mutated Draft' &&
      document.documentElement.dataset.creatorAnimationDraftAnimationId === 'transient_ready_custom' &&
      document.documentElement.dataset.creatorAnimationAssetValid === 'true' &&
      document.documentElement.dataset.creatorAnimationAssetAnimationId === 'transient_ready_custom' &&
      document.documentElement.dataset.creatorAnimationAssetFile === 'transient-ready.png',
    null,
    { timeout: 5_000 },
  );

  const tamperedWavBytes = Buffer.from(exported.audio_asset.wav_base64, 'base64');
  tamperedWavBytes[0] = 0;
  const tamperedWavPackage = JSON.stringify({
    ...exported,
    audio_asset: {
      ...exported.audio_asset,
      wav_base64: tamperedWavBytes.toString('base64'),
    },
  });
  await page.evaluate((json) => window.customFighterCreatorImportPackageJson(json), tamperedWavPackage);
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorPackageImportStatus === 'invalid' &&
      (document.documentElement.dataset.creatorPackageImportError ?? '').includes('RIFF/WAVE framing') &&
      document.documentElement.dataset.creatorAudioAssetValid === 'true' &&
      document.documentElement.dataset.creatorAudioAssetCue === 'transient_cast_custom',
    null,
    { timeout: 5_000 },
  );

  const unsafeAudioPackage = JSON.stringify({
    ...exported,
    audio_bindings: {
      ...exported.audio_bindings,
      cues: { ...exported.audio_bindings.cues, skill_cast: '../payload.wav' },
    },
  });
  await page.evaluate((json) => window.customFighterCreatorImportPackageJson(json), unsafeAudioPackage);
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorPackageImportStatus === 'invalid' &&
      (document.documentElement.dataset.creatorPackageImportError ?? '').includes('audio cue for skill_cast must be a safe lowercase token') &&
      document.documentElement.dataset.creatorDraftName === 'Mutated Draft' &&
      document.documentElement.dataset.creatorAudioDraftCue === 'transient_cast_custom' &&
      document.documentElement.dataset.creatorAudioAssetValid === 'true',
    null,
    { timeout: 5_000 },
  );

  await page.evaluate((json) => window.customFighterCreatorImportPackageJson(json), exportedJson);
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorPackageImportStatus === 'valid' &&
      document.documentElement.dataset.creatorPackageImportCount === '1' &&
      document.documentElement.dataset.creatorDraftName === 'Package Nova' &&
      document.documentElement.dataset.creatorDraftAnimationMap === 'storm_duelist' &&
      document.documentElement.dataset.creatorAnimationDraftAnimationId === 'package_ready_custom' &&
      document.documentElement.dataset.creatorAnimationAssetValid === 'true' &&
      document.documentElement.dataset.creatorAnimationAssetSemantic === 'ready' &&
      document.documentElement.dataset.creatorAnimationAssetAnimationId === 'package_ready_custom' &&
      document.documentElement.dataset.creatorAnimationAssetFile === 'package-ready.png' &&
      Number(document.documentElement.dataset.creatorAnimationAssetBytes ?? '0') > 0 &&
      document.documentElement.dataset.creatorAnimationAssetFrameCount === '4' &&
      document.documentElement.dataset.creatorAnimationAssetFps === '18.000' &&
      document.documentElement.dataset.creatorAnimationAssetError === '' &&
      document.documentElement.dataset.creatorPackageAnimationAssetBound === 'true' &&
      Number(document.documentElement.dataset.creatorPackageAnimationAssetBytes ?? '0') > 0 &&
      document.documentElement.dataset.creatorPackageAnimationAssetSemantic === 'ready' &&
      document.documentElement.dataset.creatorPackageAnimationAssetAnimationId === 'package_ready_custom' &&
      document.documentElement.dataset.creatorAudioDraftValid === 'true' &&
      document.documentElement.dataset.creatorAudioDraftBinding === 'skill_cast' &&
      document.documentElement.dataset.creatorAudioDraftCue === 'package_cast_custom' &&
      document.documentElement.dataset.creatorAudioAssetValid === 'true' &&
      document.documentElement.dataset.creatorAudioAssetBinding === 'skill_cast' &&
      document.documentElement.dataset.creatorAudioAssetCue === 'package_cast_custom' &&
      document.documentElement.dataset.creatorAudioAssetFile === 'package-cast.wav' &&
      document.documentElement.dataset.creatorAudioAssetBytes === '844' &&
      document.documentElement.dataset.creatorAudioAssetError === '' &&
      document.documentElement.dataset.creatorPackageAudioAssetBound === 'true' &&
      document.documentElement.dataset.creatorPackageAudioAssetBytes === '844' &&
      document.documentElement.dataset.creatorDraftMaxHp === '222' &&
      document.documentElement.dataset.creatorSkillDraftName === 'Package Bolt' &&
      document.documentElement.dataset.creatorSkillDraftDamage === '41' &&
      document.documentElement.dataset.creatorSkillDraftMpCost === '19' &&
      Math.abs(Number(document.documentElement.dataset.creatorSkillDraftCooldown) - 2.25) < 0.001 &&
      document.documentElement.dataset.creatorTimelineCount === '5' &&
      document.documentElement.dataset.creatorTimelineValid === 'true' &&
      document.documentElement.dataset.creatorPreviewCanLaunch === 'true',
    null,
    { timeout: 10_000 },
  );

  await page.evaluate(() => window.customFighterCreatorPreview());
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.appMode === 'training' &&
      document.documentElement.dataset.creatorPreviewActive === 'true' &&
      document.documentElement.dataset.playerCharacterName === 'Package Nova' &&
      document.documentElement.dataset.playerAnimationMapLoaded === 'true' &&
      document.documentElement.dataset.playerAnimationMapId === 'storm_duelist' &&
      document.documentElement.dataset.playerAnimationSemantic === 'ready' &&
      document.documentElement.dataset.playerAnimationId === 'package_ready_custom' &&
      document.documentElement.dataset.creatorPreviewAnimationOverrideActive === 'true' &&
      document.documentElement.dataset.playerAudioBindingsLoaded === 'true' &&
      document.documentElement.dataset.creatorPreviewAudioBindingsActive === 'true' &&
      document.documentElement.dataset.playerAudioCueSkillCast === 'package_cast_custom' &&
      document.documentElement.dataset.playerMaxHp === '222' &&
      document.documentElement.dataset.playerRuntimeSkill1 === 'my_projectile_001' &&
      document.documentElement.dataset.creatorPreviewRuntimeSkillDamage === '41' &&
      document.documentElement.dataset.creatorPreviewRuntimeSkillMpCost === '19',
    null,
    { timeout: 60_000 },
  );

  await page.keyboard.down('u');
  await page.waitForFunction(() => Number(document.documentElement.dataset.playerMp) === 81, null, { timeout: 3_000 });
  await page.keyboard.up('u');
  await page.waitForFunction(
    () =>
      Number(document.documentElement.dataset.dummyHp) === 59 &&
      document.documentElement.dataset.lastSkillHit === 'true' &&
      Number(document.documentElement.dataset.skillHitCount) >= 1 &&
      document.documentElement.dataset.creatorPreviewTimelineLastAudioCue === 'package_cast_custom',
    null,
    { timeout: 5_000 },
  );

  console.log('WEB_CREATOR_PACKAGE_SMOKE_PASSED export=true schema=2 noVfxFallback=true animationMapRoundTrip=true animationPreview=true animationPngPackageRoundTrip=true invalidImportPreservesAnimationPng=true validImportRestoresAnimationPng=true tamperedPackagedAnimationPngBlocked=true semanticInvalidExportBlocked=true semanticPackageRoundTrip=true semanticTransientReset=true audioBindingPackageRoundTrip=true wavPackageRoundTrip=true invalidImportPreservesWav=true validImportRestoresWav=true tamperedPackagedWavBlocked=true unsafePackagedAudioBlocked=true unsafePackagedAnimationBlocked=true missingAnimationMapBlocked=true timelineRoundTrip=true compositionExpanded=true invalidPreserved=true import=true authoredHp=222 authoredDamage=41 authoredMpCost=19 previewCast=true');
  await page.close();
} finally {
  await browser.close();
}
