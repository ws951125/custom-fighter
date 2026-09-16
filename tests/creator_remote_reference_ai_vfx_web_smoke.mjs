import { chromium } from 'playwright';
import sharp from 'sharp';

const baseUrl = process.env.CUSTOM_FIGHTER_WEB_URL ?? 'http://127.0.0.1:8000';
const endpoint = 'https://ai.example.com/v1/vfx/generate';
const browserChannel = process.env.BROWSER_CHANNEL?.trim();
const launchOptions = { headless: true };
if (browserChannel) launchOptions.channel = browserChannel;

const referencePng = await sharp({
  create: { width: 2, height: 2, channels: 4, background: { r: 255, g: 64, b: 32, alpha: 1 } },
}).png().toBuffer();
const generatedStrip = await sharp({
  create: { width: 256, height: 64, channels: 4, background: { r: 64, g: 128, b: 255, alpha: 1 } },
}).png().toBuffer();

const browser = await chromium.launch(launchOptions);
let capturedPayload = null;
try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  await page.route('https://ai.example.com/**', async (route) => {
    const requestUrl = new URL(route.request().url());
    if (requestUrl.pathname === '/healthz') {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        headers: { 'Access-Control-Allow-Origin': '*' },
        body: JSON.stringify({
          ok: true,
          service: 'custom-fighter-ai-vfx',
          ai: { configured: true, provider: 'gemini', model: 'gemini-3.6-flash', billing_mode: 'free-tier-only' },
        }),
      });
      return;
    }
    if (requestUrl.pathname !== '/v1/vfx/generate') {
      await route.abort();
      return;
    }
    capturedPayload = route.request().postDataJSON();
    const requestId = String(capturedPayload?.request_id ?? '');
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      headers: { 'Access-Control-Allow-Origin': '*' },
      body: JSON.stringify({
        ok: true,
        request_id: requestId,
        frame_count: 4,
        fps: 10,
        png_base64: generatedStrip.toString('base64'),
        skill_proposal: {
          proposal_id: `${requestId}_skill`,
          source_request_id: requestId,
          skill_id: `${requestId}_projectile`,
          skill_name: 'Reference Arc',
          skill_type: 'projectile',
          damage: 31,
          mp_cost: 18,
          cooldown: 1.6,
          startup: 0.2,
          active: 0.1,
          recovery: 0.3,
          speed: 640,
          range: 900,
          hitstun: 0.22,
          knockback: 300,
          hitbox_half_width: 28,
          hitbox_half_depth: 0.08,
          visual: 'prototype_fireball',
          impact_visual: 'prototype_impact',
          rationale: 'Reference-guided proposal; review and confirm before applying.',
        },
      }),
    });
  });

  const url = new URL(baseUrl);
  url.searchParams.set('mode', 'vfx');
  url.searchParams.set('ai_vfx_provider', 'remote_ai_vfx');
  url.searchParams.set('ai_vfx_endpoint', endpoint);
  const response = await page.goto(url.toString(), { waitUntil: 'domcontentloaded', timeout: 60_000 });
  if (!response?.ok()) throw new Error(`VFX URL returned HTTP ${response?.status() ?? 'unknown'}`);
  await page.waitForFunction(() => document.documentElement.dataset.creatorAiVfxReady === 'true', null, { timeout: 60_000 });
  await page.waitForFunction(
    () => document.documentElement.dataset.creatorAiVfxBackendReadiness === 'ready' && document.documentElement.dataset.creatorAiVfxGenerateEnabled === 'true',
    null,
    { timeout: 15_000 },
  );

  const dataUrl = `data:image/png;base64,${referencePng.toString('base64')}`;
  await page.evaluate((value) => window.customFighterCreatorAiVfxImportReference('reference.png', 'image/png', value), dataUrl);
  await page.waitForFunction(() => document.documentElement.dataset.creatorAiVfxReferencePresent === 'true', null, { timeout: 10_000 });
  await page.evaluate(() => window.customFighterCreatorAiVfxSetPrompt('reference guided blue arc'));
  await page.evaluate(() => window.customFighterCreatorAiVfxSetOutput(4, 64, 64, 10));
  await page.evaluate(() => window.customFighterCreatorAiVfxGenerate());

  await page.waitForFunction(
    () => document.documentElement.dataset.creatorAiVfxLastStatus === 'success' && document.documentElement.dataset.creatorAiVfxGeneratedValid === 'true',
    null,
    { timeout: 30_000 },
  );
  if (!capturedPayload) throw new Error('Remote backend route did not capture a request');
  if (capturedPayload.reference_mime_type !== 'image/png') throw new Error('Reference MIME was not serialized');
  if (capturedPayload.reference_width !== 2 || capturedPayload.reference_height !== 2) throw new Error('Reference dimensions were not serialized');
  if (capturedPayload.reference_png_base64 !== referencePng.toString('base64')) throw new Error('Reference PNG bytes changed in transit');
  if (capturedPayload.frame_count !== 4 || capturedPayload.frame_width !== 64 || capturedPayload.frame_height !== 64 || Number(capturedPayload.fps) !== 10) {
    throw new Error(`Remote output contract mismatch: ${JSON.stringify(capturedPayload)}`);
  }
  console.log('WEB_CREATOR_REMOTE_REFERENCE_AI_VFX_SMOKE_PASSED readiness=true reference=true payload=true generated=true proposal=true');
} finally {
  await browser.close();
}
