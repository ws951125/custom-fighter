import { chromium } from 'playwright';
import sharp from 'sharp';

const webUrl = process.env.CUSTOM_FIGHTER_WEB_URL ?? 'https://ws951125.github.io/custom-fighter/';
const backendUrl = process.env.CUSTOM_FIGHTER_AI_BACKEND_URL ?? 'https://custom-fighter-ai-vfx.onrender.com';
const expectedRevision = String(process.env.EXPECTED_BACKEND_REVISION ?? '').trim();
if (!expectedRevision) throw new Error('EXPECTED_BACKEND_REVISION is required');

const referencePng = await sharp({
  create: { width: 16, height: 16, channels: 4, background: { r: 24, g: 96, b: 255, alpha: 1 } },
}).png().toBuffer();

const browser = await chromium.launch({ headless: true });
try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const url = new URL(webUrl);
  url.searchParams.set('mode', 'vfx');
  url.searchParams.set('ai_vfx_provider', 'remote_ai_vfx');
  url.searchParams.set('ai_vfx_endpoint', `${backendUrl.replace(/\/$/, '')}/v1/vfx/generate`);

  const response = await page.goto(url.toString(), { waitUntil: 'domcontentloaded', timeout: 60_000 });
  if (!response?.ok()) throw new Error(`Production VFX URL returned HTTP ${response?.status() ?? 'unknown'}`);
  await page.waitForFunction(
    () => document.documentElement.dataset.creatorAiVfxReady === 'true' && document.documentElement.dataset.creatorAiVfxBackendReadiness === 'ready' && document.documentElement.dataset.creatorAiVfxGenerateEnabled === 'true',
    null,
    { timeout: 60_000 },
  );
  if ((await page.evaluate(() => document.documentElement.dataset.creatorAiVfxBackendProvider)) !== 'gemini') throw new Error('Production Creator backend is not Gemini');

  const dataUrl = `data:image/png;base64,${referencePng.toString('base64')}`;
  await page.evaluate((value) => window.customFighterCreatorAiVfxImportReference('p4-production-reference.png', 'image/png', value), dataUrl);
  await page.waitForFunction(() => document.documentElement.dataset.creatorAiVfxReferencePresent === 'true', null, { timeout: 10_000 });
  await page.evaluate(() => window.customFighterCreatorAiVfxSetPrompt('bright electric blue arc projectile with a white core'));
  await page.evaluate(() => window.customFighterCreatorAiVfxSetOutput(4, 64, 64, 10));
  await page.evaluate(() => window.customFighterCreatorAiVfxGenerate());
  await page.waitForFunction(
    () => document.documentElement.dataset.creatorAiVfxLastStatus === 'success' && document.documentElement.dataset.creatorAiVfxGeneratedValid === 'true' && document.documentElement.dataset.creatorVfxValid === 'true',
    null,
    { timeout: 120_000 },
  );

  await page.evaluate(() => window.customFighterCreatorVfxBackToCreator());
  await page.waitForFunction(
    () => document.documentElement.dataset.appMode === 'creator' && document.documentElement.dataset.creatorAiSkillProposalReady === 'true' && document.documentElement.dataset.creatorAiSkillProposalValid === 'true' && document.documentElement.dataset.creatorAiSkillProposalConfirmed === 'false',
    null,
    { timeout: 60_000 },
  );

  const damage = Number(await page.evaluate(() => document.documentElement.dataset.creatorAiSkillProposalDamage ?? document.documentElement.dataset.creatorSkillDraftDamage ?? '0'));
  await page.evaluate(() => window.customFighterCreatorConfirmPreviewAiSkillProposal());
  await page.waitForFunction(
    () => document.documentElement.dataset.appMode === 'training' && document.documentElement.dataset.creatorPreviewActive === 'true' && document.documentElement.dataset.creatorPreviewReturnReady === 'true',
    null,
    { timeout: 60_000 },
  );

  const mpBefore = Number(await page.evaluate(() => document.documentElement.dataset.playerMp));
  const hpBefore = Number(await page.evaluate(() => document.documentElement.dataset.dummyHp));
  await page.keyboard.down('u');
  await page.waitForTimeout(100);
  await page.keyboard.up('u');
  await page.waitForFunction(
    ({ mpBefore, hpBefore }) => Number(document.documentElement.dataset.playerMp) < mpBefore && Number(document.documentElement.dataset.dummyHp) < hpBefore && document.documentElement.dataset.lastSkillHit === 'true' && Number(document.documentElement.dataset.skillHitCount) >= 1,
    { mpBefore, hpBefore },
    { timeout: 10_000 },
  );

  console.log(`PRODUCTION_CREATOR_GEMINI_E2E_PASSED provider=gemini revision=${expectedRevision} reference=true proposal=true confirmPreview=true cast=true damage=${damage}`);
} finally {
  await browser.close();
}
