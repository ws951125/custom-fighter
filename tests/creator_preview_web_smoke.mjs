import { chromium } from 'playwright';

const baseUrl = process.env.CUSTOM_FIGHTER_WEB_URL ?? 'http://127.0.0.1:8000';
const browserChannel = process.env.BROWSER_CHANNEL?.trim();
const launchOptions = { headless: true };
if (browserChannel) launchOptions.channel = browserChannel;

console.log(`CREATOR_PREVIEW_BROWSER=${browserChannel || 'playwright-chromium'}`);
console.log(`CREATOR_PREVIEW_BASE_URL=${baseUrl}`);

const browser = await chromium.launch(launchOptions);
let page;
let diagnosticStage = 'browser-launch';

async function diagnosticSnapshot() {
  if (!page) return {};
  try {
    return await page.evaluate(() => {
      const d = document.documentElement.dataset;
      const keys = [
        'appMode',
        'creatorStudioReady',
        'creatorPreviewReady',
        'creatorTimelineReady',
        'creatorDraftValid',
        'creatorSkillDraftValid',
        'creatorPreviewCanLaunch',
        'creatorPreviewError',
        'creatorTimelineCount',
        'creatorTimelineValid',
        'creatorPreviewActive',
        'playerCharacterSource',
        'playerCharacterName',
        'playerMp',
        'playerHp',
        'dummyHp',
        'playerIncomingHitCount',
        'lastPlayerIncomingDamage',
        'lastPlayerDamageDealt',
        'lastPlayerHitCountered',
        'trainingIncomingHitReady',
        'lastSkillHit',
        'skillHitCount',
        'playerAnimationSemantic',
        'playerAnimationId',
        'playerAnimationMapId',
        'creatorPreviewAnimationOverrideActive',
        'creatorAnimationAssetValid',
        'creatorAnimationAssetSemantic',
        'creatorAnimationAssetAnimationId',
        'creatorAnimationAssetFile',
        'creatorAnimationAssetBytes',
        'creatorAnimationAssetFrameCount',
        'creatorAnimationAssetFps',
        'creatorAnimationAssetError',
        'creatorAudioDraftValid',
        'creatorAudioDraftBinding',
        'creatorAudioDraftCue',
        'creatorAudioAssetValid',
        'creatorAudioAssetBinding',
        'creatorAudioAssetCue',
        'creatorAudioAssetFile',
        'creatorAudioAssetBytes',
        'creatorAudioAssetDurationMs',
        'creatorAudioAssetError',
        'playerAudioBindingsLoaded',
        'creatorPreviewAudioBindingsActive',
        'playerAudioCueBasicAttack',
        'playerAudioCueHitReceived',
        'playerAudioCueSkillCast',
        'playerAudioCueSkillImpact',
        'creatorPreviewAudioAssetActive',
        'creatorPreviewAudioAssetLoaded',
        'creatorPreviewAudioAssetCue',
        'creatorPreviewAudioAssetBytes',
        'creatorPreviewAudioAssetLoadError',
        'creatorPreviewAudioPlaybackCount',
        'creatorPreviewAudioLastPlayedCue',
        'creatorPreviewTimelineRunning',
        'creatorPreviewTimelineElapsed',
        'creatorPreviewTimelineTransitionCount',
        'creatorPreviewTimelineLastEventId',
        'creatorPreviewTimelineLastEventType',
        'creatorPreviewTimelineLastPhase',
        'creatorPreviewTimelineAnimationSemantic',
        'creatorPreviewTimelineLastVfx',
        'creatorPreviewTimelineVfxActive',
        'creatorPreviewTimelineLastAudioCue',
        'creatorPreviewTimelineAudioEventCount',
        'creatorPreviewTimelineHitboxActiveCount',
        'creatorPreviewTimelineHurtboxActiveCount',
        'creatorPreviewTimelineHitboxes',
        'creatorPreviewTimelineHurtboxes',
      ];
      return Object.fromEntries(keys.map((key) => [key, d[key] ?? null]));
    });
  } catch (error) {
    return { snapshotError: String(error) };
  }
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

function annotationSafe(value) {
  return String(value).replace(/%/g, '%25').replace(/\r/g, '%0D').replace(/\n/g, '%0A');
}

try {
  diagnosticStage = 'creator-navigation';
  const creatorUrl = new URL(baseUrl);
  creatorUrl.searchParams.set('mode', 'creator');
  page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const response = await page.goto(creatorUrl.toString(), { waitUntil: 'domcontentloaded', timeout: 60_000 });
  if (!response?.ok()) throw new Error(`Creator preview URL returned HTTP ${response?.status() ?? 'unknown'}`);

  diagnosticStage = 'creator-ready';
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.appMode === 'creator' &&
      document.documentElement.dataset.creatorStudioReady === 'true' &&
      document.documentElement.dataset.creatorPreviewReady === 'true' &&
      document.documentElement.dataset.creatorTimelineReady === 'true' &&
      typeof window.customFighterCreatorPreview === 'function' &&
      typeof window.customFighterCreatorSetAnimationSemantic === 'function' &&
      typeof window.customFighterCreatorImportAnimationPng === 'function' &&
      typeof window.customFighterCreatorSetAnimationAssetTiming === 'function' &&
      typeof window.customFighterCreatorSetAudioBinding === 'function' &&
      typeof window.customFighterCreatorImportWav === 'function' &&
      typeof window.customFighterCreatorSetSkillMpCost === 'function' &&
      typeof window.customFighterCreatorSetSkillCooldown === 'function' &&
      typeof window.customFighterCreatorTimelineAdd === 'function' &&
      typeof window.customFighterCreatorTimelineClear === 'function' &&
      typeof window.customFighterCreatorTimelineApplyComposition === 'function' &&
      document.documentElement.dataset.creatorTimelineCompositionReady === 'true',
    null,
    { timeout: 60_000 },
  );

  diagnosticStage = 'invalid-preview-block';
  await page.evaluate(() => window.customFighterCreatorSetName(''));
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorDraftValid === 'false' &&
      document.documentElement.dataset.creatorPreviewCanLaunch === 'false',
    null,
    { timeout: 5_000 },
  );
  await page.evaluate(() => window.customFighterCreatorPreview());
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.appMode === 'creator' &&
      (document.documentElement.dataset.creatorPreviewError ?? '').includes('Fix invalid'),
    null,
    { timeout: 5_000 },
  );

  diagnosticStage = 'author-timeline';
  await page.evaluate(() => {
    window.customFighterCreatorSetName('Preview Nova');
    window.customFighterCreatorSetAnimationSemantic('ready', 'preview_ready_custom');
    window.customFighterCreatorSetAudioBinding('skill_cast', 'preview_cast_custom');
    window.customFighterCreatorSetMaxHp(180);
    window.customFighterCreatorSetSkillName('Nova Bolt');
    window.customFighterCreatorSetSkillDamage(33);
    window.customFighterCreatorSetSkillMpCost(17);
    window.customFighterCreatorSetSkillCooldown(2.4);
    window.customFighterCreatorTimelineClear();
    window.customFighterCreatorTimelineApplyComposition('guarded_impact', 0);
  });

  await page.evaluate(() => window.customFighterCreatorSetAnimationAssetTiming(4, 18));
  const previewAnimationPngDataUrl = await page.evaluate(() => {
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
    ({ dataUrl }) => window.customFighterCreatorImportAnimationPng('preview-ready.png', 'image/png', dataUrl),
    { dataUrl: previewAnimationPngDataUrl },
  );

  const previewWavDataUrl = pcmWavDataUrl();
  await page.evaluate(
    ({ dataUrl }) => window.customFighterCreatorImportWav('preview-cast.wav', 'audio/wav', dataUrl),
    { dataUrl: previewWavDataUrl },
  );

  diagnosticStage = 'authored-timeline-valid';
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorDraftValid === 'true' &&
      document.documentElement.dataset.creatorSkillDraftValid === 'true' &&
      document.documentElement.dataset.creatorDraftName === 'Preview Nova' &&
      document.documentElement.dataset.creatorAnimationDraftValid === 'true' &&
      document.documentElement.dataset.creatorAnimationDraftSemantic === 'ready' &&
      document.documentElement.dataset.creatorAnimationDraftAnimationId === 'preview_ready_custom' &&
      document.documentElement.dataset.creatorAnimationAssetValid === 'true' &&
      document.documentElement.dataset.creatorAnimationAssetSemantic === 'ready' &&
      document.documentElement.dataset.creatorAnimationAssetAnimationId === 'preview_ready_custom' &&
      document.documentElement.dataset.creatorAnimationAssetFile === 'preview-ready.png' &&
      Number(document.documentElement.dataset.creatorAnimationAssetBytes ?? '0') > 0 &&
      document.documentElement.dataset.creatorAnimationAssetFrameCount === '4' &&
      document.documentElement.dataset.creatorAnimationAssetFps === '18.000' &&
      document.documentElement.dataset.creatorAnimationAssetError === '' &&
      document.documentElement.dataset.creatorAudioDraftValid === 'true' &&
      document.documentElement.dataset.creatorAudioAssetValid === 'true' &&
      document.documentElement.dataset.creatorAudioAssetBinding === 'skill_cast' &&
      document.documentElement.dataset.creatorAudioAssetCue === 'preview_cast_custom' &&
      document.documentElement.dataset.creatorAudioAssetFile === 'preview-cast.wav' &&
      document.documentElement.dataset.creatorAudioAssetBytes === '844' &&
      document.documentElement.dataset.creatorAudioAssetDurationMs === '100' &&
      document.documentElement.dataset.creatorAudioAssetError === '' &&
      document.documentElement.dataset.creatorDraftMaxHp === '180' &&
      document.documentElement.dataset.creatorSkillDraftName === 'Nova Bolt' &&
      document.documentElement.dataset.creatorSkillDraftDamage === '33' &&
      document.documentElement.dataset.creatorSkillDraftMpCost === '17' &&
      Math.abs(Number(document.documentElement.dataset.creatorSkillDraftCooldown) - 2.4) < 0.001 &&
      document.documentElement.dataset.creatorTimelineCount === '5' &&
      document.documentElement.dataset.creatorTimelineValid === 'true' &&
      document.documentElement.dataset.creatorTimelineCompositionLastRecipe === 'guarded_impact' &&
      document.documentElement.dataset.creatorTimelineCompositionLastAddedCount === '5' &&
      document.documentElement.dataset.creatorTimelineCompositionError === '' &&
      document.documentElement.dataset.creatorPreviewCanLaunch === 'true',
    null,
    { timeout: 5_000 },
  );

  diagnosticStage = 'training-preview-launch';
  await page.evaluate(() => window.customFighterCreatorPreview());
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.appMode === 'training' &&
      document.documentElement.dataset.creatorPreviewActive === 'true' &&
      document.documentElement.dataset.playerCharacterSource === 'creator_preview_session' &&
      document.documentElement.dataset.playerCharacterName === 'Preview Nova' &&
      document.documentElement.dataset.creatorPreviewAnimationOverrideActive === 'true' &&
      document.documentElement.dataset.playerAudioBindingsLoaded === 'true' &&
      document.documentElement.dataset.creatorPreviewAudioBindingsActive === 'true' &&
      document.documentElement.dataset.playerAudioCueSkillCast === 'preview_cast_custom' &&
      document.documentElement.dataset.creatorPreviewAudioAssetActive === 'true' &&
      document.documentElement.dataset.creatorPreviewAudioAssetLoaded === 'true' &&
      document.documentElement.dataset.creatorPreviewAudioAssetCue === 'preview_cast_custom' &&
      document.documentElement.dataset.creatorPreviewAudioAssetBytes === '844' &&
      document.documentElement.dataset.creatorPreviewAudioAssetLoadError === '' &&
      document.documentElement.dataset.creatorPreviewAudioPlaybackCount === '0' &&
      document.documentElement.dataset.creatorPreviewAudioLastPlayedCue === '' &&
      document.documentElement.dataset.playerAnimationMapLoaded === 'true' &&
      document.documentElement.dataset.playerAnimationMapId === 'ember_vanguard' &&
      document.documentElement.dataset.playerAnimationSemantic === 'ready' &&
      document.documentElement.dataset.playerAnimationId === 'preview_ready_custom' &&
      document.documentElement.dataset.creatorPreviewAnimationAssetRuntimeLoaded === 'true' &&
      document.documentElement.dataset.creatorPreviewAnimationAssetRuntimeActive === 'true' &&
      document.documentElement.dataset.creatorPreviewAnimationAssetRuntimeSemantic === 'ready' &&
      document.documentElement.dataset.creatorPreviewAnimationAssetRuntimeAnimationId === 'preview_ready_custom' &&
      document.documentElement.dataset.creatorPreviewAnimationAssetRuntimeFrameCount === '4' &&
      document.documentElement.dataset.creatorPreviewAnimationAssetRuntimeLoadError === '' &&
      document.documentElement.dataset.playerMaxHp === '180' &&
      document.documentElement.dataset.playerRuntimeSkill1 === 'my_projectile_001' &&
      document.documentElement.dataset.skillId === 'my_projectile_001' &&
      document.documentElement.dataset.creatorPreviewRuntimeSkillDamage === '33' &&
      document.documentElement.dataset.creatorPreviewRuntimeSkillMpCost === '17' &&
      Math.abs(Number(document.documentElement.dataset.creatorPreviewRuntimeSkillCooldown) - 2.4) < 0.001 &&
      document.documentElement.dataset.creatorPreviewReturnReady === 'true' &&
      typeof window.customFighterPreviewReturnToCreator === 'function',
    null,
    { timeout: 60_000 },
  );

  diagnosticStage = 'animation-png-runtime-render';
  await page.waitForFunction(
    () =>
      Number(document.documentElement.dataset.creatorPreviewAnimationAssetRuntimeMaxFrameSeen ?? '0') >= 1 &&
      Number(document.documentElement.dataset.creatorPreviewAnimationAssetRuntimeDrawCount ?? '0') > 0 &&
      Number(document.documentElement.dataset.creatorPreviewAnimationAssetRuntimeLastDrawnFrame ?? '-1') >= 0,
    null,
    { timeout: 5_000 },
  );

  diagnosticStage = 'skill-cast';
  await page.keyboard.down('u');
  await page.waitForFunction(
    () => Number(document.documentElement.dataset.playerMp) === 83,
    null,
    { timeout: 3_000 },
  );
  await page.keyboard.up('u');

  diagnosticStage = 'timeline-overlap-window';
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorPreviewTimelineRunning === 'true' &&
      Number(document.documentElement.dataset.creatorPreviewTimelineTransitionCount ?? '0') >= 5 &&
      document.documentElement.dataset.creatorPreviewTimelineAnimationSemantic === 'skill_3' &&
      document.documentElement.dataset.playerAnimationSemantic === 'skill_3' &&
      document.documentElement.dataset.creatorPreviewAnimationAssetRuntimeActive === 'false' &&
      document.documentElement.dataset.creatorPreviewTimelineLastVfx === 'prototype_impact' &&
      document.documentElement.dataset.creatorPreviewTimelineVfxActive === 'true' &&
      document.documentElement.dataset.creatorPreviewTimelineLastAudioCue === 'preview_cast_custom' &&
      Number(document.documentElement.dataset.creatorPreviewTimelineAudioEventCount ?? '0') >= 1 &&
      Number(document.documentElement.dataset.creatorPreviewAudioPlaybackCount ?? '0') >= 1 &&
      document.documentElement.dataset.creatorPreviewAudioLastPlayedCue === 'preview_cast_custom' &&
      Number(document.documentElement.dataset.creatorPreviewTimelineHitboxActiveCount ?? '0') >= 1 &&
      Number(document.documentElement.dataset.creatorPreviewTimelineHurtboxActiveCount ?? '0') >= 1,
    null,
    { timeout: 5_000 },
  );

  diagnosticStage = 'spatial-payload';
  const runtimeHitboxes = JSON.parse(await page.evaluate(() => document.documentElement.dataset.creatorPreviewTimelineHitboxes ?? '[]'));
  const runtimeHurtboxes = JSON.parse(await page.evaluate(() => document.documentElement.dataset.creatorPreviewTimelineHurtboxes ?? '[]'));
  if (Number(runtimeHitboxes[0]?.half_width) !== 40 || Number(runtimeHitboxes[0]?.offset_x) !== 24) {
    throw new Error(`Training hitbox spatial payload mismatch: ${JSON.stringify(runtimeHitboxes)}`);
  }
  if (Number(runtimeHurtboxes[0]?.half_depth) !== 0.09 || Number(runtimeHurtboxes[0]?.offset_depth) !== 0.03) {
    throw new Error(`Training hurtbox spatial payload mismatch: ${JSON.stringify(runtimeHurtboxes)}`);
  }

  diagnosticStage = 'legacy-projectile-hit';
  await page.waitForFunction(
    () =>
      Number(document.documentElement.dataset.dummyHp) === 67 &&
      document.documentElement.dataset.lastSkillHit === 'true' &&
      Number(document.documentElement.dataset.skillHitCount) >= 1,
    null,
    { timeout: 5_000 },
  );

  diagnosticStage = 'timeline-completion';
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorPreviewTimelineRunning === 'false' &&
      Number(document.documentElement.dataset.creatorPreviewTimelineTransitionCount ?? '0') >= 9 &&
      Number(document.documentElement.dataset.creatorPreviewTimelineHitboxActiveCount ?? '-1') === 0 &&
      Number(document.documentElement.dataset.creatorPreviewTimelineHurtboxActiveCount ?? '-1') === 0,
    null,
    { timeout: 5_000 },
  );

  diagnosticStage = 'animation-png-runtime-resume';
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.playerAnimationSemantic === 'ready' &&
      document.documentElement.dataset.playerAnimationId === 'preview_ready_custom' &&
      document.documentElement.dataset.creatorPreviewAnimationAssetRuntimeActive === 'true' &&
      Number(document.documentElement.dataset.creatorPreviewAnimationAssetRuntimeDrawCount ?? '0') > 0,
    null,
    { timeout: 5_000 },
  );

  diagnosticStage = 'creator-return';
  await page.evaluate(() => window.customFighterPreviewReturnToCreator());
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.appMode === 'creator' &&
      document.documentElement.dataset.creatorStudioReady === 'true' &&
      document.documentElement.dataset.creatorDraftName === 'Preview Nova' &&
      document.documentElement.dataset.creatorAnimationDraftValid === 'true' &&
      document.documentElement.dataset.creatorAnimationDraftSemantic === 'ready' &&
      document.documentElement.dataset.creatorAnimationDraftAnimationId === 'preview_ready_custom' &&
      document.documentElement.dataset.creatorAnimationAssetValid === 'true' &&
      document.documentElement.dataset.creatorAnimationAssetSemantic === 'ready' &&
      document.documentElement.dataset.creatorAnimationAssetAnimationId === 'preview_ready_custom' &&
      document.documentElement.dataset.creatorAnimationAssetFile === 'preview-ready.png' &&
      Number(document.documentElement.dataset.creatorAnimationAssetBytes ?? '0') > 0 &&
      document.documentElement.dataset.creatorAnimationAssetFrameCount === '4' &&
      document.documentElement.dataset.creatorAnimationAssetFps === '18.000' &&
      document.documentElement.dataset.creatorAnimationAssetError === '' &&
      document.documentElement.dataset.creatorAudioDraftValid === 'true' &&
      document.documentElement.dataset.creatorAudioAssetValid === 'true' &&
      document.documentElement.dataset.creatorAudioAssetBinding === 'skill_cast' &&
      document.documentElement.dataset.creatorAudioAssetCue === 'preview_cast_custom' &&
      document.documentElement.dataset.creatorAudioAssetFile === 'preview-cast.wav' &&
      document.documentElement.dataset.creatorAudioAssetBytes === '844' &&
      document.documentElement.dataset.creatorDraftMaxHp === '180' &&
      document.documentElement.dataset.creatorSkillDraftName === 'Nova Bolt' &&
      document.documentElement.dataset.creatorSkillDraftDamage === '33' &&
      document.documentElement.dataset.creatorSkillDraftMpCost === '17' &&
      Math.abs(Number(document.documentElement.dataset.creatorSkillDraftCooldown) - 2.4) < 0.001 &&
      document.documentElement.dataset.creatorTimelineCount === '5' &&
      document.documentElement.dataset.creatorTimelineValid === 'true',
    null,
    { timeout: 10_000 },
  );

  diagnosticStage = 'audio-binding-round-trip';
  const restoredAudioDraft = JSON.parse(
    await page.evaluate(() => document.documentElement.dataset.creatorAudioDraftJson ?? '{}'),
  );
  if (restoredAudioDraft?.cues?.skill_cast !== 'preview_cast_custom') {
    throw new Error(`Audio binding draft round-trip mismatch: ${JSON.stringify(restoredAudioDraft)}`);
  }

  diagnosticStage = 'author-basic-attack-audio';
  await page.evaluate(() => {
    window.customFighterCreatorSetAudioBinding('basic_attack', 'preview_attack_custom');
  });
  const basicAttackWavDataUrl = pcmWavDataUrl();
  await page.evaluate(
    ({ dataUrl }) => window.customFighterCreatorImportWav('preview-attack.wav', 'audio/wav', dataUrl),
    { dataUrl: basicAttackWavDataUrl },
  );
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorAudioDraftValid === 'true' &&
      document.documentElement.dataset.creatorAudioAssetValid === 'true' &&
      document.documentElement.dataset.creatorAudioAssetBinding === 'basic_attack' &&
      document.documentElement.dataset.creatorAudioAssetCue === 'preview_attack_custom' &&
      document.documentElement.dataset.creatorAudioAssetFile === 'preview-attack.wav' &&
      document.documentElement.dataset.creatorPreviewCanLaunch === 'true',
    null,
    { timeout: 5_000 },
  );

  diagnosticStage = 'basic-attack-preview-launch';
  await page.evaluate(() => window.customFighterCreatorPreview());
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.appMode === 'training' &&
      document.documentElement.dataset.creatorPreviewActive === 'true' &&
      document.documentElement.dataset.playerAudioBindingsLoaded === 'true' &&
      document.documentElement.dataset.playerAudioCueBasicAttack === 'preview_attack_custom' &&
      document.documentElement.dataset.creatorPreviewAudioAssetActive === 'true' &&
      document.documentElement.dataset.creatorPreviewAudioAssetLoaded === 'true' &&
      document.documentElement.dataset.creatorPreviewAudioAssetCue === 'preview_attack_custom' &&
      document.documentElement.dataset.creatorPreviewAudioPlaybackCount === '0' &&
      document.documentElement.dataset.creatorPreviewAudioLastPlayedCue === '',
    null,
    { timeout: 60_000 },
  );

  diagnosticStage = 'basic-attack-wav-playback';
  await page.keyboard.press('j');
  await page.waitForFunction(
    () =>
      Number(document.documentElement.dataset.creatorPreviewAudioPlaybackCount ?? '0') >= 1 &&
      document.documentElement.dataset.creatorPreviewAudioLastPlayedCue === 'preview_attack_custom',
    null,
    { timeout: 5_000 },
  );

  diagnosticStage = 'basic-attack-return';
  await page.evaluate(() => window.customFighterPreviewReturnToCreator());
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.appMode === 'creator' &&
      document.documentElement.dataset.creatorStudioReady === 'true' &&
      document.documentElement.dataset.creatorAudioAssetValid === 'true' &&
      document.documentElement.dataset.creatorAudioAssetBinding === 'basic_attack' &&
      document.documentElement.dataset.creatorAudioAssetCue === 'preview_attack_custom' &&
      document.documentElement.dataset.creatorAudioAssetFile === 'preview-attack.wav',
    null,
    { timeout: 10_000 },
  );

  diagnosticStage = 'author-skill-impact-audio';
  await page.evaluate(() => {
    window.customFighterCreatorSetAudioBinding('skill_impact', 'preview_impact_custom');
  });
  const skillImpactWavDataUrl = pcmWavDataUrl();
  await page.evaluate(
    ({ dataUrl }) => window.customFighterCreatorImportWav('preview-impact.wav', 'audio/wav', dataUrl),
    { dataUrl: skillImpactWavDataUrl },
  );
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorAudioDraftValid === 'true' &&
      document.documentElement.dataset.creatorAudioAssetValid === 'true' &&
      document.documentElement.dataset.creatorAudioAssetBinding === 'skill_impact' &&
      document.documentElement.dataset.creatorAudioAssetCue === 'preview_impact_custom' &&
      document.documentElement.dataset.creatorAudioAssetFile === 'preview-impact.wav' &&
      document.documentElement.dataset.creatorPreviewCanLaunch === 'true',
    null,
    { timeout: 5_000 },
  );

  diagnosticStage = 'skill-impact-preview-launch';
  await page.evaluate(() => window.customFighterCreatorPreview());
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.appMode === 'training' &&
      document.documentElement.dataset.creatorPreviewActive === 'true' &&
      document.documentElement.dataset.playerAudioBindingsLoaded === 'true' &&
      document.documentElement.dataset.playerAudioCueSkillImpact === 'preview_impact_custom' &&
      document.documentElement.dataset.creatorPreviewAudioAssetActive === 'true' &&
      document.documentElement.dataset.creatorPreviewAudioAssetLoaded === 'true' &&
      document.documentElement.dataset.creatorPreviewAudioAssetCue === 'preview_impact_custom' &&
      document.documentElement.dataset.creatorPreviewAudioPlaybackCount === '0' &&
      document.documentElement.dataset.creatorPreviewAudioLastPlayedCue === '',
    null,
    { timeout: 60_000 },
  );

  diagnosticStage = 'skill-impact-cast';
  await page.keyboard.down('u');
  await page.waitForFunction(
    () => Number(document.documentElement.dataset.playerMp) === 83,
    null,
    { timeout: 3_000 },
  );
  await page.keyboard.up('u');

  diagnosticStage = 'skill-impact-wav-playback';
  await page.waitForFunction(
    () =>
      Number(document.documentElement.dataset.skillHitCount ?? '0') >= 1 &&
      document.documentElement.dataset.lastSkillHit === 'true' &&
      Number(document.documentElement.dataset.creatorPreviewAudioPlaybackCount ?? '0') >= 1 &&
      document.documentElement.dataset.creatorPreviewAudioLastPlayedCue === 'preview_impact_custom',
    null,
    { timeout: 6_000 },
  );

  diagnosticStage = 'skill-impact-return';
  await page.evaluate(() => window.customFighterPreviewReturnToCreator());
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.appMode === 'creator' &&
      document.documentElement.dataset.creatorStudioReady === 'true' &&
      document.documentElement.dataset.creatorAudioAssetValid === 'true' &&
      document.documentElement.dataset.creatorAudioAssetBinding === 'skill_impact' &&
      document.documentElement.dataset.creatorAudioAssetCue === 'preview_impact_custom' &&
      document.documentElement.dataset.creatorAudioAssetFile === 'preview-impact.wav',
    null,
    { timeout: 10_000 },
  );

  diagnosticStage = 'author-hit-received-audio';
  await page.evaluate(() => {
    window.customFighterCreatorSetAudioBinding('hit_received', 'preview_hit_custom');
  });
  const hitReceivedWavDataUrl = pcmWavDataUrl();
  await page.evaluate(
    ({ dataUrl }) => window.customFighterCreatorImportWav('preview-hit.wav', 'audio/wav', dataUrl),
    { dataUrl: hitReceivedWavDataUrl },
  );
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorAudioDraftValid === 'true' &&
      document.documentElement.dataset.creatorAudioAssetValid === 'true' &&
      document.documentElement.dataset.creatorAudioAssetBinding === 'hit_received' &&
      document.documentElement.dataset.creatorAudioAssetCue === 'preview_hit_custom' &&
      document.documentElement.dataset.creatorAudioAssetFile === 'preview-hit.wav' &&
      document.documentElement.dataset.creatorPreviewCanLaunch === 'true',
    null,
    { timeout: 5_000 },
  );

  diagnosticStage = 'hit-received-preview-launch';
  await page.evaluate(() => window.customFighterCreatorPreview());
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.appMode === 'training' &&
      document.documentElement.dataset.creatorPreviewActive === 'true' &&
      document.documentElement.dataset.playerAudioBindingsLoaded === 'true' &&
      document.documentElement.dataset.playerAudioCueHitReceived === 'preview_hit_custom' &&
      document.documentElement.dataset.creatorPreviewAudioAssetActive === 'true' &&
      document.documentElement.dataset.creatorPreviewAudioAssetLoaded === 'true' &&
      document.documentElement.dataset.creatorPreviewAudioAssetCue === 'preview_hit_custom' &&
      document.documentElement.dataset.creatorPreviewAudioPlaybackCount === '0' &&
      document.documentElement.dataset.creatorPreviewAudioLastPlayedCue === '' &&
      document.documentElement.dataset.trainingIncomingHitReady === 'true' &&
      typeof window.customFighterTrainingIncomingHit === 'function',
    null,
    { timeout: 60_000 },
  );

  diagnosticStage = 'hit-received-damage';
  await page.evaluate(() => window.customFighterTrainingIncomingHit(9));

  diagnosticStage = 'hit-received-wav-playback';
  await page.waitForFunction(
    () =>
      Number(document.documentElement.dataset.playerIncomingHitCount ?? '0') === 1 &&
      Number(document.documentElement.dataset.lastPlayerIncomingDamage ?? '0') === 9 &&
      Number(document.documentElement.dataset.lastPlayerDamageDealt ?? '0') === 9 &&
      document.documentElement.dataset.lastPlayerHitCountered === 'false' &&
      Number(document.documentElement.dataset.creatorPreviewAudioPlaybackCount ?? '0') >= 1 &&
      document.documentElement.dataset.creatorPreviewAudioLastPlayedCue === 'preview_hit_custom',
    null,
    { timeout: 5_000 },
  );

  diagnosticStage = 'hit-received-return';
  await page.evaluate(() => window.customFighterPreviewReturnToCreator());
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.appMode === 'creator' &&
      document.documentElement.dataset.creatorStudioReady === 'true' &&
      document.documentElement.dataset.creatorAudioAssetValid === 'true' &&
      document.documentElement.dataset.creatorAudioAssetBinding === 'hit_received' &&
      document.documentElement.dataset.creatorAudioAssetCue === 'preview_hit_custom' &&
      document.documentElement.dataset.creatorAudioAssetFile === 'preview-hit.wav',
    null,
    { timeout: 10_000 },
  );

  diagnosticStage = 'author-ready-audio';
  await page.evaluate(() => {
    window.customFighterCreatorSetAudioBinding('ready', 'preview_ready_audio_custom');
  });
  const readyWavDataUrl = pcmWavDataUrl();
  await page.evaluate(
    ({ dataUrl }) => window.customFighterCreatorImportWav('preview-ready.wav', 'audio/wav', dataUrl),
    { dataUrl: readyWavDataUrl },
  );
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorAudioDraftValid === 'true' &&
      document.documentElement.dataset.creatorAudioAssetValid === 'true' &&
      document.documentElement.dataset.creatorAudioAssetBinding === 'ready' &&
      document.documentElement.dataset.creatorAudioAssetCue === 'preview_ready_audio_custom' &&
      document.documentElement.dataset.creatorAudioAssetFile === 'preview-ready.wav' &&
      document.documentElement.dataset.creatorPreviewCanLaunch === 'true',
    null,
    { timeout: 5_000 },
  );

  diagnosticStage = 'ready-preview-launch';
  await page.evaluate(() => window.customFighterCreatorPreview());
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.appMode === 'training' &&
      document.documentElement.dataset.creatorPreviewActive === 'true' &&
      document.documentElement.dataset.playerAudioBindingsLoaded === 'true' &&
      document.documentElement.dataset.playerAudioCueReady === 'preview_ready_audio_custom' &&
      document.documentElement.dataset.creatorPreviewAudioAssetActive === 'true' &&
      document.documentElement.dataset.creatorPreviewAudioAssetLoaded === 'true' &&
      document.documentElement.dataset.creatorPreviewAudioAssetCue === 'preview_ready_audio_custom' &&
      document.documentElement.dataset.creatorPreviewReadyAudioArmed === 'true' &&
      document.documentElement.dataset.creatorPreviewReadyAudioUnlockObserved === 'false' &&
      document.documentElement.dataset.creatorPreviewReadyAudioPlayed === 'false' &&
      document.documentElement.dataset.creatorPreviewReadyAudioUnlockKind === '' &&
      document.documentElement.dataset.creatorPreviewAudioPlaybackCount === '0' &&
      document.documentElement.dataset.creatorPreviewAudioLastPlayedCue === '',
    null,
    { timeout: 60_000 },
  );

  diagnosticStage = 'ready-autoplay-blocked-before-input';
  await page.waitForTimeout(300);
  const preUnlockReadyAudio = await page.evaluate(() => ({
    count: Number(document.documentElement.dataset.creatorPreviewAudioPlaybackCount ?? '0'),
    armed: document.documentElement.dataset.creatorPreviewReadyAudioArmed,
    unlockObserved: document.documentElement.dataset.creatorPreviewReadyAudioUnlockObserved,
    played: document.documentElement.dataset.creatorPreviewReadyAudioPlayed,
  }));
  if (
    preUnlockReadyAudio.count !== 0 ||
    preUnlockReadyAudio.armed !== 'true' ||
    preUnlockReadyAudio.unlockObserved !== 'false' ||
    preUnlockReadyAudio.played !== 'false'
  ) {
    throw new Error(`Ready WAV autoplay gate changed before user input: ${JSON.stringify(preUnlockReadyAudio)}`);
  }

  diagnosticStage = 'ready-first-input-unlock';
  await page.keyboard.press('x');
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorPreviewReadyAudioUnlockObserved === 'true' &&
      document.documentElement.dataset.creatorPreviewReadyAudioUnlockKind === 'key' &&
      document.documentElement.dataset.creatorPreviewReadyAudioPlayed === 'true' &&
      document.documentElement.dataset.creatorPreviewReadyAudioArmed === 'false' &&
      Number(document.documentElement.dataset.creatorPreviewAudioPlaybackCount ?? '0') === 1 &&
      document.documentElement.dataset.creatorPreviewAudioLastPlayedCue === 'preview_ready_audio_custom',
    null,
    { timeout: 5_000 },
  );

  diagnosticStage = 'ready-one-shot';
  await page.keyboard.press('x');
  await page.waitForTimeout(250);
  const readyReplayCount = Number(
    await page.evaluate(() => document.documentElement.dataset.creatorPreviewAudioPlaybackCount ?? '0'),
  );
  if (readyReplayCount !== 1) {
    throw new Error(`Ready WAV replayed after first unlock: count=${readyReplayCount}`);
  }

  diagnosticStage = 'ready-return';
  await page.evaluate(() => window.customFighterPreviewReturnToCreator());
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.appMode === 'creator' &&
      document.documentElement.dataset.creatorStudioReady === 'true' &&
      document.documentElement.dataset.creatorAudioAssetValid === 'true' &&
      document.documentElement.dataset.creatorAudioAssetBinding === 'ready' &&
      document.documentElement.dataset.creatorAudioAssetCue === 'preview_ready_audio_custom' &&
      document.documentElement.dataset.creatorAudioAssetFile === 'preview-ready.wav',
    null,
    { timeout: 10_000 },
  );

  diagnosticStage = 'passed';
  console.log('WEB_CREATOR_PREVIEW_SMOKE_PASSED invalidBlocked=true authoredHp=180 authoredDamage=33 authoredMpCost=17 authoredCooldown=2.4 semanticAnimationOverride=true semanticAnimationRoundTrip=true audioBindingOverride=true audioBindingRoundTrip=true animationPngMemoryRoundTrip=true animationPngRuntimeRendering=true animationPngRuntimeFrameAdvance=true animationPngSemanticFallback=true wavMemoryRoundTrip=true wavRuntimePlayback=true basicAttackWavRuntimePlayback=true skillImpactWavRuntimePlayback=true hitReceivedWavRuntimePlayback=true readyWavAutoplaySafe=true readyWavFirstInputPlayback=true readyWavOneShot=true safeComposition=true timelineRoundTrip=true animationTiming=true vfxTiming=true audioTiming=true spatialHitbox=true spatialHurtbox=true cast=true draftsRestored=true');
  await page.close();
} catch (error) {
  const snapshot = await diagnosticSnapshot();
  const detail = JSON.stringify({ stage: diagnosticStage, message: String(error), snapshot });
  console.error(`::error title=Creator preview diagnostic::${annotationSafe(detail)}`);
  throw error;
} finally {
  await browser.close();
}
