import { chromium } from 'playwright';

const baseUrl = process.env.CUSTOM_FIGHTER_WEB_URL ?? 'http://127.0.0.1:8000';
const browserChannel = process.env.BROWSER_CHANNEL?.trim();
const launchOptions = { headless: true };
if (browserChannel) launchOptions.channel = browserChannel;

console.log(`CREATOR_PREVIEW_FAMILY_BROWSER=${browserChannel || 'playwright-chromium'}`);
console.log(`CREATOR_PREVIEW_FAMILY_BASE_URL=${baseUrl}`);

const families = [
  { type: 'projectile', slot: 'skill_1', key: 'u', index: 1 },
  { type: 'dash', slot: 'skill_2', key: 'i', index: 2 },
  { type: 'area', slot: 'skill_3', key: 'o', index: 3 },
  { type: 'formation', slot: 'skill_4', key: 'p', index: 4 },
  { type: 'buff', slot: 'skill_5', key: 'b', index: 5 },
  { type: 'melee', slot: 'skill_6', key: 'h', index: 6 },
  { type: 'beam', slot: 'skill_7', key: 'y', index: 7 },
  { type: 'trap', slot: 'skill_8', key: 't', index: 8 },
  { type: 'aura', slot: 'skill_9', key: 'g', index: 9 },
  { type: 'teleport', slot: 'skill_10', key: 'r', index: 10 },
  { type: 'counter', slot: 'skill_11', key: 'f', index: 11 },
  { type: 'grab', slot: 'skill_12', key: 'e', index: 12 },
];

function creatorUrl() {
  const url = new URL(baseUrl);
  url.searchParams.set('mode', 'creator');
  return url.toString();
}

async function dataset(page, key) {
  return String(await page.evaluate((name) => document.documentElement.dataset[name] ?? '', key));
}

async function waitForCreator(page) {
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.appMode === 'creator' &&
      document.documentElement.dataset.creatorStudioReady === 'true' &&
      document.documentElement.dataset.creatorPreviewReady === 'true' &&
      document.documentElement.dataset.creatorTimelineReady === 'true' &&
      typeof window.customFighterCreatorSetSkillType === 'function' &&
      typeof window.customFighterCreatorSetSkillName === 'function' &&
      typeof window.customFighterCreatorSetSkillDamage === 'function' &&
      typeof window.customFighterCreatorSetSkillMpCost === 'function' &&
      typeof window.customFighterCreatorSetSkillCooldown === 'function' &&
      typeof window.customFighterCreatorSetSkillRange === 'function' &&
      typeof window.customFighterCreatorTimelineClear === 'function' &&
      typeof window.customFighterCreatorTimelineAdd === 'function' &&
      typeof window.customFighterCreatorPreview === 'function',
    null,
    { timeout: 60_000 },
  );
}

const browser = await chromium.launch(launchOptions);
let page;
let stage = 'launch';

