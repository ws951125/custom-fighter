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
  await page.evaluate(() => window.customFighterCreatorTimelineAdd(JSON.stringify({ type: 'hitbox', time: 0.2, duration: 0.1 })));
  await waitCount(page, 2);
  if ((await dataset(page, 'creatorTimelineValid')) !== 'true') throw new Error(await dataset(page, 'creatorTimelineError'));

  await page.evaluate(() => window.customFighterCreatorTimelineUpdate(1, JSON.stringify({ time: 0.1, duration: 0.15, type: 'vfx' })));
  await page.waitForFunction(() => JSON.parse(document.documentElement.dataset.creatorTimelineEvents || '[]')[1]?.type === 'vfx', null, { timeout: 5_000 });
  if ((await dataset(page, 'creatorTimelineValid')) !== 'true') throw new Error('Safe timeline update should remain valid');

  await page.evaluate(() => window.customFighterCreatorTimelineMove(1, 0));
  await page.waitForFunction(() => document.documentElement.dataset.creatorTimelineValid === 'false', null, { timeout: 5_000 });
  if (!(await dataset(page, 'creatorTimelineError')).includes('ordered by non-decreasing time')) throw new Error('Out-of-order timeline must fail closed');

  await page.evaluate(() => window.customFighterCreatorTimelineMove(0, 1));
  await page.waitForFunction(() => document.documentElement.dataset.creatorTimelineValid === 'true', null, { timeout: 5_000 });
  await page.evaluate(() => window.customFighterCreatorTimelineRemove(0));
  await waitCount(page, 1);
  await page.evaluate(() => window.customFighterCreatorTimelineClear());
  await waitCount(page, 0);
  if ((await dataset(page, 'creatorTimelineValid')) !== 'true') throw new Error('Clear timeline must restore V1-compatible valid draft');

  console.log('WEB_CREATOR_TIMELINE_EDITOR_SMOKE_PASSED add=true update=true reorderFailClosed=true remove=true clear=true');
} finally {
  await browser.close();
}
