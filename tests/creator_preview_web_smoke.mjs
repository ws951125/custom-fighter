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
        'dummyHp',
        'lastSkillHit',
        'skillHitCount',
        'playerAnimationSemantic',
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
      typeof window.customFighterCreatorSetSkillMpCost === 'function' &&
      typeof window.customFighterCreatorSetSkillCooldown === 'function' &&
      typeof window.customFighterCreatorTimelineAdd === 'function' &&
      typeof window.customFighterCreatorTimelineClear === 'function',
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
    window.customFighterCreatorSetMaxHp(180);
    window.customFighterCreatorSetSkillName('Nova Bolt');
    window.customFighterCreatorSetSkillDamage(33);
    window.customFighterCreatorSetSkillMpCost(17);
    window.customFighterCreatorSetSkillCooldown(2.4);
    window.customFighterCreatorTimelineClear();
    window.customFighterCreatorTimelineAdd(JSON.stringify({
      type: 'animation', time: 0.0, duration: 1.2, animation: 'skill_3',
    }));
    window.customFighterCreatorTimelineAdd(JSON.stringify({
      type: 'vfx', time: 0.1, duration: 1.0, visual: 'prototype_impact',
    }));
    window.customFighterCreatorTimelineAdd(JSON.stringify({
      type: 'hitbox', time: 0.2, duration: 0.9,
      half_width: 40, half_depth: 0.12, offset_x: 24, offset_depth: -0.02,
    }));
    window.customFighterCreatorTimelineAdd(JSON.stringify({
      type: 'audio', time: 0.3, duration: 0.0, cue: 'skill_cast',
    }));
    window.customFighterCreatorTimelineAdd(JSON.stringify({
      type: 'hurtbox', time: 0.4, duration: 0.7,
      half_width: 22, half_depth: 0.09, offset_x: -6, offset_depth: 0.03,
    }));
  });

  diagnosticStage = 'authored-timeline-valid';
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorDraftValid === 'true' &&
      document.documentElement.dataset.creatorSkillDraftValid === 'true' &&
      document.documentElement.dataset.creatorDraftName === 'Preview Nova' &&
      document.documentElement.dataset.creatorDraftMaxHp === '180' &&
      document.documentElement.dataset.creatorSkillDraftName === 'Nova Bolt' &&
      document.documentElement.dataset.creatorSkillDraftDamage === '33' &&
      document.documentElement.dataset.creatorSkillDraftMpCost === '17' &&
      Math.abs(Number(document.documentElement.dataset.creatorSkillDraftCooldown) - 2.4) < 0.001 &&
      document.documentElement.dataset.creatorTimelineCount === '5' &&
      document.documentElement.dataset.creatorTimelineValid === 'true' &&
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
      document.documentElement.dataset.creatorPreviewTimelineLastVfx === 'prototype_impact' &&
      document.documentElement.dataset.creatorPreviewTimelineVfxActive === 'true' &&
      document.documentElement.dataset.creatorPreviewTimelineLastAudioCue === 'skill_cast' &&
      Number(document.documentElement.dataset.creatorPreviewTimelineAudioEventCount ?? '0') >= 1 &&
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

  diagnosticStage = 'creator-return';
  await page.evaluate(() => window.customFighterPreviewReturnToCreator());
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.appMode === 'creator' &&
      document.documentElement.dataset.creatorStudioReady === 'true' &&
      document.documentElement.dataset.creatorDraftName === 'Preview Nova' &&
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

  diagnosticStage = 'passed';
  console.log('WEB_CREATOR_PREVIEW_SMOKE_PASSED invalidBlocked=true authoredHp=180 authoredDamage=33 authoredMpCost=17 authoredCooldown=2.4 timelineRoundTrip=true animationTiming=true vfxTiming=true audioTiming=true spatialHitbox=true spatialHurtbox=true cast=true draftsRestored=true');
  await page.close();
} catch (error) {
  const snapshot = await diagnosticSnapshot();
  const detail = JSON.stringify({ stage: diagnosticStage, message: String(error), snapshot });
  console.error(`::error title=Creator preview diagnostic::${annotationSafe(detail)}`);
  throw error;
} finally {
  await browser.close();
}
