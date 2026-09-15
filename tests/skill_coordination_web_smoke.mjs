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
  const initialRejectionCount = await readNumber('skillCoordinatorRejectionCount');

  // First make U/skill_1 acquire the coordinator from durable runtime evidence. The Area
  // controller deliberately checks can_claim() before _try_cast(), so a competing O press is
  // gated before try_claim() and must NOT increment the coordinator rejection counter.
  // areaSkillInputLatched proves the O input was actually sampled by the controller while the
  // first skill owned the coordinator; it avoids relying on an arbitrary wall-clock hold.
  await page.keyboard.down('u');
  try {
    await page.waitForFunction(
      ({ expectedClaimCount }) =>
        Number(document.documentElement.dataset.playerMp) === 75 &&
        document.documentElement.dataset.skillCoordinatorBusy === 'true' &&
        document.documentElement.dataset.skillCoordinatorOwner === 'skill_1' &&
        document.documentElement.dataset.skillCoordinatorLastClaimed === 'skill_1' &&
        Number(document.documentElement.dataset.skillCoordinatorClaimCount) === expectedClaimCount,
      { expectedClaimCount: initialClaimCount + 1 },
      { timeout: 5_000 },
    );

    await page.keyboard.down('o');
    try {
      await page.waitForFunction(
        ({ expectedClaimCount, initialRejections }) =>
          document.documentElement.dataset.areaSkillInputLatched === 'true' &&
          Number(document.documentElement.dataset.playerMp) === 75 &&
          Number(document.documentElement.dataset.skillCoordinatorClaimCount) === expectedClaimCount &&
          Number(document.documentElement.dataset.skillCoordinatorRejectionCount) === initialRejections &&
          document.documentElement.dataset.areaSkillPhase === 'READY' &&
          Number(document.documentElement.dataset.areaSkillCooldown) === 0,
        { expectedClaimCount: initialClaimCount + 1, initialRejections: initialRejectionCount },
        { timeout: 2_500 },
      );
    } finally {
      await page.keyboard.up('o');
    }
  } finally {
    await page.keyboard.up('u');
  }

  await page.waitForFunction(
    () => document.documentElement.dataset.areaSkillInputLatched === 'false',
    null,
    { timeout: 2_500 },
  );

  const mpAfterContendedInput = await readNumber('playerMp');
  const lastClaimed = await readText('skillCoordinatorLastClaimed');
  const lastRejected = await readText('skillCoordinatorLastRejected');
  const claimCount = await readNumber('skillCoordinatorClaimCount');
  const rejectionCount = await readNumber('skillCoordinatorRejectionCount');
  const areaPhase = await readText('areaSkillPhase');
  const areaCooldown = await readNumber('areaSkillCooldown');
  const fireballCooldown = await readNumber('skillCooldown');

  if (mpAfterContendedInput !== 75) {
    throw new Error(`Expected only U to spend MP (100 -> 75); got ${mpAfterContendedInput}`);
  }
  if (lastClaimed !== 'skill_1') {
    throw new Error(`Expected persistent last claim to be skill_1; got '${lastClaimed}'`);
  }
  if (claimCount !== initialClaimCount + 1) {
    throw new Error(`Expected exactly one coordinator claim; before=${initialClaimCount} after=${claimCount}`);
  }
  if (rejectionCount !== initialRejectionCount) {
    throw new Error(
      `Expected Area input gate to avoid try_claim rejection; before=${initialRejectionCount} after=${rejectionCount}`,
    );
  }
  if (areaPhase !== 'READY' || areaCooldown !== 0) {
    throw new Error(`O cast escaped coordinator: phase=${areaPhase} cooldown=${areaCooldown}`);
  }

  // Cooldown is transient and can complete before a production Edge runner gets another
  // sampling turn. Durable claim telemetry, the Area input latch, and exact MP spend prove
  // exclusivity without depending on a wall-clock overlap window.
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.skillCoordinatorBusy === 'false' &&
      document.documentElement.dataset.skillCoordinatorOwner === '',
    null,
    { timeout: 8_000 },
  );

  if (pageErrors.length > 0 || consoleErrors.length > 0) {
    throw new Error(
      `Browser errors detected. pageErrors=${pageErrors.join(' | ')} consoleErrors=${consoleErrors.join(' | ')}`,
    );
  }

  console.log(
    `WEB_SKILL_COORDINATION_SMOKE_PASSED mp=${mpAfterContendedInput} lastClaimed=${lastClaimed} lastRejected=${lastRejected} claims=${claimCount - initialClaimCount} rejections=${rejectionCount - initialRejectionCount} sampledFireballCooldown=${fireballCooldown} areaPhase=${areaPhase} areaCooldown=${areaCooldown}`,
  );
} finally {
  await browser.close();
}
