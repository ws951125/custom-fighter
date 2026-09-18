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
    typeof window.customFighterCreatorTimelineClear === 'function' &&
    typeof window.customFighterCreatorTimelineApplyComposition === 'function' &&
    document.documentElement.dataset.creatorTimelineCompositionReady === 'true', null, { timeout: 60_000 });

  if ((await dataset(page, 'creatorTimelineCount')) !== '0' || (await dataset(page, 'creatorTimelineValid')) !== 'true') {
    throw new Error('Starter Creator timeline must remain empty and V1-compatible');
  }

  const recipes = JSON.parse(await dataset(page, 'creatorTimelineCompositionRecipes') || '[]');
  if (JSON.stringify(recipes) !== JSON.stringify(['cast_burst', 'guarded_impact'])) {
    throw new Error(`Unexpected safe composition recipes: ${JSON.stringify(recipes)}`);
  }

  await page.evaluate(() => window.customFighterCreatorTimelineApplyComposition('cast_burst', 0));
  await waitCount(page, 4);
  await page.waitForFunction(() =>
    document.documentElement.dataset.creatorTimelineCompositionLastRecipe === 'cast_burst' &&
    document.documentElement.dataset.creatorTimelineCompositionLastAddedCount === '4' &&
    document.documentElement.dataset.creatorTimelineCompositionError === '' &&
    document.documentElement.dataset.creatorTimelineValid === 'true',
    null,
    { timeout: 5_000 },
  );
  let compositionEvents = await timelineEvents(page);
  if (compositionEvents.map((event) => event.type).join(',') !== 'animation,vfx,audio,hitbox') {
    throw new Error(`cast_burst composition emitted unexpected vocabulary: ${JSON.stringify(compositionEvents)}`);
  }
  if (!compositionEvents.every((event) => /^[a-z0-9][a-z0-9_-]*$/.test(event.id ?? ''))) {
    throw new Error('Composition emitted unsafe event id');
  }

  await page.evaluate(() => window.customFighterCreatorTimelineApplyComposition('guarded_impact', 0.7));
  await waitCount(page, 9);
  await page.waitForFunction(() =>
    document.documentElement.dataset.creatorTimelineCompositionLastRecipe === 'guarded_impact' &&
    document.documentElement.dataset.creatorTimelineCompositionLastAddedCount === '5' &&
    document.documentElement.dataset.creatorTimelineCompositionError === '',
    null,
    { timeout: 5_000 },
  );
  compositionEvents = await timelineEvents(page);
  if (compositionEvents.slice(4).map((event) => event.type).join(',') !== 'animation,vfx,hitbox,audio,hurtbox') {
    throw new Error(`guarded_impact composition emitted unexpected vocabulary: ${JSON.stringify(compositionEvents.slice(4))}`);
  }

  await page.evaluate(() => window.customFighterCreatorTimelineApplyComposition('script', 2.0));
  await page.waitForFunction(
    () => (document.documentElement.dataset.creatorTimelineCompositionError ?? '').includes('unsupported timeline composition recipe'),
    null,
    { timeout: 5_000 },
  );
  if ((await dataset(page, 'creatorTimelineCount')) !== '9') throw new Error('Unsupported composition mutated timeline');

  await page.evaluate(() => window.customFighterCreatorTimelineApplyComposition('cast_burst', 0.1));
  await page.waitForFunction(
    () => (document.documentElement.dataset.creatorTimelineCompositionError ?? '').includes('must not start before the existing timeline tail'),
    null,
    { timeout: 5_000 },
  );
  if ((await dataset(page, 'creatorTimelineCount')) !== '9') throw new Error('Backwards composition mutated timeline');

  await page.evaluate(() => window.customFighterCreatorTimelineClear());
  await waitCount(page, 0);
  await page.waitForFunction(() =>
    document.documentElement.dataset.creatorTimelineCompositionError === '' &&
    document.documentElement.dataset.creatorTimelineCompositionLastRecipe === '' &&
    document.documentElement.dataset.creatorTimelineCompositionLastAddedCount === '0',
    null,
    { timeout: 5_000 },
  );

  await page.evaluate(() => window.customFighterCreatorTimelineAdd(JSON.stringify({
    type: 'animation', time: 0.0, duration: 0.1, animation: 'skill_2',
  })));
  await waitCount(page, 1);
  await page.evaluate(() => window.customFighterCreatorTimelineAdd(JSON.stringify({
    type: 'vfx', time: 0.1, duration: 0.0, visual: 'prototype_impact',
  })));
  await waitCount(page, 2);
  await page.evaluate(() => window.customFighterCreatorTimelineAdd(JSON.stringify({
    type: 'hitbox', time: 0.2, duration: 0.1,
    half_width: 36, half_depth: 0.12, offset_x: 18, offset_depth: -0.02,
  })));
  await waitCount(page, 3);
  await page.evaluate(() => window.customFighterCreatorTimelineAdd(JSON.stringify({
    type: 'audio', time: 0.3, duration: 0.0, cue: 'skill_cast',
  })));
  await waitCount(page, 4);
  await page.evaluate(() => window.customFighterCreatorTimelineAdd(JSON.stringify({
    type: 'hurtbox', time: 0.4, duration: 0.1,
    half_width: 22, half_depth: 0.09, offset_x: -6, offset_depth: 0.03,
  })));
  await waitCount(page, 5);
  if ((await dataset(page, 'creatorTimelineValid')) !== 'true') throw new Error(await dataset(page, 'creatorTimelineError'));

  let events = await timelineEvents(page);
  if (events[0]?.type !== 'animation' || events[0]?.animation !== 'skill_2') {
    throw new Error(`Animation payload was not preserved: ${JSON.stringify(events[0])}`);
  }
  if (events[1]?.type !== 'vfx' || events[1]?.visual !== 'prototype_impact') {
    throw new Error(`VFX payload was not preserved: ${JSON.stringify(events[1])}`);
  }
  if (events[2]?.type !== 'hitbox' || Number(events[2]?.half_width) !== 36 || Number(events[2]?.offset_x) !== 18 || Number(events[2]?.offset_depth) !== -0.02) {
    throw new Error(`Hitbox spatial payload was not preserved: ${JSON.stringify(events[2])}`);
  }
  if (events[3]?.type !== 'audio' || events[3]?.cue !== 'skill_cast') {
    throw new Error(`Audio payload was not preserved: ${JSON.stringify(events[3])}`);
  }
  if (events[4]?.type !== 'hurtbox' || Number(events[4]?.half_depth) !== 0.09 || Number(events[4]?.offset_depth) !== 0.03) {
    throw new Error(`Hurtbox spatial payload was not preserved: ${JSON.stringify(events[4])}`);
  }

  await page.evaluate(() => window.customFighterCreatorTimelineUpdate(0, JSON.stringify({ animation: '../evil.gd' })));
  await page.waitForFunction(() => document.documentElement.dataset.creatorTimelineValid === 'false', null, { timeout: 5_000 });
  if (!(await dataset(page, 'creatorTimelineError')).includes('animation must be a safe lowercase token')) {
    throw new Error('Unsafe animation path must fail closed');
  }
  await page.evaluate(() => window.customFighterCreatorTimelineUpdate(0, JSON.stringify({ animation: 'skill_3' })));
  await page.waitForFunction(() => document.documentElement.dataset.creatorTimelineValid === 'true', null, { timeout: 5_000 });

  await page.evaluate(() => window.customFighterCreatorTimelineUpdate(1, JSON.stringify({ visual: 'https://example.com/vfx' })));
  await page.waitForFunction(() => document.documentElement.dataset.creatorTimelineValid === 'false', null, { timeout: 5_000 });
  if (!(await dataset(page, 'creatorTimelineError')).includes('visual must be a safe lowercase token')) {
    throw new Error('Unsafe VFX URL must fail closed');
  }
  await page.evaluate(() => window.customFighterCreatorTimelineUpdate(1, JSON.stringify({ visual: 'prototype_fireball' })));
  await page.waitForFunction(() => document.documentElement.dataset.creatorTimelineValid === 'true', null, { timeout: 5_000 });

  await page.evaluate(() => window.customFighterCreatorTimelineUpdate(2, JSON.stringify({ half_width: 0 })));
  await page.waitForFunction(() => document.documentElement.dataset.creatorTimelineValid === 'false', null, { timeout: 5_000 });
  if (!(await dataset(page, 'creatorTimelineError')).includes('half_width must be > 0')) throw new Error('Invalid spatial dimensions must fail closed');
  await page.evaluate(() => window.customFighterCreatorTimelineUpdate(2, JSON.stringify({ half_width: 40, offset_x: 24 })));
  await page.waitForFunction(() => document.documentElement.dataset.creatorTimelineValid === 'true', null, { timeout: 5_000 });

  await page.evaluate(() => window.customFighterCreatorTimelineUpdate(3, JSON.stringify({ type: 'vfx', visual: 'prototype_impact' })));
  await page.waitForFunction(() => JSON.parse(document.documentElement.dataset.creatorTimelineEvents || '[]')[3]?.type === 'vfx', null, { timeout: 5_000 });
  events = await timelineEvents(page);
  if ('cue' in events[3] || events[3]?.visual !== 'prototype_impact') throw new Error('Media type change must remove stale audio payload and keep VFX payload');

  await page.evaluate(() => window.customFighterCreatorTimelineUpdate(4, JSON.stringify({ time: 0.4, duration: 0.15, type: 'vfx', visual: 'prototype_fireball' })));
  await page.waitForFunction(() => JSON.parse(document.documentElement.dataset.creatorTimelineEvents || '[]')[4]?.type === 'vfx', null, { timeout: 5_000 });
  events = await timelineEvents(page);
  if ('half_width' in events[4] || 'offset_depth' in events[4]) throw new Error('Non-spatial event must not retain stale spatial payload');
  if (events[4]?.visual !== 'prototype_fireball') throw new Error('Spatial-to-VFX type change must author a valid VFX payload');
  if ((await dataset(page, 'creatorTimelineValid')) !== 'true') throw new Error('Safe timeline update should remain valid');

  await page.evaluate(() => window.customFighterCreatorTimelineMove(4, 0));
  await page.waitForFunction(() => document.documentElement.dataset.creatorTimelineValid === 'false', null, { timeout: 5_000 });
  if (!(await dataset(page, 'creatorTimelineError')).includes('ordered by non-decreasing time')) throw new Error('Out-of-order timeline must fail closed');

  await page.evaluate(() => window.customFighterCreatorTimelineMove(0, 4));
  await page.waitForFunction(() => document.documentElement.dataset.creatorTimelineValid === 'true', null, { timeout: 5_000 });
  await page.evaluate(() => window.customFighterCreatorTimelineRemove(0));
  await waitCount(page, 4);
  await page.evaluate(() => window.customFighterCreatorTimelineClear());
  await waitCount(page, 0);
  if ((await dataset(page, 'creatorTimelineValid')) !== 'true') throw new Error('Clear timeline must restore V1-compatible valid draft');

  console.log('WEB_CREATOR_TIMELINE_EDITOR_SMOKE_PASSED safeComposition=true allowList=true compositionFailClosed=true mediaAnimation=true mediaVfx=true mediaAudio=true mediaFailClosed=true mediaStaleCleanup=true spatialHitbox=true spatialHurtbox=true spatialFailClosed=true stalePayloadCleanup=true reorderFailClosed=true remove=true clear=true');
} finally {
  await browser.close();
}
