import { chromium } from 'playwright';

const baseUrl = process.env.CUSTOM_FIGHTER_WEB_URL ?? 'http://127.0.0.1:8000';
const browserChannel = process.env.BROWSER_CHANNEL?.trim();
const launchOptions = { headless: true };
if (browserChannel) launchOptions.channel = browserChannel;

console.log(`FORMATION_SMOKE_BROWSER=${browserChannel || 'playwright-chromium'}`);
console.log(`FORMATION_SMOKE_URL=${baseUrl}`);

const browser = await chromium.launch(launchOptions);
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const pageErrors = [];
const consoleErrors = [];

page.on('pageerror', (error) => {
  const detail = error?.stack || error?.message || String(error);
  pageErrors.push(detail);
  console.error(`[formation pageerror] ${detail}`);
});
page.on('console', (message) => {
  console.log(`[formation browser ${message.type()}] ${message.text()}`);
  if (message.type() === 'error') consoleErrors.push(message.text());
});
page.on('requestfailed', (request) => {
  console.error(`[formation requestfailed] ${request.url()} :: ${request.failure()?.errorText ?? 'unknown'}`);
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

try {
  const response = await page.goto(baseUrl, { waitUntil: 'domcontentloaded', timeout: 60_000 });
  if (!response?.ok()) {
    throw new Error(`Formation test Web build returned HTTP ${response?.status() ?? 'unknown'}`);
  }

  await page.waitForFunction(
    () =>
      document.documentElement.dataset.godotReady === 'true' &&
      document.documentElement.dataset.formationSkillLoaded === 'true',
    null,
    { timeout: 60_000 },
  );

  if ((await readText('formationSkillId')) !== 'blade_rain_001') {
    throw new Error(`Unexpected formation skill id: ${await readText('formationSkillId')}`);
  }
  if ((await readNumber('formationStrikeCount')) !== 5) {
    throw new Error(`Unexpected formation strike count: ${await readNumber('formationStrikeCount')}`);
  }
  if ((await readNumber('playerMp')) !== 100 || (await readNumber('dummyHp')) !== 100) {
    throw new Error(`Unexpected clean state: mp=${await readNumber('playerMp')} hp=${await readNumber('dummyHp')}`);
  }

  // The default spawn geometry intentionally places the fifth JSON-driven formation cell
  // over the training dummy, so this test validates the actual configured spacing/offset.
  await holdKey('p');
  await page.waitForFunction(
    () => Number(document.documentElement.dataset.playerMp) === 65,
    null,
    { timeout: 3_000 },
  );

  const cooldownAfterCast = await readNumber('formationSkillCooldown');
  if (!(cooldownAfterCast > 0)) {
    throw new Error(`Formation cooldown did not start: ${cooldownAfterCast}`);
  }

  // Recast during startup/cooldown must not spend another 35 MP.
  await holdKey('p');
  await page.waitForTimeout(120);
  if ((await readNumber('playerMp')) !== 65) {
    throw new Error(`Formation duplicate cast spent MP: ${await readNumber('playerMp')}`);
  }

  await page.waitForFunction(
    () =>
      Number(document.documentElement.dataset.formationStrikesEmitted) === 5 &&
      Number(document.documentElement.dataset.lastFormationStrikeIndex) === 4,
    null,
    { timeout: 4_000 },
  );

  await page.waitForFunction(
    () =>
      Number(document.documentElement.dataset.formationSkillHitCount) === 1 &&
      Number(document.documentElement.dataset.dummyHp) === 86 &&
      document.documentElement.dataset.lastFormationSkillHit === 'true',
    null,
    { timeout: 4_000 },
  );

  const finalStrikeX = await readNumber('lastFormationStrikeX');
  if (!(finalStrikeX > 750)) {
    throw new Error(`Formation final strike did not reach configured corridor: x=${finalStrikeX}`);
  }

  await page.waitForFunction(
    () => document.documentElement.dataset.formationSkillActive === 'false',
    null,
    { timeout: 3_000 },
  );
  if ((await readNumber('formationSkillHitCount')) !== 1) {
    throw new Error(`Formation hit count changed after completion: ${await readNumber('formationSkillHitCount')}`);
  }

  await page.waitForFunction(
    () => document.documentElement.dataset.formationSkillCanCast === 'true',
    null,
    { timeout: 6_000 },
  );

  if (pageErrors.length > 0 || consoleErrors.length > 0) {
    throw new Error(
      `Formation browser errors detected. pageErrors=${pageErrors.join(' | ')} consoleErrors=${consoleErrors.join(' | ')}`,
    );
  }

  console.log(
    `WEB_FORMATION_SKILL_SMOKE_PASSED damage=14 mpAfterCast=65 strikes=5 hitCount=${await readNumber('formationSkillHitCount')} finalHp=${await readNumber('dummyHp')} finalStrikeX=${finalStrikeX} cooldownAfterCast=${cooldownAfterCast}`,
  );
} finally {
  await browser.close();
}
