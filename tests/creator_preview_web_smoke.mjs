import { chromium } from 'playwright';

const baseUrl = process.env.CUSTOM_FIGHTER_WEB_URL ?? 'http://127.0.0.1:8000';
const browserChannel = process.env.BROWSER_CHANNEL?.trim();
const launchOptions = { headless: true };
if (browserChannel) launchOptions.channel = browserChannel;

console.log(`CREATOR_PREVIEW_BROWSER=${browserChannel || 'playwright-chromium'}`);
console.log(`CREATOR_PREVIEW_BASE_URL=${baseUrl}`);

const browser = await chromium.launch(launchOptions);
try {
  const creatorUrl = new URL(baseUrl);
  creatorUrl.searchParams.set('mode', 'creator');
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const response = await page.goto(creatorUrl.toString(), { waitUntil: 'domcontentloaded', timeout: 60_000 });
  if (!response?.ok()) throw new Error(`Creator preview URL returned HTTP ${response?.status() ?? 'unknown'}`);

  await page.waitForFunction(
    () =>
      document.documentElement.dataset.appMode === 'creator' &&
      document.documentElement.dataset.creatorStudioReady === 'true' &&
      document.documentElement.dataset.creatorPreviewReady === 'true' &&
      typeof window.customFighterCreatorPreview === 'function' &&
      typeof window.customFighterCreatorSetSkillMpCost === 'function' &&
      typeof window.customFighterCreatorSetSkillCooldown === 'function',
    null,
    { timeout: 60_000 },
  );

  await page.evaluate(() => window.customFighterCreatorSetName(''));
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorDraftValid === 'false' &&
      document.documentElement.dataset.creatorPreviewCanLaunch === 'false',
    null,
    { timeout: 5_000 },
  );
  await page.evaluate(() => window.customFighterCreatorPreview());
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.appMode === 'creator' &&
      (document.documentElement.dataset.creatorPreviewError ?? '').includes('Fix invalid'),
    null,
    { timeout: 5_000 },
  );

  await page.evaluate(() => {
    window.customFighterCreatorSetName('Preview Nova');
    window.customFighterCreatorSetMaxHp(180);
    window.customFighterCreatorSetSkillName('Nova Bolt');
    window.customFighterCreatorSetSkillDamage(33);
    window.customFighterCreatorSetSkillMpCost(17);
    window.customFighterCreatorSetSkillCooldown(2.4);
  });
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.creatorDraftValid === 'true' &&
      document.documentElement.dataset.creatorSkillDraftValid === 'true' &&
      document.documentElement.dataset.creatorDraftName === 'Preview Nova' &&
      document.documentElement.dataset.creatorDraftMaxHp === '180' &&
      document.documentElement.dataset.creatorSkillDraftName === 'Nova Bolt' &&
      document.documentElement.dataset.creatorSkillDraftDamage === '33' &&
      document.documentElement.dataset.creatorSkillDraftMpCost === '17' &&
      Math.abs(Number(document.documentElement.dataset.creatorSkillDraftCooldown) - 2.4) < 0.001 &&
      document.documentElement.dataset.creatorPreviewCanLaunch === 'true',
    null,
    { timeout: 5_000 },
  );

  await page.evaluate(() => window.customFighterCreatorPreview());
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.appMode === 'training' &&
      document.documentElement.dataset.creatorPreviewActive === 'true' &&
      document.documentElement.dataset.playerCharacterSource === 'creator_preview_session' &&
      document.documentElement.dataset.playerCharacterName === 'Preview Nova' &&
      document.documentElement.dataset.playerMaxHp === '180' &&
      document.documentElement.dataset.playerRuntimeSkill1 === 'my_projectile_001' &&
      document.documentElement.dataset.skillId === 'my_projectile_001' &&
      document.documentElement.dataset.creatorPreviewRuntimeSkillDamage === '33' &&
      document.documentElement.dataset.creatorPreviewRuntimeSkillMpCost === '17' &&
      Math.abs(Number(document.documentElement.dataset.creatorPreviewRuntimeSkillCooldown) - 2.4) < 0.001 &&
      document.documentElement.dataset.creatorPreviewReturnReady === 'true' &&
      typeof window.customFighterPreviewReturnToCreator === 'function',
    null,
    { timeout: 60_000 },
  );

  await page.keyboard.down('u');
  await page.waitForFunction(
    () => Number(document.documentElement.dataset.playerMp) === 83,
    null,
    { timeout: 3_000 },
  );
  await page.keyboard.up('u');
  await page.waitForFunction(
    () =>
      Number(document.documentElement.dataset.dummyHp) === 67 &&
      document.documentElement.dataset.lastSkillHit === 'true' &&
      Number(document.documentElement.dataset.skillHitCount) >= 1,
    null,
    { timeout: 5_000 },
  );

  await page.evaluate(() => window.customFighterPreviewReturnToCreator());
  await page.waitForFunction(
    () =>
      document.documentElement.dataset.appMode === 'creator' &&
      document.documentElement.dataset.creatorStudioReady === 'true' &&
      document.documentElement.dataset.creatorDraftName === 'Preview Nova' &&
      document.documentElement.dataset.creatorDraftMaxHp === '180' &&
      document.documentElement.dataset.creatorSkillDraftName === 'Nova Bolt' &&
      document.documentElement.dataset.creatorSkillDraftDamage === '33' &&
      document.documentElement.dataset.creatorSkillDraftMpCost === '17' &&
      Math.abs(Number(document.documentElement.dataset.creatorSkillDraftCooldown) - 2.4) < 0.001,
    null,
    { timeout: 10_000 },
  );

  console.log('WEB_CREATOR_PREVIEW_SMOKE_PASSED invalidBlocked=true authoredHp=180 authoredDamage=33 authoredMpCost=17 authoredCooldown=2.4 cast=true draftsRestored=true');
  await page.close();
} finally {
  await browser.close();
}
