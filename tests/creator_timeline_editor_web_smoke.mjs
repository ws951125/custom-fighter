import { chromium } from 'playwright';

const baseUrl = process.env.CUSTOM_FIGHTER_WEB_URL ?? 'http://127.0.0.1:8000';
const browserChannel = process.env.BROWSER_CHANNEL?.trim();
const launchOptions = { headless: true };
if (browserChannel) launchOptions.channel = browserChannel;

function creatorUrl() {
  const url = new URL(baseUrl);
  url.searchParams.set('mode', 'creator');
  return url.toString();
}
async function dataset(page, key) {
  return String(await page.evaluate((name) => document.documentElement.dataset[name] ?? '', key));
}
async function waitCount(page, count) {
  await page.waitForFunction((expected) => Number(document.documentElement.dataset.creatorTimelineCount ?? '-1') === expected, count, { timeout: 5_000 });
}
async function timelineEvents(page) {
  return JSON.parse(await dataset(page, 'creatorTimelineEvents') || '[]');
}

const browser = await chromium.launch(launchOptions);
try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const response = await page.goto(creatorUrl(), { waitUntil: 'domcontentloaded', timeout: 60_000 });
  if (!response?.ok()) throw new Error(`Creator URL returned HTTP ${response?.status() ?? 'unknown'}`);
  await page.waitForFunction(() =>
    document.documentElement.dataset.creatorTimelineReady === 'true' &&
    typeof window.customFighterCreatorTimelineAdd === 'function' &&
    typeof window.customFighterCreatorTimelineRemove === 'function' &&
    typeof window.customFighterCreatorTimelineMove === 'function' &&
    typeof window.customFighterCreatorTimelineUpdate === 'function' &&
    typeof window.customFighterCreatorTimelineClear === 'function', null, { timeout: 60_000 });

  if ((await dataset(page, 'creatorTimelineCount')) !== '0' || (await dataset(page, 'creatorTimelineValid')) !== 'true') {
    throw new Error('Starter Creator timeline must remain empty and V1-compatible');
  }
  await page.evaluate(() => window.customFighterCreatorTimelineAdd(JSON.stringify({ type: 'animation', time: 0.0, duration: 0.2 })));
  await waitCount(page, 1);
  await page.evaluate(() => window.customFighterCreatorTimelineAdd(JSON.stringify({
    type: 'hitbox', time: 0.2, duration: 0.1,
    half_width: 36, half_depth: 0.12, offset_x: 18, offset_depth: -0.02,
  })));
  await waitCount(page, 2);
  await page.evaluate(() => window.customFighterCreatorTimelineAdd(JSON.stringify({
    type: 'hurtbox', time: 0.4, duration: 0.1,
    half_width: 22, half_depth: 0.09, offset_x: -6, offset_depth: 0.03,
  })));
  await waitCount(page, 3);
  if ((await dataset(page, 'creatorTimelineValid')) !== 'true') throw new Error(await dataset(page, 'creatorTimelineError'));

  let events = await timelineEvents(page);
  if (events[1]?.type !== 'hitbox' || Number(events[1]?.half_width) !== 36 || Number(events[1]?.offset_x) !== 18 || Number(events[1]?.offset_depth) !== -0.02) {
    throw new Error(`Hitbox spatial payload was not preserved: ${JSON.stringify(events[1])}`);
  }
  if (events[2]?.type !== 'hurtbox' || Number(events[2]?.half_depth) !== 0.09 || Number(events[2]?.offset_depth) !== 0.03) {
    throw new Error(`Hurtbox spatial payload was not preserved: ${JSON.stringify(events[2])}`);
  }

  await page.evaluate(() => window.customFighterCreatorTimelineUpdate(1, JSON.stringify({ half_width: 0 })));
  await page.waitForFunction(() => document.documentElement.dataset.creatorTimelineValid === 'false', null, { timeout: 5_000 });
  if (!(await dataset(page, 'creatorTimelineError')).includes('half_width must be > 0')) throw new Error('Invalid spatial dimensions must fail closed');
  await page.evaluate(() => window.customFighterCreatorTimelineUpdate(1, JSON.stringify({ half_width: 40, offset_x: 24 })));
  await page.waitForFunction(() => document.documentElement.dataset.creatorTimelineValid === 'true', null, { timeout: 5_000 });

  await page.evaluate(() => window.customFighterCreatorTimelineUpdate(2, JSON.stringify({ time: 0.4, duration: 0.15, type: 'vfx' })));
  await page.waitForFunction(() => JSON.parse(document.documentElement.dataset.creatorTimelineEvents || '[]')[2]?.type === 'vfx', null, { timeout: 5_000 });
  events = await timelineEvents(page);
  if ('half_width' in events[2] || 'offset_depth' in events[2]) throw new Error('Non-spatial event must not retain stale spatial payload');
  if ((await dataset(page, 'creatorTimelineValid')) !== 'true') throw new Error('Safe timeline update should remain valid');

  await page.evaluate(() => window.customFighterCreatorTimelineMove(2, 0));
  await page.waitForFunction(() => document.documentElement.dataset.creatorTimelineValid === 'false', null, { timeout: 5_000 });
  if (!(await dataset(page, 'creatorTimelineError')).includes('ordered by non-decreasing time')) throw new Error('Out-of-order timeline must fail closed');

  await page.evaluate(() => window.customFighterCreatorTimelineMove(0, 2));
  await page.waitForFunction(() => document.documentElement.dataset.creatorTimelineValid === 'true', null, { timeout: 5_000 });
  await page.evaluate(() => window.customFighterCreatorTimelineRemove(0));
  await waitCount(page, 2);
  await page.evaluate(() => window.customFighterCreatorTimelineClear());
  await waitCount(page, 0);
  if ((await dataset(page, 'creatorTimelineValid')) !== 'true') throw new Error('Clear timeline must restore V1-compatible valid draft');

  console.log('WEB_CREATOR_TIMELINE_EDITOR_SMOKE_PASSED spatialHitbox=true spatialHurtbox=true failClosed=true stalePayloadCleanup=true reorderFailClosed=true remove=true clear=true');
} finally {
  await browser.close();
}
