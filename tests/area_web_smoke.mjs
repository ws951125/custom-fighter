import { chromium } from 'playwright';

const baseUrl = process.env.CUSTOM_FIGHTER_WEB_URL ?? 'http://127.0.0.1:8000';
const browserChannel = process.env.BROWSER_CHANNEL?.trim();
const launchOptions = { headless: true };
if (browserChannel) launchOptions.channel = browserChannel;

console.log(`AREA_SMOKE_BROWSER=${browserChannel || 'playwright-chromium'}`);
console.log(`AREA_SMOKE_URL=${baseUrl}`);

const browser = await chromium.launch(launchOptions);
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const pageErrors = [];
const consoleErrors = [];

page.on('pageerror', (error) => {
  const detail = error?.stack || error?.message || String(error);
  pageErrors.push(detail);
  console.error(`[area pageerror] ${detail}`);
});
page.on('console', (message) => {
  console.log(`[area browser ${message.type()}] ${message.text()}`);
  if (message.type() === 'error') consoleErrors.push(message.text());
});
page.on('requestfailed', (request) => {
  console.error(`[area requestfailed] ${request.url()} :: ${request.failure()?.errorText ?? 'unknown'}`);
});

async function readNumber(key) {
  return Number(await page.evaluate((datasetKey) => document.documentElement.dataset[datasetKey], key));
}

async function readText(key) {
  return String(await page.evaluate((datasetKey) => document.documentElement.dataset[datasetKey] ?? '', key));
}

async function holdKey(key, holdMs = 90) {
  await page.keyboard.down(key);
  await page.waitForTimeout(holdMs);
  await page.keyboard.up(key);
  await page.waitForTimeout(35);
}

async function approachDummy(maxGap = 110) {
  for (let step = 0; step < 80; step += 1) {
    const playerX = await readNumber('playerX');
    const dummyX = await readNumber('dummyX');
    const gap = dummyX - playerX;
    if (gap > 40 && gap <= maxGap) return { playerX, dummyX, gap };
    await holdKey(gap > maxGap ? 'd' : 'a', 50);
  }
  throw new Error(
    `Failed to enter area-skill range: playerX=${await readNumber('playerX')} dummyX=${await readNumber('dummyX')}`,
  );
}

try {
  const response = await page.goto(baseUrl, { waitUntil: 'domcontentloaded', timeout: 60_000 });
  if (!response?.ok()) throw new Error(`Area test Web build returned HTTP ${response?.status() ?? 'unknown'}`);

  await page.waitForFunction(
    () =>
      document.documentElement.dataset.godotReady === 'true' &&
      document.documentElement.dataset.areaSkillLoaded === 'true',
    null,
    { timeout: 60_000 },
  );

  if ((await readText('areaSkillId')) !== 'arc_burst_001') {
    throw new Error(`Unexpected area skill id: ${await readText('areaSkillId')}`);
  }
  if ((await readNumber('playerMp')) !== 100 || (await readNumber('dummyHp')) !== 100) {
    throw new Error(`Unexpected clean state: mp=${await readNumber('playerMp')} hp=${await readNumber('dummyHp')}`);
  }

  const position = await approachDummy();
  console.log(`AREA_RANGE_READY gap=${position.gap} playerX=${position.playerX} dummyX=${position.dummyX}`);

  await holdKey('o');
  await page.waitForFunction(
    () => Number(document.documentElement.dataset.playerMp) === 70,
    null,
    { timeout: 3_000 },
  );

  const cooldownAfterCast = await readNumber('areaSkillCooldown');
  if (!(cooldownAfterCast > 0)) {
    throw new Error(`Area skill cooldown did not start: ${cooldownAfterCast}`);
  }

  // A second O during startup/active/cooldown must not spend another 30 MP.
  await holdKey('o');
  await page.waitForTimeout(120);
  if ((await readNumber('playerMp')) !== 70) {
    throw new Error(`Area skill duplicate cast spent MP: ${await readNumber('playerMp')}`);
  }

  await page.waitForFunction(
    () =>
      Number(document.documentElement.dataset.areaSkillHitCount) === 1 &&
      Number(document.documentElement.dataset.dummyHp) === 78 &&
      document.documentElement.dataset.lastAreaSkillHit === 'true',
    null,
    { timeout: 4_000 },
  );

  // The active window may stay visible after its one allowed hit, but it must expire.
  await page.waitForFunction(
    () => document.documentElement.dataset.areaSkillActive === 'false',
    null,
    { timeout: 3_000 },
  );
  if ((await readNumber('areaSkillHitCount')) !== 1) {
    throw new Error(`Area skill hit more than once: ${await readNumber('areaSkillHitCount')}`);
  }

  await page.waitForFunction(
    () => document.documentElement.dataset.areaSkillCanCast === 'true',
    null,
    { timeout: 5_000 },
  );

  if (pageErrors.length > 0 || consoleErrors.length > 0) {
    throw new Error(
      `Area browser errors detected. pageErrors=${pageErrors.join(' | ')} consoleErrors=${consoleErrors.join(' | ')}`,
    );
  }

  console.log(
    `WEB_AREA_SKILL_SMOKE_PASSED damage=22 mpAfterCast=70 cooldownAfterCast=${cooldownAfterCast} finalHp=${await readNumber('dummyHp')} hitCount=${await readNumber('areaSkillHitCount')}`,
  );
} finally {
  await browser.close();
}
