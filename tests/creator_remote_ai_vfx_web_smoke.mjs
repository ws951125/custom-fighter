import { chromium } from 'playwright';

const baseUrl = process.env.CUSTOM_FIGHTER_WEB_URL ?? 'http://127.0.0.1:8000';
const endpoint = 'https://ai.example.com/v1/vfx/generate';
const healthEndpoint = 'https://ai.example.com/healthz';
const browserChannel = process.env.BROWSER_CHANNEL?.trim();
const launchOptions = { headless: true };
if (browserChannel) launchOptions.channel = browserChannel;
const browser = await chromium.launch(launchOptions);

async function openVfx(page, remoteEndpoint) {
  const url = new URL(baseUrl);
  url.searchParams.set('mode', 'vfx');
  url.searchParams.set('ai_vfx_provider', 'remote_ai_vfx');
  url.searchParams.set('ai_vfx_endpoint', remoteEndpoint);
  const response = await page.goto(url.toString(), { waitUntil: 'domcontentloaded', timeout: 60_000 });
  if (!response?.ok()) throw new Error(`VFX URL returned HTTP ${response?.status() ?? 'unknown'}`);
  await page.waitForFunction(
    () => document.documentElement.dataset.creatorAiVfxReady === 'true',
    null,
    { timeout: 60_000 },
  );
}

try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  let configured = true;
  await page.route(healthEndpoint, async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        ok: true,
        service: 'custom-fighter-ai-vfx',
        provider: 'openai',
        model: 'gpt-image-2',
        configured,
      }),
    });
  });

  await openVfx(page, endpoint);
  await page.waitForFunction(
    () => document.documentElement.dataset.creatorAiVfxBackendReadiness === 'ready',
    null,
    { timeout: 10_000 },
  );
  const provider = await page.evaluate(() => document.documentElement.dataset.creatorAiVfxProvider ?? '');
  const backendProvider = await page.evaluate(() => document.documentElement.dataset.creatorAiVfxBackendProvider ?? '');
  const backendModel = await page.evaluate(() => document.documentElement.dataset.creatorAiVfxBackendModel ?? '');
  const backendConfigured = await page.evaluate(() => document.documentElement.dataset.creatorAiVfxBackendConfigured ?? '');
  if (provider !== 'remote_ai_vfx') throw new Error(`Expected remote provider, got ${provider}`);
  if (backendProvider !== 'openai' || backendModel !== 'gpt-image-2' || backendConfigured !== 'true') {
    throw new Error(`Configured backend readiness metadata mismatch: ${backendProvider} ${backendModel} ${backendConfigured}`);
  }

  configured = false;
  await page.reload({ waitUntil: 'domcontentloaded', timeout: 60_000 });
  await page.waitForFunction(
    () => document.documentElement.dataset.creatorAiVfxBackendReadiness === 'unconfigured',
    null,
    { timeout: 60_000 },
  );
  if ((await page.evaluate(() => document.documentElement.dataset.creatorAiVfxBackendConfigured ?? '')) !== 'false') {
    throw new Error('Unconfigured backend must report configured=false');
  }
  const readinessError = await page.evaluate(() => document.documentElement.dataset.creatorAiVfxBackendError ?? '');
  if (!readinessError.includes('credentials')) throw new Error(`Unconfigured backend reason missing: ${readinessError}`);
  await page.evaluate(() => window.customFighterCreatorAiVfxSetPrompt('blocked readiness probe'));
  await page.evaluate(() => window.customFighterCreatorAiVfxGenerate());
  await page.waitForFunction(
    () => document.documentElement.dataset.creatorAiVfxLastStatus === 'error',
    null,
    { timeout: 5_000 },
  );
  if (Number(await page.evaluate(() => document.documentElement.dataset.creatorAiVfxGenerationCount ?? '0')) !== 0) {
    throw new Error('Unconfigured backend must not start a generation');
  }

  await openVfx(page, 'http://ai.example.com/v1/vfx/generate');
  const rejectedProvider = await page.evaluate(() => document.documentElement.dataset.creatorAiVfxProvider ?? '');
  const status = await page.evaluate(() => document.documentElement.dataset.creatorAiVfxLastStatus ?? '');
  const error = await page.evaluate(() => document.documentElement.dataset.creatorAiVfxError ?? '');
  if (rejectedProvider !== 'mock_ai_vfx') throw new Error(`Unsafe endpoint must fall back to mock, got ${rejectedProvider}`);
  if (status !== 'error' || !error.includes('https URL')) throw new Error(`Unsafe endpoint was not reported: ${status} ${error}`);
  console.log('WEB_CREATOR_REMOTE_AI_VFX_SMOKE_PASSED readiness=true unconfiguredBlocked=true unsafeRejected=true');
} finally {
  await browser.close();
}
