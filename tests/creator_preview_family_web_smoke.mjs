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
          d.creatorPreviewReturnReady === 'true' &&
          typeof window.customFighterPreviewReturnToCreator === 'function'
        );
      },
      family,
      { timeout: 60_000 },
    );

    const runtimeId = await dataset(page, 'creatorPreviewRuntimeSkillId');
    if (!runtimeId) throw new Error(`Preview runtime id missing for ${family.type}`);

    stage = `cast-${family.type}`;
    const beforeMp = Number(await dataset(page, 'playerMp'));
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

  console.log('WEB_CREATOR_PREVIEW_FAMILY_SMOKE_PASSED families=6 slotRouting=true authoredCast=true timelineDispatch=true roundTrip=true');
} catch (error) {
  let snapshot = {};
  if (page) {
    try {
      snapshot = await page.evaluate(() => ({ ...document.documentElement.dataset }));
    } catch {
      snapshot = {};
    }
  }
  console.error(`CREATOR_PREVIEW_FAMILY_FAILURE stage=${stage} error=${String(error)} snapshot=${JSON.stringify(snapshot)}`);
  throw error;
} finally {
  await browser.close();
}
