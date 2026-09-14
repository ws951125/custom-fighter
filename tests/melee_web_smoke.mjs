import { chromium } from 'playwright';

const baseUrl = process.env.CUSTOM_FIGHTER_WEB_URL ?? 'http://127.0.0.1:8000';
const browserChannel = process.env.BROWSER_CHANNEL?.trim();
const launchOptions = { headless: true };
if (browserChannel) launchOptions.channel = browserChannel;

console.log(`MELEE_SMOKE_BROWSER=${browserChannel || 'playwright-chromium'}`);
console.log(`MELEE_SMOKE_URL=${baseUrl}`);

const browser = await chromium.launch(launchOptions);
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const pageErrors = [];
const consoleErrors = [];

page.on('pageerror', (error) => {
  const detail = error?.stack || error?.message || String(error);
  pageErrors.push(detail);
  console.error(`[melee pageerror] ${detail}`);
});
page.on('console', (message) => {
  console.log(`[melee browser ${message.type()}] ${message.text()}`);
  if (message.type() === 'error') consoleErrors.push(message.text());
});
page.on('requestfailed', (request) => {
  console.error(`[melee requestfailed] ${request.url()} :: ${request.failure()?.errorText ?? 'unknown'}`);
});

async function readNumber(key) {
  return Number(await page.evaluate((datasetKey) => document.documentElement.dataset[datasetKey], key));
}

async function readText(key) {
  return String(await page.evaluate((datasetKey) => document.documentElement.dataset[datasetKey] ?? '', key));
}

async function nudge(key, holdMs = 55) {
  await page.keyboard.down(key);
  await page.waitForTimeout(holdMs);
  await page.keyboard.up(key);
  await page.waitForTimeout(30);
}

async function castMeleeExpectMp(beforeMp, afterMp) {
  for (let attempt = 0; attempt < 4; attempt += 1) {
    await nudge('h', 120);
    try {
      await page.waitForFunction(
        (expectedMp) => Number(document.documentElement.dataset.playerMp) === expectedMp,
        afterMp,
        { timeout: 1_500 },
      );
      return;
    } catch {
      const currentMp = await readNumber('playerMp');
      if (currentMp === afterMp) return;
      if (currentMp !== beforeMp) {
        throw new Error(`Heavy Strike changed MP unexpectedly: before=${beforeMp} expected=${afterMp} actual=${currentMp}`);
      }
      const canCast = await readText('meleeSkillCanCast');
      if (canCast !== 'true') {
        throw new Error(`Heavy Strike input was observed without expected MP spend: mp=${currentMp} canCast=${canCast}`);
      }
      console.log(`MELEE_INPUT_RETRY attempt=${attempt + 1} mp=${currentMp} canCast=${canCast}`);
    }
  }
  throw new Error(`Heavy Strike input was not accepted after retries: expected MP ${beforeMp} -> ${afterMp}`);
}

async function waitForPositiveCooldown(label) {
  await page.waitForFunction(
    () => Number(document.documentElement.dataset.meleeSkillCooldown) > 0,
    null,
    { timeout: 2_500 },
  );
  const cooldown = await readNumber('meleeSkillCooldown');
  if (!(cooldown > 0)) throw new Error(`Expected melee cooldown after ${label}; got ${cooldown}`);
  return cooldown;
}

async function movementNudge(key, beforeX, holdMs) {
  await page.keyboard.down(key);
  await page.waitForTimeout(holdMs);
  await page.keyboard.up(key);

  // Hosted Edge can publish playerX more slowly than keyboard events are sent. Wait for
  // the runtime observation to advance before issuing another movement command so stale
  // dataset samples cannot queue several nudges and overshoot the target by a large amount.
  try {
    await page.waitForFunction(
      (previousX) => Math.abs(Number(document.documentElement.dataset.playerX) - previousX) > 0.5,
      beforeX,
      { timeout: 900 },
    );
  } catch {
    // A frame-polled input can legitimately be missed. The caller will re-read state and retry.
  }
  await page.waitForTimeout(55);
}

