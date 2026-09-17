import { chromium } from 'playwright';

const baseUrl = process.env.CUSTOM_FIGHTER_WEB_URL ?? 'http://127.0.0.1:8000';
const browserChannel = process.env.BROWSER_CHANNEL?.trim();
const launchOptions = { headless: true };
if (browserChannel) launchOptions.channel = browserChannel;

console.log(`CREATOR_SKILL_BROWSER=${browserChannel || 'playwright-chromium'}`);
console.log(`CREATOR_SKILL_BASE_URL=${baseUrl}`);

function creatorUrl() {
  const url = new URL(baseUrl);
  url.searchParams.set('mode', 'creator');
  return url.toString();
}

async function dataset(page, key) {
  return String(await page.evaluate((name) => document.documentElement.dataset[name] ?? '', key));
}

async function waitForRevision(page, key, before) {
  await page.waitForFunction(
    ({ datasetKey, previous }) => Number(document.documentElement.dataset[datasetKey] ?? '0') > previous,
    { datasetKey: key, previous: before },
    { timeout: 5_000 },
  );
}

const browser = await chromium.launch(launchOptions);
try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const response = await page.goto(creatorUrl(), { waitUntil: 'domcontentloaded', timeout: 60_000 });
  if (!response?.ok()) throw new Error(`Creator URL returned HTTP ${response?.status() ?? 'unknown'}`);

  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorStudioReady === 'true' &&
      typeof window.customFighterCreatorSelectEditor === 'function' &&
      typeof window.customFighterCreatorSetSkillName === 'function' &&
      typeof window.customFighterCreatorSetSkillType === 'function' &&
      typeof window.customFighterCreatorSetSkillSpeed === 'function' &&
      typeof window.customFighterCreatorSetSkillRange === 'function' &&
      typeof window.customFighterCreatorResetSkillDraft === 'function',
    null,
    { timeout: 60_000 },
  );

  if ((await dataset(page, 'creatorEditor')) !== 'character') {
    throw new Error(`Creator should initially show Character Editor: ${await dataset(page, 'creatorEditor')}`);
  }

  await page.evaluate(() => window.customFighterCreatorSelectEditor('skill'));
  await page.waitForFunction(() => document.documentElement.dataset.creatorEditor === 'skill', null, { timeout: 5_000 });

  const starter = {
    valid: await dataset(page, 'creatorSkillDraftValid'),
    id: await dataset(page, 'creatorSkillDraftId'),
    name: await dataset(page, 'creatorSkillDraftName'),
    type: await dataset(page, 'creatorSkillDraftType'),
    damage: Number(await dataset(page, 'creatorSkillDraftDamage')),
    mpCost: Number(await dataset(page, 'creatorSkillDraftMpCost')),
    speed: Number(await dataset(page, 'creatorSkillDraftSpeed')),
    range: Number(await dataset(page, 'creatorSkillDraftRange')),
  };
  if (
    starter.valid !== 'true' ||
    starter.id !== 'my_projectile_001' ||
    starter.name !== 'My Projectile' ||
    starter.type !== 'projectile' ||
    starter.damage !== 18 ||
    starter.mpCost !== 25 ||
    Math.abs(starter.speed - 560) > 0.01 ||
    Math.abs(starter.range - 900) > 0.01
  ) {
    throw new Error(`Starter projectile draft mismatch: ${JSON.stringify(starter)}`);
  }

  for (const family of ['melee', 'projectile', 'area', 'dash', 'formation', 'buff']) {
    const before = Number(await dataset(page, 'creatorSkillDraftRevision'));
    await page.evaluate((value) => window.customFighterCreatorSetSkillType(value), family);
    await waitForRevision(page, 'creatorSkillDraftRevision', before);
    const actualType = await dataset(page, 'creatorSkillDraftType');
    const valid = await dataset(page, 'creatorSkillDraftValid');
    if (actualType !== family || valid !== 'true') {
      throw new Error(`Creator family ${family} did not validate: type=${actualType} valid=${valid} error=${await dataset(page, 'creatorSkillDraftError')}`);
    }
    if (family === 'formation') {
      const count = Number(await dataset(page, 'creatorSkillDraftFormationCount'));
      const spacing = Number(await dataset(page, 'creatorSkillDraftFormationSpacing'));
      const interval = Number(await dataset(page, 'creatorSkillDraftFormationInterval'));
      if (count !== 4 || Math.abs(spacing - 80) > 0.01 || Math.abs(interval - 0.15) > 0.001) {
        throw new Error(`Formation safe defaults missing: count=${count} spacing=${spacing} interval=${interval}`);
      }
    }
    if (family === 'buff') {
      const duration = Number(await dataset(page, 'creatorSkillDraftBuffDuration'));
      const moveMultiplier = Number(await dataset(page, 'creatorSkillDraftMoveSpeedMultiplier'));
      const damageMultiplier = Number(await dataset(page, 'creatorSkillDraftBasicDamageMultiplier'));
      if (Math.abs(duration - 5) > 0.01 || moveMultiplier < 1 || damageMultiplier < 1) {
        throw new Error(`Buff safe defaults missing: duration=${duration} move=${moveMultiplier} damage=${damageMultiplier}`);
      }
    }
  }

  let revision = Number(await dataset(page, 'creatorSkillDraftRevision'));
  await page.evaluate(() => window.customFighterCreatorSetSkillType('projectile'));
  await waitForRevision(page, 'creatorSkillDraftRevision', revision);

  revision = Number(await dataset(page, 'creatorSkillDraftRevision'));
  await page.evaluate(() => window.customFighterCreatorSetSkillName(''));
  await waitForRevision(page, 'creatorSkillDraftRevision', revision);
  if ((await dataset(page, 'creatorSkillDraftValid')) !== 'false') {
    throw new Error('Blank projectile name should make SkillDraft invalid');
  }
  if (!(await dataset(page, 'creatorSkillDraftError')).includes('name must not be empty')) {
    throw new Error(`Blank-name error missing: ${await dataset(page, 'creatorSkillDraftError')}`);
  }

  revision = Number(await dataset(page, 'creatorSkillDraftRevision'));
  await page.evaluate(() => window.customFighterCreatorSetSkillName('Nova Bolt'));
  await waitForRevision(page, 'creatorSkillDraftRevision', revision);
  if ((await dataset(page, 'creatorSkillDraftValid')) !== 'true') {
    throw new Error(`Valid projectile name did not restore validity: ${await dataset(page, 'creatorSkillDraftError')}`);
  }

  revision = Number(await dataset(page, 'creatorSkillDraftRevision'));
  await page.evaluate(() => window.customFighterCreatorSetSkillSpeed(0));
  await waitForRevision(page, 'creatorSkillDraftRevision', revision);
  if ((await dataset(page, 'creatorSkillDraftValid')) !== 'false') {
    throw new Error('Zero projectile speed should make SkillDraft invalid');
  }
  if (!(await dataset(page, 'creatorSkillDraftError')).includes('projectile speed must be positive')) {
    throw new Error(`Projectile-speed error missing: ${await dataset(page, 'creatorSkillDraftError')}`);
  }

  revision = Number(await dataset(page, 'creatorSkillDraftRevision'));
  await page.evaluate(() => window.customFighterCreatorSetSkillSpeed(720));
  await waitForRevision(page, 'creatorSkillDraftRevision', revision);
  if ((await dataset(page, 'creatorSkillDraftValid')) !== 'true') {
    throw new Error(`Positive projectile speed did not restore validity: ${await dataset(page, 'creatorSkillDraftError')}`);
  }

  revision = Number(await dataset(page, 'creatorSkillDraftRevision'));
  await page.evaluate(() => window.customFighterCreatorSetSkillRange(0));
  await waitForRevision(page, 'creatorSkillDraftRevision', revision);
  if ((await dataset(page, 'creatorSkillDraftValid')) !== 'false') {
    throw new Error('Zero projectile range should make SkillDraft invalid');
  }

  revision = Number(await dataset(page, 'creatorSkillDraftRevision'));
  await page.evaluate(() => window.customFighterCreatorSetSkillRange(1100));
  await waitForRevision(page, 'creatorSkillDraftRevision', revision);
  if ((await dataset(page, 'creatorSkillDraftValid')) !== 'true') {
    throw new Error(`Positive projectile range did not restore validity: ${await dataset(page, 'creatorSkillDraftError')}`);
  }

  revision = Number(await dataset(page, 'creatorSkillDraftRevision'));
  await page.evaluate(() => window.customFighterCreatorSetSkillDamage(42));
  await waitForRevision(page, 'creatorSkillDraftRevision', revision);
  if (Number(await dataset(page, 'creatorSkillDraftDamage')) !== 42 || (await dataset(page, 'creatorSkillDraftValid')) !== 'true') {
    throw new Error('Valid damage edit did not persist in SkillDraft diagnostics');
  }

  revision = Number(await dataset(page, 'creatorSkillDraftRevision'));
  await page.evaluate(() => window.customFighterCreatorResetSkillDraft());
  await waitForRevision(page, 'creatorSkillDraftRevision', revision);
  const reset = {
    valid: await dataset(page, 'creatorSkillDraftValid'),
    name: await dataset(page, 'creatorSkillDraftName'),
    type: await dataset(page, 'creatorSkillDraftType'),
    damage: Number(await dataset(page, 'creatorSkillDraftDamage')),
    speed: Number(await dataset(page, 'creatorSkillDraftSpeed')),
    range: Number(await dataset(page, 'creatorSkillDraftRange')),
  };
  if (
    reset.valid !== 'true' ||
    reset.name !== 'My Projectile' ||
    reset.type !== 'projectile' ||
    reset.damage !== 18 ||
    Math.abs(reset.speed - 560) > 0.01 ||
    Math.abs(reset.range - 900) > 0.01
  ) {
    throw new Error(`Reset projectile draft mismatch: ${JSON.stringify(reset)}`);
  }

  await page.evaluate(() => window.customFighterCreatorSelectEditor('character'));
  await page.waitForFunction(() => document.documentElement.dataset.creatorEditor === 'character', null, { timeout: 5_000 });
  if ((await dataset(page, 'creatorDraftValid')) !== 'true') {
    throw new Error('Character Editor regression: character starter draft should remain valid');
  }

  console.log('WEB_CREATOR_SKILL_EDITOR_SMOKE_PASSED families=6 projectileRegression=true validInvalidValid=true reset=true');
} finally {
  await browser.close();
}