try {
  page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  stage = 'creator-navigation';
  const response = await page.goto(creatorUrl(), { waitUntil: 'domcontentloaded', timeout: 60_000 });
  if (!response?.ok()) throw new Error(`Creator URL returned HTTP ${response?.status() ?? 'unknown'}`);
  await waitForCreator(page);

  for (const family of families) {
    stage = `author-${family.type}`;
    await page.evaluate(({ type }) => {
      window.customFighterCreatorSetSkillType(type);
      window.customFighterCreatorSetSkillName(`Preview ${type}`);
      window.customFighterCreatorSetSkillDamage(12);
      window.customFighterCreatorSetSkillMpCost(11);
      window.customFighterCreatorSetSkillCooldown(0.6);
      if (type === 'trap') window.customFighterCreatorSetSkillRange(580);
      if (type === 'teleport') window.customFighterCreatorSetSkillRange(360);
      if (type === 'counter') window.customFighterCreatorSetSkillRange(180);
      if (type === 'grab') window.customFighterCreatorSetSkillRange(120);
      window.customFighterCreatorTimelineClear();
      window.customFighterCreatorTimelineAdd(JSON.stringify({
        type: 'audio', time: 0.0, duration: 0.0, cue: 'skill_cast',
      }));
    }, family);

    await page.waitForFunction(
      ({ type }) =>
        document.documentElement.dataset.creatorSkillDraftValid === 'true' &&
        document.documentElement.dataset.creatorSkillDraftType === type &&
        document.documentElement.dataset.creatorSkillDraftMpCost === '11' &&
        (type !== 'trap' || Math.abs(Number(document.documentElement.dataset.creatorSkillDraftRange) - 580) < 0.01) &&
        (type !== 'teleport' || Math.abs(Number(document.documentElement.dataset.creatorSkillDraftRange) - 360) < 0.01) &&
        (type !== 'counter' || Math.abs(Number(document.documentElement.dataset.creatorSkillDraftRange) - 180) < 0.01) &&
        (type !== 'grab' || Math.abs(Number(document.documentElement.dataset.creatorSkillDraftRange) - 120) < 0.01) &&
        document.documentElement.dataset.creatorTimelineCount === '1' &&
        document.documentElement.dataset.creatorTimelineValid === 'true' &&
        document.documentElement.dataset.creatorPreviewCanLaunch === 'true',
      family,
      { timeout: 5_000 },
    );

    stage = `launch-${family.type}`;
    await page.evaluate(() => window.customFighterCreatorPreview());
    await page.waitForFunction(
      ({ type, slot, index }) => {
        const d = document.documentElement.dataset;
        return (
          d.appMode === 'training' &&
          d.creatorPreviewActive === 'true' &&
          d.playerCharacterSource === 'creator_preview_session' &&
          d.creatorPreviewRuntimeSkillType === type &&
          d.creatorPreviewRuntimeSkillSlot === slot &&
          d[`playerRuntimeSkill${index}Type`] === type &&
          d[`playerRuntimeSkill${index}Source`] === 'creator_preview_session' &&
          d[`playerRuntimeSkill${index}`] === d.creatorPreviewRuntimeSkillId &&
          Number(d.creatorPreviewRuntimeSkillMpCost) === 11 &&
          (type !== 'beam' || (d.beamSkillLoaded === 'true' && d.beamSkillId === d.creatorPreviewRuntimeSkillId)) &&
          (type !== 'trap' || (d.trapSkillLoaded === 'true' && d.trapSkillId === d.creatorPreviewRuntimeSkillId)) &&
          (type !== 'aura' || (d.auraSkillLoaded === 'true' && d.auraSkillId === d.creatorPreviewRuntimeSkillId)) &&
          (type !== 'teleport' || (d.teleportSkillLoaded === 'true' && d.teleportSkillId === d.creatorPreviewRuntimeSkillId)) &&
          (type !== 'counter' || (d.counterSkillLoaded === 'true' && d.counterSkillId === d.creatorPreviewRuntimeSkillId && d.trainingIncomingHitReady === 'true' && typeof window.customFighterTrainingIncomingHit === 'function')) &&
          (type !== 'grab' || (d.grabSkillLoaded === 'true' && d.grabSkillId === d.creatorPreviewRuntimeSkillId)) &&
          d.creatorPreviewReturnReady === 'true' &&
          typeof window.customFighterPreviewReturnToCreator === 'function'
        );
      },
      family,
      { timeout: 60_000 },
    );

    const runtimeId = await dataset(page, 'creatorPreviewRuntimeSkillId');
    if (!runtimeId) throw new Error(`Preview runtime id missing for ${family.type}`);

    if (family.type === 'aura' || family.type === 'counter' || family.type === 'grab') {
      stage = `${family.type}-approach`;
      await page.keyboard.down('d');
      try {
        await page.waitForFunction(
          () => {
            const d = document.documentElement.dataset;
            return Number(d.dummyX) - Number(d.playerX) <= 85;
          },
          null,
          { timeout: 4_000 },
        );
      } finally {
        await page.keyboard.up('d');
      }
      await page.waitForTimeout(120);
      const gap = Number(await dataset(page, 'dummyX')) - Number(await dataset(page, 'playerX'));
      if (gap < 0 || gap > 110) {
        throw new Error(`${family.type} approach ended outside deterministic range: gap=${gap}`);
      }
    }

    stage = `cast-${family.type}`;
    const beforeMp = Number(await dataset(page, 'playerMp'));
    const beforeDummyHp = Number(await dataset(page, 'dummyHp'));
    const beforePlayerHp = Number(await dataset(page, 'playerHp'));
    const beforePlayerX = Number(await dataset(page, 'playerX'));
    await page.keyboard.down(family.key);
    await page.waitForFunction(
      (expected) => Number(document.documentElement.dataset.playerMp) === expected,
      beforeMp - 11,
      { timeout: 4_000 },
    );
    await page.keyboard.up(family.key);

    await page.waitForFunction(
      () =>
        Number(document.documentElement.dataset.creatorPreviewTimelineTransitionCount ?? '0') >= 1 &&
        document.documentElement.dataset.creatorPreviewTimelineLastEventType === 'audio' &&
        document.documentElement.dataset.creatorPreviewTimelineLastAudioCue === 'skill_cast' &&
        Number(document.documentElement.dataset.creatorPreviewTimelineAudioEventCount ?? '0') >= 1,
      null,
      { timeout: 5_000 },
    );

    if (family.type === 'beam') {
      stage = 'beam-hit';
      await page.waitForFunction(
        (expectedHp) => {
          const d = document.documentElement.dataset;
          return (
            d.lastBeamSkillHit === 'true' &&
            Number(d.beamSkillHitCount ?? '0') === 1 &&
            Number(d.dummyHp) === expectedHp
          );
        },
        beforeDummyHp - 12,
        { timeout: 5_000 },
      );
      await page.waitForTimeout(120);
      if (Number(await dataset(page, 'beamSkillHitCount')) !== 1) {
        throw new Error('Beam damaged more than once during one activation');
      }
    }

    if (family.type === 'trap') {
      stage = 'trap-hit';
      await page.waitForFunction(
        (expectedHp) => {
          const d = document.documentElement.dataset;
          return (
            d.lastTrapSkillHit === 'true' &&
            d.trapSkillTriggered === 'true' &&
            d.trapSkillActive === 'false' &&
            Number(d.trapSkillHitCount ?? '0') === 1 &&
            Number(d.dummyHp) === expectedHp
          );
        },
        beforeDummyHp - 12,
        { timeout: 5_000 },
      );
      await page.waitForTimeout(120);
      if (Number(await dataset(page, 'trapSkillHitCount')) !== 1) {
        throw new Error('Trap damaged more than once after one trigger');
      }
    }

    if (family.type === 'aura') {
      stage = 'aura-hit';
      await page.waitForFunction(
        (expectedHp) => {
          const d = document.documentElement.dataset;
          return (
            d.lastAuraSkillHit === 'true' &&
            d.auraSkillActive === 'true' &&
            d.auraSkillHitConsumed === 'true' &&
            Number(d.auraSkillHitCount ?? '0') === 1 &&
            Number(d.dummyHp) === expectedHp
          );
        },
        beforeDummyHp - 12,
        { timeout: 5_000 },
      );
      await page.waitForTimeout(180);
      if (Number(await dataset(page, 'auraSkillHitCount')) !== 1) {
        throw new Error('Aura damaged more than once during one activation');
      }
    }

    if (family.type === 'teleport') {
      stage = 'teleport-arrival';
      await page.waitForFunction(
        ({ expectedX, expectedHp }) => {
          const d = document.documentElement.dataset;
          return (
            d.teleportSkillLastSuccess === 'true' &&
            Number(d.teleportSkillActivationCount ?? '0') === 1 &&
            Math.abs(Number(d.teleportSkillLastDistance ?? '0') - 360) <= 1.0 &&
            Math.abs(Number(d.teleportSkillDestinationX ?? '0') - expectedX) <= 1.0 &&
            Math.abs(Number(d.playerX) - expectedX) <= 2.0 &&
            Number(d.dummyHp) === expectedHp
          );
        },
        { expectedX: beforePlayerX + 360, expectedHp: beforeDummyHp },
        { timeout: 5_000 },
      );
    }

    if (family.type === 'grab') {
      stage = 'grab-capture';
      const expectedGrabOffset = Number(await dataset(page, 'creatorSkillDraftKnockback'));
      const expectedGrabX = beforePlayerX + expectedGrabOffset;
      await page.waitForFunction(
        ({ expectedHp, expectedX }) => {
          const d = document.documentElement.dataset;
          return (
            d.lastGrabSkillSuccess === 'true' &&
            d.lastGrabSkillHit === 'true' &&
            d.grabSkillCaptured === 'true' &&
            Number(d.grabSkillActivationCount ?? '0') === 1 &&
            Number(d.grabSkillCaptureCount ?? '0') === 1 &&
            Number(d.dummyHp) === expectedHp &&
            Math.abs(Number(d.grabSkillTargetDestinationX ?? '0') - expectedX) <= 1.0 &&
            Math.abs(Number(d.dummyX) - expectedX) <= 2.0
          );
        },
        { expectedHp: beforeDummyHp - 12, expectedX: expectedGrabX },
        { timeout: 5_000 },
      );
      await page.waitForFunction(
        () => document.documentElement.dataset.grabSkillActive === 'false',
        null,
        { timeout: 5_000 },
      );
      if (Number(await dataset(page, 'grabSkillCaptureCount')) !== 1) {
        throw new Error('Grab captured more than once during one activation');
      }
      if (Number(await dataset(page, 'dummyHp')) !== beforeDummyHp - 12) {
        throw new Error('Grab damaged more than once during one activation');
      }
    }

    if (family.type === 'counter') {
      stage = 'counter-window';
      await page.waitForFunction(
        () => {
          const d = document.documentElement.dataset;
          return (
            d.counterSkillWindowActive === 'true' &&
            Number(d.counterSkillActivationCount ?? '0') === 1 &&
            d.trainingIncomingHitReady === 'true' &&
            typeof window.customFighterTrainingIncomingHit === 'function'
          );
        },
        null,
        { timeout: 5_000 },
      );

      stage = 'counter-first-incoming-hit';
      await page.evaluate(() => window.customFighterTrainingIncomingHit(9));
      await page.waitForFunction(
        ({ expectedDummyHp, expectedPlayerHp }) => {
          const d = document.documentElement.dataset;
          return (
            d.counterSkillTriggered === 'true' &&
            d.lastCounterSkillSuccess === 'true' &&
            d.lastCounterSkillHit === 'true' &&
            Number(d.counterSkillTriggerCount ?? '0') === 1 &&
            Number(d.counterSkillRetaliationHitCount ?? '0') === 1 &&
            d.lastPlayerHitCountered === 'true' &&
            Number(d.playerIncomingHitCount ?? '0') === 1 &&
            Number(d.lastPlayerDamageDealt ?? '-1') === 0 &&
            Number(d.playerHp) === expectedPlayerHp &&
            Number(d.dummyHp) === expectedDummyHp
          );
        },
        { expectedDummyHp: beforeDummyHp - 12, expectedPlayerHp: beforePlayerHp },
        { timeout: 5_000 },
      );

      stage = 'counter-second-incoming-hit';
      await page.evaluate(() => window.customFighterTrainingIncomingHit(9));
      await page.waitForFunction(
        ({ expectedDummyHp, expectedPlayerHp }) => {
          const d = document.documentElement.dataset;
          return (
            Number(d.counterSkillTriggerCount ?? '0') === 1 &&
            Number(d.counterSkillRetaliationHitCount ?? '0') === 1 &&
            d.lastPlayerHitCountered === 'false' &&
            Number(d.playerIncomingHitCount ?? '0') === 2 &&
            Number(d.lastPlayerDamageDealt ?? '0') === 9 &&
            Number(d.playerHp) === expectedPlayerHp &&
            Number(d.dummyHp) === expectedDummyHp
          );
        },
        { expectedDummyHp: beforeDummyHp - 12, expectedPlayerHp: beforePlayerHp - 9 },
        { timeout: 5_000 },
      );
    }

    stage = `return-${family.type}`;
    await page.evaluate(() => window.customFighterPreviewReturnToCreator());
    await waitForCreator(page);
    await page.waitForFunction(
      (type) =>
        document.documentElement.dataset.creatorSkillDraftType === type &&
        document.documentElement.dataset.creatorSkillDraftMpCost === '11' &&
        document.documentElement.dataset.creatorTimelineCount === '1',
      family.type,
      { timeout: 10_000 },
    );
  }

  console.log('WEB_CREATOR_PREVIEW_FAMILY_SMOKE_PASSED families=12 slotRouting=true authoredCast=true beamHitPolicy=single trapTriggerPolicy=single auraHitPolicy=single teleportPolicy=bounded counterPolicy=actual-hit-once grabPolicy=overlap-hold-once timelineDispatch=true roundTrip=true');
} catch (error) {
  let snapshot = {};
  if (page) {
    try {
      snapshot = await page.evaluate(() => ({ ...document.documentElement.dataset }));
    } catch {
      snapshot = {};
    }
  }
  const failureDetail = `stage=${stage} error=${String(error)} snapshot=${JSON.stringify(snapshot)}`;
  console.error(`CREATOR_PREVIEW_FAMILY_FAILURE ${failureDetail}`);
  const annotationDetail = failureDetail
    .replaceAll('%', '%25')
    .replaceAll('\r', '%0D')
    .replaceAll('\n', '%0A');
  console.error(`::error title=Creator Preview family smoke::${annotationDetail}`);
  throw error;
} finally {
  await browser.close();
}
