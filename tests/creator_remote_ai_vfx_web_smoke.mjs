import { chromium } from 'playwright';

const baseUrl = process.env.CUSTOM_FIGHTER_WEB_URL ?? 'http://127.0.0.1:8000';
const browserChannel = process.env.BROWSER_CHANNEL?.trim();
const launchOptions = { headless: true };
if (browserChannel) launchOptions.channel = browserChannel;
const browser = await chromium.launch(launchOptions);

async function openVfx(page, endpoint) {
  const url = new URL(baseUrl);
  url.searchParams.set('mode', 'vfx');
  url.searchParams.set('ai_vfx_provider', 'remote_ai_vfx');
  url.searchParams.set('ai_vfx_endpoint', endpoint);
  const response = await page.goto(url.toString(), { waitUntil: 'domcontentloaded', timeout: 60_000 });
  if (!response?.ok()) throw new Error(`VFX URL returned HTTP ${response?.status() ?? 'unknown'}`);
  await page.waitForFunction(
    () => document.documentElement.dataset.creatorAiVfxReady === 'true',
    null,
    { timeout: 60_000 },
  );
}

async function state(page, key) {
  return page.evaluate((name) => document.documentElement.dataset[name] ?? '', key);
}

async function waitReadiness(page, expected) {
  await page.waitForFunction(
    () => ['ready', 'unconfigured', 'error'].includes(document.documentElement.dataset.creatorAiVfxBackendReadiness ?? ''),
    null,
    { timeout: 15_000 },
  );
  const actual = await state(page, 'creatorAiVfxBackendReadiness');
  if (actual !== expected) {
    const error = await state(page, 'creatorAiVfxBackendError');
    throw new Error(`Expected backend readiness=${expected}, got ${actual}; error=${error}`);
  }
}

async function newRemotePage(configured, healthCounter) {
  const context = await browser.newContext({ viewport: { width: 1280, height: 720 } });
  await context.route('https://ai.example.com/**', async (route) => {
    const requestUrl = new URL(route.request().url());
    if (requestUrl.pathname === '/healthz') {
      healthCounter.count += 1;
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        headers: { 'Access-Control-Allow-Origin': '*' },
        body: JSON.stringify({
          ok: true,
          service: 'custom-fighter-ai-vfx',
          ai: { configured, provider: 'gemini', model: 'gemini-2.5-flash', billing_mode: 'free-tier-only' },
        }),
      });
      return;
    }
    await route.abort();
  });
  const page = await context.newPage();
  return { context, page };
}

try {
  const healthCounter = { count: 0 };

  const unconfiguredSession = await newRemotePage(false, healthCounter);
  await openVfx(unconfiguredSession.page, 'https://ai.example.com/v1/vfx/generate');
  const provider = await state(unconfiguredSession.page, 'creatorAiVfxProvider');
  if (provider !== 'remote_ai_vfx') throw new Error(`Expected remote provider, got ${provider}`);
  await waitReadiness(unconfiguredSession.page, 'unconfigured');
  if (healthCounter.count < 1) throw new Error('Trusted backend health endpoint was not requested');
  if ((await state(unconfiguredSession.page, 'creatorAiVfxBackendConfigured')) !== 'false') throw new Error('Unconfigured backend must report configured=false');
  if ((await state(unconfiguredSession.page, 'creatorAiVfxGenerateEnabled')) !== 'false') throw new Error('Generate must remain disabled while backend API key is missing');
  if (!(await state(unconfiguredSession.page, 'creatorAiVfxBackendError')).includes('API key')) throw new Error('Missing provider API key must be surfaced before generation');
  await unconfiguredSession.context.close();

  const configuredSession = await newRemotePage(true, healthCounter);
  await openVfx(configuredSession.page, 'https://ai.example.com/v1/vfx/generate');
  await waitReadiness(configuredSession.page, 'ready');
  if (healthCounter.count < 2) throw new Error('Trusted backend readiness was not checked for the configured session');
  if ((await state(configuredSession.page, 'creatorAiVfxBackendConfigured')) !== 'true') throw new Error('Configured backend must report configured=true');
  if ((await state(configuredSession.page, 'creatorAiVfxBackendProvider')) !== 'gemini') throw new Error('Backend provider metadata missing');
  if ((await state(configuredSession.page, 'creatorAiVfxBackendModel')) !== 'gemini-2.5-flash') throw new Error('Backend model metadata missing');
  if ((await state(configuredSession.page, 'creatorAiVfxGenerateEnabled')) !== 'true') throw new Error('Generate must be enabled only after readiness succeeds');
  await configuredSession.context.close();

  const unsafeContext = await browser.newContext({ viewport: { width: 1280, height: 720 } });
  const unsafePage = await unsafeContext.newPage();
  await openVfx(unsafePage, 'http://ai.example.com/v1/vfx/generate');
  const rejectedProvider = await state(unsafePage, 'creatorAiVfxProvider');
  const status = await state(unsafePage, 'creatorAiVfxLastStatus');
  const error = await state(unsafePage, 'creatorAiVfxError');
  if (rejectedProvider !== 'mock_ai_vfx') throw new Error(`Unsafe endpoint must fall back to mock, got ${rejectedProvider}`);
  if (status !== 'error' || !error.includes('https URL')) throw new Error(`Unsafe endpoint was not reported: ${status} ${error}`);
  await unsafeContext.close();

  console.log(`WEB_CREATOR_REMOTE_AI_VFX_SMOKE_PASSED readinessGate=true healthRequests=${healthCounter.count} isolatedSessions=true configuredMetadata=true unsafeEndpointBlocked=true`);
} finally {
  await browser.close();
}
