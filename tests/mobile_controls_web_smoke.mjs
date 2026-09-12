import { chromium } from 'playwright';

const baseUrl = process.env.CUSTOM_FIGHTER_WEB_URL ?? 'http://127.0.0.1:8000';
const browserChannel = process.env.BROWSER_CHANNEL?.trim();
const launchOptions = { headless: true };
if (browserChannel) launchOptions.channel = browserChannel;

console.log(`MOBILE_CONTROLS_BROWSER=${browserChannel || 'playwright-chromium'}`);
console.log(`MOBILE_CONTROLS_BASE_URL=${baseUrl}`);

function attachDiagnostics(page, label) {
  page.on('console', (message) => console.log(`[${label}:console:${message.type()}] ${message.text()}`));
  page.on('pageerror', (error) => console.log(`[${label}:pageerror] ${error.message}`));
}

async function snapshot(page, label) {
  const state = await page.evaluate(() => ({
    godotReady: document.documentElement.dataset.godotReady ?? '',
    ready: document.documentElement.dataset.mobileControlsReady ?? '',
    visible: document.documentElement.dataset.mobileControlsVisible ?? '',
    touchCapable: document.documentElement.dataset.mobileControlsTouchCapable ?? '',
    layout: document.documentElement.dataset.mobileControlsLayout ?? '',
    buttonCount: document.documentElement.dataset.mobileControlsButtonCount ?? '',
    maxTouchPoints: navigator.maxTouchPoints ?? 0,
    coarsePointer: Boolean(window.matchMedia && window.matchMedia('(pointer: coarse)').matches),
    pressBridge: typeof window.customFighterMobilePress,
    releaseBridge: typeof window.customFighterMobileRelease,
  }));
  console.log(`${label}_STATE=${JSON.stringify(state)}`);
  return state;
}

