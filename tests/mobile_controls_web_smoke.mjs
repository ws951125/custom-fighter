import { chromium } from 'playwright';

const baseUrl = process.env.CUSTOM_FIGHTER_WEB_URL ?? 'http://127.0.0.1:8000';
const browserChannel = process.env.BROWSER_CHANNEL?.trim();
const launchOptions = { headless: true };
if (browserChannel) launchOptions.channel = browserChannel;

console.log(`MOBILE_CONTROLS_BROWSER=${browserChannel || 'playwright-chromium'}`);
console.log(`MOBILE_CONTROLS_BASE_URL=${baseUrl}`);

const browser = await chromium.launch(launchOptions);
try {
  const mobilePage = await browser.newPage({
    viewport: { width: 844, height: 390 },
    hasTouch: true,
    isMobile: true,
  });
  const response = await mobilePage.goto(baseUrl, { waitUntil: 'domcontentloaded', timeout: 60_000 });
  if (!response?.ok()) throw new Error(`Mobile Training URL returned HTTP ${response?.status() ?? 'unknown'}`);

  await mobilePage.waitForFunction(
    () =>
      document.documentElement.dataset.godotReady === 'true' &&
      document.documentElement.dataset.mobileControlsReady === 'true' &&
      document.documentElement.dataset.mobileControlsVisible === 'true' &&
      document.documentElement.dataset.mobileControlsTouchCapable === 'true' &&
      document.documentElement.dataset.mobileControlsLayout === 'landscape-v1' &&
      Number(document.documentElement.dataset.mobileControlsButtonCount) === 15 &&
      typeof window.customFighterMobilePress === 'function' &&
      typeof window.customFighterMobileRelease === 'function',
    null,
    { timeout: 60_000 },
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

  const desktopUrl = new URL(baseUrl);
  desktopUrl.searchParams.set('mobile_controls', '0');
  const desktopPage = await browser.newPage({ viewport: { width: 1280, height: 720 } });
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
  await desktopPage.close();

  console.log('WEB_MOBILE_CONTROLS_SMOKE_PASSED autoTouch=true movement=true guard=true jump=true attack=true skill1=true desktopHidden=true');
} finally {
  await browser.close();
}