async function approachDummy() {
  const minGap = 40;
  const maxGap = 105;
  const stagingGap = maxGap + 55;
  let playerX = await readNumber('playerX');
  let dummyX = await readNumber('dummyX');
  let gap = dummyX - playerX;

  // Stage on the dummy's left, then make the final approach only with D. Heavy Strike
  // captures player facing when it casts, so a last-moment A correction can put a valid
  // in-range target behind the hitbox on slow hosted Edge runners.
  for (let step = 0; step < 100 && gap < stagingGap; step += 1) {
    await movementNudge('a', playerX, 28);
    playerX = await readNumber('playerX');
    dummyX = await readNumber('dummyX');
    gap = dummyX - playerX;
  }

  if (gap < stagingGap) {
    throw new Error(`Failed to stage left of dummy: playerX=${playerX} dummyX=${dummyX} gap=${gap}`);
  }

  for (let step = 0; step < 100 && gap > maxGap; step += 1) {
    const distanceFromRange = gap - maxGap;
    const holdMs = distanceFromRange > 220 ? 38 : distanceFromRange > 120 ? 28 : 20;
    await movementNudge('d', playerX, holdMs);
    playerX = await readNumber('playerX');
    dummyX = await readNumber('dummyX');
    gap = dummyX - playerX;
  }

  if (gap < minGap || gap > maxGap) {
    throw new Error(`Failed to enter Heavy Strike range while facing target: playerX=${playerX} dummyX=${dummyX} gap=${gap}`);
  }
  return { playerX, dummyX, gap };
}

try {
  const response = await page.goto(baseUrl, { waitUntil: 'domcontentloaded', timeout: 60_000 });
  if (!response?.ok()) throw new Error(`Web build returned HTTP ${response?.status() ?? 'unknown'}`);

  await page.waitForFunction(
    () => document.documentElement.dataset.godotReady === 'true',
    null,
    { timeout: 60_000 },
  );
  await page.waitForFunction(
    () => document.documentElement.dataset.meleeSkillLoaded === 'true',
    null,
    { timeout: 5_000 },
  );

  if ((await readText('meleeSkillId')) !== 'heavy_strike_001') {
    throw new Error(`Unexpected melee skill id: ${await readText('meleeSkillId')}`);
  }
  if ((await readNumber('playerMp')) !== 100 || (await readNumber('dummyHp')) !== 100) {
    throw new Error(`Unexpected initial resources: mp=${await readNumber('playerMp')} hp=${await readNumber('dummyHp')}`);
  }

  // Cast once while far away: MP/cooldown should apply, but the target must not be hit.
  const initialGap = (await readNumber('dummyX')) - (await readNumber('playerX'));
  if (!(initialGap > 200)) throw new Error(`Expected initial out-of-range gap; got ${initialGap}`);
  await castMeleeExpectMp(100, 82);
  const firstCooldown = await waitForPositiveCooldown('whiff');
  await page.waitForTimeout(700);
  if ((await readNumber('dummyHp')) !== 100 || (await readNumber('meleeSkillHitCount')) !== 0) {
    throw new Error(
      `Out-of-range Heavy Strike unexpectedly hit: hp=${await readNumber('dummyHp')} hits=${await readNumber('meleeSkillHitCount')}`,
    );
  }

  await page.waitForFunction(
    () => document.documentElement.dataset.meleeSkillCanCast === 'true',
    null,
    { timeout: 5_000 },
  );

  const rangeState = await approachDummy();

  // Cast in range: one JSON-authored melee hit must deal 24 damage and spend 18 MP.
  await castMeleeExpectMp(82, 64);
  await page.waitForFunction(
    () =>
      Number(document.documentElement.dataset.meleeSkillHitCount) === 1 &&
      Number(document.documentElement.dataset.dummyHp) === 76 &&
      document.documentElement.dataset.lastMeleeSkillHit === 'true',
    null,
    { timeout: 5_000 },
  );

  const secondCooldown = await waitForPositiveCooldown('hit');
  const centerX = await readNumber('meleeSkillCenterX');
  if (!(centerX > rangeState.playerX)) {
    throw new Error(`Expected right-facing melee hitbox in front: playerX=${rangeState.playerX} centerX=${centerX}`);
  }

  // A sampled recast during cooldown must be rejected without another MP spend or hit.
  await nudge('h', 120);
  await page.waitForTimeout(180);
  if ((await readNumber('playerMp')) !== 64) {
    throw new Error(`Melee cooldown recast spent MP: ${await readNumber('playerMp')}`);
  }
  await page.waitForTimeout(350);
  if ((await readNumber('dummyHp')) !== 76 || (await readNumber('meleeSkillHitCount')) !== 1) {
    throw new Error(
      `Melee activation hit more than once: hp=${await readNumber('dummyHp')} hits=${await readNumber('meleeSkillHitCount')}`,
    );
  }

  if (pageErrors.length > 0 || consoleErrors.length > 0) {
    throw new Error(
      `Browser errors detected. pageErrors=${pageErrors.join(' | ')} consoleErrors=${consoleErrors.join(' | ')}`,
    );
  }

  console.log(
    `WEB_MELEE_SKILL_SMOKE_PASSED damage=24 mpAfterTwoCasts=64 firstCooldown=${firstCooldown} secondCooldown=${secondCooldown} initialGap=${initialGap} hitGap=${rangeState.gap} finalHp=76 hitCount=1 centerX=${centerX}`,
  );
} finally {
  await browser.close();
}