const browser = await chromium.launch(launchOptions);
try {
  // Functional gameplay validation uses the explicit test override. Real phones still
  // auto-enable from touch capability, which is checked separately below.
  const forcedUrl = new URL(baseUrl);
  forcedUrl.searchParams.set('mobile_controls', '1');
  const mobilePage = await browser.newPage({
    viewport: { width: 844, height: 390 },
    hasTouch: true,
  });
  attachDiagnostics(mobilePage, 'mobile-forced');
  const response = await mobilePage.goto(forcedUrl.toString(), { waitUntil: 'domcontentloaded', timeout: 60_000 });
  if (!response?.ok()) throw new Error(`Mobile Training URL returned HTTP ${response?.status() ?? 'unknown'}`);

  await mobilePage.waitForFunction(
    () => document.documentElement.dataset.godotReady === 'true',
    null,
    { timeout: 60_000 },
  );
  await snapshot(mobilePage, 'MOBILE_FORCED_READY');
  await mobilePage.waitForFunction(
    () =>
      document.documentElement.dataset.mobileControlsReady === 'true' &&
      document.documentElement.dataset.mobileControlsVisible === 'true' &&
      document.documentElement.dataset.mobileControlsLayout === 'landscape-v1' &&
      Number(document.documentElement.dataset.mobileControlsButtonCount) === 15 &&
      typeof window.customFighterMobilePress === 'function' &&
      typeof window.customFighterMobileRelease === 'function',
    null,
    { timeout: 15_000 },
  );

  const startX = Number(await mobilePage.evaluate(() => document.documentElement.dataset.playerX));
  await mobilePage.evaluate(() => window.customFighterMobilePress('move_right'));
  await mobilePage.waitForFunction(
    (originX) =>
      Number(document.documentElement.dataset.playerX) > originX + 45 &&
      (document.documentElement.dataset.mobileControlsPressed ?? '').includes('move_right'),
    startX,
    { timeout: 4_000 },
  );
  await mobilePage.evaluate(() => window.customFighterMobileRelease('move_right'));
  await mobilePage.waitForFunction(
    () => !(document.documentElement.dataset.mobileControlsPressed ?? '').includes('move_right'),
    null,
    { timeout: 2_000 },
  );

  await mobilePage.evaluate(() => window.customFighterMobilePress('guard'));
  await mobilePage.waitForFunction(
    () => document.documentElement.dataset.playerGuarding === 'true',
    null,
    { timeout: 2_000 },
  );
  await mobilePage.evaluate(() => window.customFighterMobileRelease('guard'));
  await mobilePage.waitForFunction(
    () => document.documentElement.dataset.playerGuarding === 'false',
    null,
    { timeout: 2_000 },
  );

  await mobilePage.evaluate(() => window.customFighterMobilePress('jump'));
  await mobilePage.waitForFunction(
    () => document.documentElement.dataset.playerJumping === 'true',
    null,
    { timeout: 2_000 },
  );
  await mobilePage.evaluate(() => window.customFighterMobileRelease('jump'));
  await mobilePage.waitForFunction(
    () => document.documentElement.dataset.playerJumping === 'false',
    null,
    { timeout: 4_000 },
  );

  await mobilePage.evaluate(() => window.customFighterMobilePress('attack'));
  await mobilePage.waitForFunction(
    () => Number(document.documentElement.dataset.comboStep) >= 1,
    null,
    { timeout: 2_000 },
  );
  await mobilePage.evaluate(() => window.customFighterMobileRelease('attack'));
  await mobilePage.waitForFunction(
    () => Number(document.documentElement.dataset.comboStep) === 0,
    null,
    { timeout: 3_000 },
  );

  const mpBefore = Number(await mobilePage.evaluate(() => document.documentElement.dataset.playerMp));
  await mobilePage.evaluate(() => window.customFighterMobilePress('skill_1'));
  await mobilePage.waitForFunction(
    (before) => Number(document.documentElement.dataset.playerMp) < before,
    mpBefore,
    { timeout: 3_000 },
  );
  await mobilePage.evaluate(() => window.customFighterMobileRelease('skill_1'));
  await mobilePage.waitForFunction(
    () => Number(document.documentElement.dataset.skillHitCount) >= 1,
    null,
    { timeout: 6_000 },
  );
  await mobilePage.close();

  // Separately prove the production auto-detection path using Playwright's touch context.
  const autoPage = await browser.newPage({
    viewport: { width: 844, height: 390 },
    hasTouch: true,
  });
  attachDiagnostics(autoPage, 'mobile-auto');
  const autoResponse = await autoPage.goto(baseUrl, { waitUntil: 'domcontentloaded', timeout: 60_000 });
  if (!autoResponse?.ok()) throw new Error(`Auto-touch Training URL returned HTTP ${autoResponse?.status() ?? 'unknown'}`);
  await autoPage.waitForFunction(
    () => document.documentElement.dataset.godotReady === 'true',
    null,
    { timeout: 60_000 },
  );
  const autoState = await snapshot(autoPage, 'MOBILE_AUTO_READY');
  if (!(autoState.maxTouchPoints > 0 || autoState.coarsePointer)) {
    throw new Error(`Playwright touch context did not expose a touch-capable browser environment: ${JSON.stringify(autoState)}`);
  }
  await autoPage.waitForFunction(
    () =>
      document.documentElement.dataset.mobileControlsReady === 'true' &&
      document.documentElement.dataset.mobileControlsTouchCapable === 'true' &&
      document.documentElement.dataset.mobileControlsVisible === 'true',
    null,
    { timeout: 15_000 },
  );
  await autoPage.close();

  const desktopUrl = new URL(baseUrl);
  desktopUrl.searchParams.set('mobile_controls', '0');
  const desktopPage = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  attachDiagnostics(desktopPage, 'desktop-hidden');
  const desktopResponse = await desktopPage.goto(desktopUrl.toString(), { waitUntil: 'domcontentloaded', timeout: 60_000 });
  if (!desktopResponse?.ok()) throw new Error(`Desktop Training URL returned HTTP ${desktopResponse?.status() ?? 'unknown'}`);
  await desktopPage.waitForFunction(
    () =>
      document.documentElement.dataset.godotReady === 'true' &&
      document.documentElement.dataset.mobileControlsReady === 'true' &&
      document.documentElement.dataset.mobileControlsVisible === 'false',
    null,
    { timeout: 60_000 },
  );
  await snapshot(desktopPage, 'DESKTOP_HIDDEN_READY');
  await desktopPage.close();

  console.log('WEB_MOBILE_CONTROLS_SMOKE_PASSED autoTouch=true forcedOverride=true movement=true guard=true jump=true attack=true skill1=true desktopHidden=true');
} finally {
  await browser.close();
}
