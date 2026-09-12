import { chromium } from 'playwright';

const baseUrl = process.env.CUSTOM_FIGHTER_WEB_URL ?? 'http://127.0.0.1:8000';
const browserChannel = process.env.BROWSER_CHANNEL?.trim();
const launchOptions = { headless: true };
if (browserChannel) launchOptions.channel = browserChannel;

console.log(`COORDINATION_SMOKE_BROWSER=${browserChannel || 'playwright-chromium'}`);
console.log(`COORDINATION_SMOKE_URL=${baseUrl}`);

const browser = await chromium.launch(launchOptions);
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const pageErrors = [];
const consoleErrors = [];

page.on('pageerror', (error) => {
  const detail = error?.stack || error?.message || String(error);
  pageErrors.push(detail);
  console.error(`[pageerror] ${detail}`);
});
page.on('console', (message) => {
  if (message.type() === 'error') consoleErrors.push(message.text());
});
page.on('requestfailed', (request) => {
  console.error(`[requestfailed] ${request.url()} :: ${request.failure()?.errorText ?? 'unknown'}`);
});

async function readText(key) {
  return String(await page.evaluate((name) => document.documentElement.dataset[name] ?? '', key));
}

async function readNumber(key) {
  return Number(await page.evaluate((name) => document.documentElement.dataset[name] ?? 'NaN', key));
}

try {
  const response = await page.goto(baseUrl, { waitUntil: 'domcontentloaded', timeout: 60_000 });
  if (!response?.ok()) throw new Error(`Web build returned HTTP ${response?.status() ?? 'unknown'}`);

  await page.waitForFunction(
    () =>
      document.documentElement.dataset.godotReady === 'true' &&
      document.documentElement.dataset.areaSkillLoaded === 'true' &&
      document.documentElement.dataset.skillCoordinatorBusy === 'false',
    null,
    { timeout: 60_000 },
  );

  if ((await readNumber('playerMp')) !== 100) {
    throw new Error(`Unexpected initial MP: ${await readNumber('playerMp')}`);
  }

  const initialClaimCount = await readNumber('skillCoordinatorClaimCount');

  // U is handled by the parent runtime before O's child controller. Holding both across
  // multiple Godot frames proves the coordinator, not synthetic key timing, decides exclusivity.
  await page.keyboard.down('u');
  await page.keyboard.down('o');
  await page.waitForTimeout(120);
  await page.keyboard.up('o');
  await page.keyboard.up('u');

  await page.waitForFunction(
    () => Number(document.documentElement.dataset.playerMp) < 100,
    null,
    { timeout: 3_000 },
  );

  const mpAfterSimultaneousInput = await readNumber('playerMp');
  const lastClaimed = await readText('skillCoordinatorLastClaimed');
  const claimCount = await readNumber('skillCoordinatorClaimCount');
  const areaPhase = await readText('areaSkillPhase');
  const areaCooldown = await readNumber('areaSkillCooldown');
  const fireballCooldown = await readNumber('skillCooldown');

  if (mpAfterSimultaneousInput !== 75) {
    throw new Error(`Expected exactly one U cast (100 -> 75 MP); got ${mpAfterSimultaneousInput}`);
  }
  if (lastClaimed !== 'skill_1') {
    throw new Error(`Expected persistent last claim to be skill_1; got '${lastClaimed}'`);
  }
  if (claimCount !== initialClaimCount + 1) {
    throw new Error(`Expected exactly one coordinator claim; before=${initialClaimCount} after=${claimCount}`);
  }
  if (!Number.isFinite(fireballCooldown) || fireballCooldown < 0) {
    throw new Error(`Invalid U cooldown diagnostic: ${fireballCooldown}`);
  }
  if (areaPhase !== 'READY' || areaCooldown !== 0) {
    throw new Error(`O cast escaped coordinator: phase=${areaPhase} cooldown=${areaCooldown}`);
  }

  // Cooldown remaining is transient and can legitimately reach zero before a slower hosted
  // production browser observes this point. MP consumption + lastClaimed + claimCount are the
  // durable proof that U actually cast and was the only coordinator owner.
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.skillCoordinatorBusy === 'false' &&
      document.documentElement.dataset.skillCoordinatorOwner === '',
    null,
    { timeout: 4_000 },
  );

  if (pageErrors.length > 0 || consoleErrors.length > 0) {
    throw new Error(
      `Browser errors detected. pageErrors=${pageErrors.join(' | ')} consoleErrors=${consoleErrors.join(' | ')}`,
    );
  }

  console.log(
    `WEB_SKILL_COORDINATION_SMOKE_PASSED mp=${mpAfterSimultaneousInput} lastClaimed=${lastClaimed} claims=${claimCount - initialClaimCount} fireballCooldownObserved=${fireballCooldown} areaPhase=${areaPhase} areaCooldown=${areaCooldown}`,
  );
} finally {
  await browser.close();
}
